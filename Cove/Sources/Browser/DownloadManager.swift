import AppKit
import Combine
import WebKit

@MainActor
final class DownloadManager: NSObject, ObservableObject {
    @Published private(set) var items: [DownloadItem] = []
    @Published private(set) var hasUnseenDownloads = false
    @Published private(set) var presentationRequest = 0
    let settings: BrowserSettingsStore
    var dataStore: WKWebsiteDataStore = .nonPersistent()
    private let recordsURL: URL?
    private var itemCancellables: [UUID: AnyCancellable] = [:]
    private var downloadToItem: [WKDownload: DownloadItem] = [:]
    private var retryViews: [UUID: WKWebView] = [:]
    private var reservations: Set<URL> = []
    private var partialFiles: [UUID: URL] = [:]

    var hasActiveDownloads: Bool { items.contains { $0.state == .downloading } }
    var completedCount: Int { items.count { $0.state == .completed } }
    var overallProgress: Double {
        let active = items.filter { $0.state == .downloading }
        let total = active.reduce(0.0) { $0 + Double(max($1.totalBytes, 0)) }
        let done = active.reduce(0.0) { $0 + ($1.totalBytes > 0 ? Double($1.bytesDownloaded) : 0) }
        return total > 0 ? min(1, max(0, done / total)) : 0
    }

    init(settings: BrowserSettingsStore, recordsURL: URL? = nil) {
        self.settings = settings
        self.recordsURL = recordsURL
        super.init()
        if let recordsURL, let data = try? Data(contentsOf: recordsURL),
           let records = try? PropertyListDecoder().decode([DownloadItem.Record].self, from: data) {
            items = records.map(DownloadItem.init(record:))
            items.forEach(observe)
        }
    }

    func handleDownload(_ download: WKDownload) { download.delegate = self }

    func cancelDownload(_ item: DownloadItem) {
        guard item.state == .downloading else { return }
        // Remove ownership before WebKit can deliver a late finish/failure.
        if let entry = downloadToItem.first(where: { $0.value.id == item.id }) {
            downloadToItem.removeValue(forKey: entry.key)
            let destination = item.fileURL
            let partial = partialFiles.removeValue(forKey: item.id)
            entry.key.cancel { [weak self] _ in
                Task { @MainActor in
                    if let destination { self?.reservations.remove(destination) }
                    if let partial { try? FileManager.default.removeItem(at: partial.deletingLastPathComponent()) }
                }
            }
        }
        retryViews.removeValue(forKey: item.id)
        item.markCancelled()
        save()
    }

    /// Retry is an explicit new GET. Never replay a form submission, blob URL,
    /// or an expiring WebKit resume token under a different login context.
    func retry(_ item: DownloadItem) {
        guard items.contains(where: { $0 === item }), item.state != .downloading,
              item.canRestart, let url = item.sourceURL else { return }
        item.startAgain()
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = dataStore
        let view = WKWebView(frame: .zero, configuration: configuration)
        retryViews[item.id] = view
        save()
        view.startDownload(using: URLRequest(url: url)) { [weak self, weak item, weak view] download in
            guard let self, let item, let view, self.retryViews[item.id] === view,
                  item.state == .downloading else { download.cancel { _ in }; return }
            self.downloadToItem[download] = item
            download.delegate = self
        }
    }

    func clearCompleted() {
        let removed = items.filter { $0.state != .downloading }
        for item in removed { itemCancellables.removeValue(forKey: item.id) }
        items.removeAll { $0.state != .downloading }
        save()
    }

    func markDownloadsSeen() { hasUnseenDownloads = false }
    func refreshFiles() { items.forEach { $0.refreshFileAvailability() } }

    func open(_ item: DownloadItem) {
        item.refreshFileAvailability()
        guard item.state == .completed, item.fileExists, let url = item.fileURL else { return }
        if !NSWorkspace.shared.open(url) { item.showOpenFailure() }
    }

