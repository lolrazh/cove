import Foundation
import WebKit
import AppKit
import UniformTypeIdentifiers
import Combine

@MainActor
final class DownloadItem: ObservableObject, Identifiable {
    let id = UUID()
    let filename: String
    let sourceURL: URL?

    @Published var state: State = .downloading
    @Published var progress: Double = 0
    @Published var bytesDownloaded: Int64 = 0
    @Published var totalBytes: Int64 = -1
    @Published var fileURL: URL?

    private(set) var resumeData: Data?
    private var progressObservers: [NSKeyValueObservation] = []

    enum State {
        case downloading, completed, failed, cancelled
    }

    init(filename: String, sourceURL: URL?, destinationURL: URL) {
        self.filename = filename
        self.sourceURL = sourceURL
        self.fileURL = destinationURL
    }

    func observeProgress(of download: WKDownload) {
        let p = download.progress
        progressObservers = [
            p.observe(\.fractionCompleted) { [weak self] p, _ in
                Task { @MainActor in self?.progress = p.fractionCompleted }
            },
            p.observe(\.completedUnitCount) { [weak self] p, _ in
                Task { @MainActor in self?.bytesDownloaded = p.completedUnitCount }
            },
            p.observe(\.totalUnitCount) { [weak self] p, _ in
                Task { @MainActor in self?.totalBytes = p.totalUnitCount }
            },
        ]
    }

    var fileExtension: String {
        (filename as NSString).pathExtension.lowercased()
    }

    var fileIcon: NSImage {
        NSWorkspace.shared.icon(for: .init(filenameExtension: (filename as NSString).pathExtension) ?? .data)
    }

    func markCompleted() {
        progress = 1
        // Read final file size from disk
        if let url = fileURL,
           let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64 {
            totalBytes = size
            bytesDownloaded = size
        }
        state = .completed
        progressObservers = []
    }

    func markFailed(resumeData: Data?) {
        self.resumeData = resumeData
        state = .failed
        progressObservers = []
    }

    func markCancelled() {
        state = .cancelled
        progressObservers = []
    }
}

@MainActor
final class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager(settings: .shared)

    @Published var items: [DownloadItem] = []
    private let settings: BrowserSettingsStore
    private var itemCancellables: [UUID: AnyCancellable] = [:]

    var hasActiveDownloads: Bool {
        items.contains { $0.state == .downloading }
    }

    // Aggregate progress across all active downloads (0.0–1.0)
    var overallProgress: Double {
        let active = items.filter { $0.state == .downloading }
        guard !active.isEmpty else { return 0 }
        let total = active.reduce(Int64(0)) { $0 + max($1.totalBytes, 0) }
        let done = active.reduce(Int64(0)) { $0 + $1.bytesDownloaded }
        return total > 0 ? Double(done) / Double(total) : active.map(\.progress).reduce(0, +) / Double(active.count)
    }

    private var downloadToItem: [WKDownload: DownloadItem] = [:]

    init(settings: BrowserSettingsStore) {
        self.settings = settings
        super.init()
    }

    func handleDownload(_ download: WKDownload) {
        download.delegate = self
    }

    func cancelDownload(_ item: DownloadItem) {
        guard let entry = downloadToItem.first(where: { $0.value.id == item.id }) else { return }
        entry.key.cancel { _ in }
        item.markCancelled()
        downloadToItem.removeValue(forKey: entry.key)
    }

    func clearCompleted() {
        let removed = items.filter { $0.state != .downloading }
        for item in removed { itemCancellables.removeValue(forKey: item.id) }
        items.removeAll { $0.state != .downloading }
    }

    func revealInFinder(_ item: DownloadItem) {
        guard let url = item.fileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func remove(_ item: DownloadItem) {
        items.removeAll { $0.id == item.id }
        downloadToItem = downloadToItem.filter { $0.value.id != item.id }
        itemCancellables.removeValue(forKey: item.id)
    }
}

extension DownloadManager: WKDownloadDelegate {
    nonisolated func download(
        _ download: WKDownload,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String
    ) async -> URL? {
        let mode = await MainActor.run { settings.downloadDestinationMode }
        guard let destination = await Self.destinationURL(for: suggestedFilename, mode: mode) else {
            return nil
        }

        await MainActor.run {
            let sourceURL = download.originalRequest?.url
            let item = DownloadItem(
                filename: suggestedFilename,
                sourceURL: sourceURL,
                destinationURL: destination
            )
            item.observeProgress(of: download)
            self.items.insert(item, at: 0)
            self.downloadToItem[download] = item
            self.itemCancellables[item.id] = item.objectWillChange
                .sink { [weak self] _ in self?.objectWillChange.send() }
        }

        return destination
    }

    nonisolated func downloadDidFinish(_ download: WKDownload) {
        Task { @MainActor in
            guard let item = self.downloadToItem.removeValue(forKey: download) else { return }
            item.markCompleted()
        }
    }

    nonisolated func download(
        _ download: WKDownload,
        didFailWithError error: Error,
        resumeData: Data?
    ) {
        Task { @MainActor in
            guard let item = self.downloadToItem.removeValue(forKey: download) else { return }
            item.markFailed(resumeData: resumeData)
        }
    }

    // Default: follow redirects
    nonisolated func download(
        _ download: WKDownload,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest: URLRequest
    ) async -> WKDownload.RedirectPolicy {
        .allow
    }

    private nonisolated static func destinationURL(
        for suggestedFilename: String,
        mode: DownloadDestinationMode
    ) async -> URL? {
        switch mode {
        case .downloadsFolder:
            let dir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            return uniqueDestination(for: suggestedFilename, in: dir)
        case .askEveryTime:
            return await chooseDestination(for: suggestedFilename)
        }
    }

    @MainActor
    private static func chooseDestination(for suggestedFilename: String) async -> URL? {
        await withCheckedContinuation { continuation in
            let panel = NSSavePanel()
            panel.canCreateDirectories = true
            panel.nameFieldStringValue = suggestedFilename
            panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first

            panel.begin { response in
                continuation.resume(returning: response == .OK ? panel.url : nil)
            }
        }
    }

    private nonisolated static func uniqueDestination(for suggestedFilename: String, in directory: URL) -> URL {
        var dest = directory.appendingPathComponent(suggestedFilename)

        guard FileManager.default.fileExists(atPath: dest.path) else { return dest }

        let stem = dest.deletingPathExtension().lastPathComponent
        let ext = dest.pathExtension
        var n = 1
        repeat {
            let name = ext.isEmpty ? "\(stem) (\(n))" : "\(stem) (\(n)).\(ext)"
            dest = directory.appendingPathComponent(name)
            n += 1
        } while FileManager.default.fileExists(atPath: dest.path)

        return dest
    }
}
