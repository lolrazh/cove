import Foundation
import WebKit

@MainActor
final class DownloadItem: ObservableObject, Identifiable {
    let id = UUID()
    let filename: String
    let sourceURL: URL?

    @Published var state: State = .downloading
    @Published var progress: Double = 0
    @Published var fileURL: URL?

    private(set) var resumeData: Data?
    private var progressObserver: NSKeyValueObservation?

    enum State {
        case downloading, completed, failed, cancelled
    }

    init(filename: String, sourceURL: URL?, destinationURL: URL) {
        self.filename = filename
        self.sourceURL = sourceURL
        self.fileURL = destinationURL
    }

    func observeProgress(of download: WKDownload) {
        progressObserver = download.progress.observe(\.fractionCompleted) { [weak self] p, _ in
            Task { @MainActor in self?.progress = p.fractionCompleted }
        }
    }

    func markCompleted() {
        progress = 1
        state = .completed
        progressObserver = nil
    }

    func markFailed(resumeData: Data?) {
        self.resumeData = resumeData
        state = .failed
        progressObserver = nil
    }

    func markCancelled() {
        state = .cancelled
        progressObserver = nil
    }
}

@MainActor
final class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()

    @Published var items: [DownloadItem] = []

    var hasActiveDownloads: Bool {
        items.contains { $0.state == .downloading }
    }

    private var downloadToItem: [WKDownload: DownloadItem] = [:]

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
        items.removeAll { $0.state != .downloading }
    }

    func revealInFinder(_ item: DownloadItem) {
        guard let url = item.fileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func remove(_ item: DownloadItem) {
        items.removeAll { $0.id == item.id }
        downloadToItem = downloadToItem.filter { $0.value.id != item.id }
    }
}

extension DownloadManager: WKDownloadDelegate {
    nonisolated func download(
        _ download: WKDownload,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String
    ) async -> URL? {
        let destination = Self.uniqueDestination(for: suggestedFilename)

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

    private nonisolated static func uniqueDestination(for suggestedFilename: String) -> URL {
        let dir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        var dest = dir.appendingPathComponent(suggestedFilename)

        guard FileManager.default.fileExists(atPath: dest.path) else { return dest }

        let stem = dest.deletingPathExtension().lastPathComponent
        let ext = dest.pathExtension
        var n = 1
        repeat {
            let name = ext.isEmpty ? "\(stem) (\(n))" : "\(stem) (\(n)).\(ext)"
            dest = dir.appendingPathComponent(name)
            n += 1
        } while FileManager.default.fileExists(atPath: dest.path)

        return dest
    }
}