    func revealInFinder(_ item: DownloadItem) {
        item.refreshFileAvailability()
        guard item.state == .completed, item.fileExists, let url = item.fileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func remove(_ item: DownloadItem) {
        cancelDownload(item)
        items.removeAll { $0.id == item.id }
        itemCancellables.removeValue(forKey: item.id)
        save()
    }

    private func observe(_ item: DownloadItem) {
        itemCancellables[item.id] = item.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
    }

    private func save() {
        guard let recordsURL, let data = try? PropertyListEncoder().encode(items.map(\.record)) else { return }
        do {
            try FileManager.default.createDirectory(at: recordsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: recordsURL, options: .atomic)
        } catch { NSLog("Could not save download history: %@", error.localizedDescription) }
    }

    /// Reservations also cover downloads whose destination file is not on disk yet.
    static func uniqueDestination(for suggestedFilename: String, in directory: URL, reserved: Set<URL> = []) -> URL {
        let filename = (suggestedFilename as NSString).lastPathComponent
        let safeName = filename.isEmpty || filename == "." || filename == ".." ? "Download" : filename
        var dest = directory.appendingPathComponent(safeName)
        let stem = dest.deletingPathExtension().lastPathComponent, ext = dest.pathExtension
        var n = 1
        while FileManager.default.fileExists(atPath: dest.path) || reserved.contains(dest) {
            let name = ext.isEmpty ? "\(stem) (\(n))" : "\(stem) (\(n)).\(ext)"
            dest = directory.appendingPathComponent(name)
            n += 1
        }
        return dest
    }

    private func destination(for filename: String) async -> URL? {
        let directory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let proposed = Self.uniqueDestination(for: filename, in: directory, reserved: reservations)
        if settings.downloadDestinationMode == .downloadsFolder {
            reservations.insert(proposed)
            return proposed
        }
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = proposed.lastPathComponent
        panel.directoryURL = directory
        let result: NSApplication.ModalResponse = await withCheckedContinuation { continuation in
            if let window = NSApp.keyWindow {
                panel.beginSheetModal(for: window) { continuation.resume(returning: $0) }
            } else {
                panel.begin { continuation.resume(returning: $0) }
            }
        }
        guard result == .OK, let url = panel.url else { return nil }
        // WebKit requires a non-existing destination. Keep both files if the
        // selected name already exists, including another pending download.
        let available = Self.uniqueDestination(for: url.lastPathComponent, in: url.deletingLastPathComponent(), reserved: reservations)
        reservations.insert(available)
        return available
    }
}

extension DownloadManager: WKDownloadDelegate {
    nonisolated func download(_ download: WKDownload, decideDestinationUsing response: URLResponse,
                             suggestedFilename: String) async -> URL? {
        await prepare(download, filename: suggestedFilename)
    }

    private func prepare(_ download: WKDownload, filename: String) async -> URL? {
        let existing = downloadToItem[download]
        guard let destination = await destination(for: filename) else {
            if let existing { cancelDownload(existing) }
            return nil
        }
        if let existing, existing.state != .downloading {
            reservations.remove(destination)
            return nil
        }
        let item = existing ?? DownloadItem(filename: destination.lastPathComponent,
            sourceURL: download.originalRequest?.url, destinationURL: destination,
            canRestart: (download.originalRequest?.httpMethod ?? "GET") == "GET")
        let partial = FileManager.default.temporaryDirectory
            .appendingPathComponent("CoveDownloads", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent(destination.lastPathComponent)
        do {
            try FileManager.default.createDirectory(at: partial.deletingLastPathComponent(), withIntermediateDirectories: true)
        } catch {
            reservations.remove(destination)
            item.markFailed(error.localizedDescription)
            if existing == nil { items.insert(item, at: 0); observe(item) }
            downloadToItem.removeValue(forKey: download)
            retryViews.removeValue(forKey: item.id)
            save()
            return nil
        }
        partialFiles[item.id] = partial
        item.setDestination(destination)
        if existing == nil { items.insert(item, at: 0); observe(item) }
        downloadToItem[download] = item
        item.observeProgress(of: download)
        save()
        presentationRequest += 1
        return partial
    }

    nonisolated func downloadDidFinish(_ download: WKDownload) {
        Task { @MainActor in
            guard let item = self.downloadToItem.removeValue(forKey: download) else { return }
            if let url = item.fileURL { self.reservations.remove(url) }
            self.retryViews.removeValue(forKey: item.id)
            guard let partial = self.partialFiles.removeValue(forKey: item.id), let destination = item.fileURL else {
                item.markFailed("The downloaded file is unavailable")
                self.save()
                return
            }
            defer { try? FileManager.default.removeItem(at: partial.deletingLastPathComponent()) }
            do {
                // Recheck in case another app created this name during the download.
                let final = Self.uniqueDestination(for: destination.lastPathComponent,
                    in: destination.deletingLastPathComponent(), reserved: self.reservations)
                try FileManager.default.moveItem(at: partial, to: final)
                item.setDestination(final)
                item.markCompleted()
                self.hasUnseenDownloads = true
            } catch { item.markFailed(error.localizedDescription) }
            self.save()
        }
    }

    nonisolated func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        let message = error.localizedDescription
        Task { @MainActor in
            guard let item = self.downloadToItem.removeValue(forKey: download) else { return }
            if let url = item.fileURL { self.reservations.remove(url) }
            self.retryViews.removeValue(forKey: item.id)
            if let partial = self.partialFiles.removeValue(forKey: item.id) {
                try? FileManager.default.removeItem(at: partial.deletingLastPathComponent())
            }
            item.markFailed(message)
            self.hasUnseenDownloads = true
            self.save()
        }
    }
}
