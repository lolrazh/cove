import AppKit
import Combine
import UniformTypeIdentifiers
import WebKit

@MainActor
final class DownloadItem: ObservableObject, Identifiable {
    let id: UUID
    let sourceURL: URL?
    let canRestart: Bool
    @Published private(set) var filename: String
    @Published private(set) var state: State = .downloading
    @Published private(set) var progress: Double = 0
    @Published private(set) var bytesDownloaded: Int64 = 0
    @Published private(set) var totalBytes: Int64 = -1
    @Published private(set) var fileURL: URL?
    @Published private(set) var detail: String?
    @Published private(set) var fileExists = true
    private var progressObservers: [NSKeyValueObservation] = []
    private var attempt = UUID()
    private var cachedIcon: NSImage?

    enum State: String, Codable { case downloading, completed, failed, cancelled }

    struct Record: Codable {
        let id: UUID
        let sourceURL: URL?
        let canRestart: Bool
        let filename: String
        let state: State
        let totalBytes: Int64
        let fileURL: URL?
    }

    init(filename: String, sourceURL: URL?, destinationURL: URL, canRestart: Bool = true, id: UUID = UUID()) {
        self.id = id
        self.filename = filename
        self.sourceURL = sourceURL
        self.fileURL = destinationURL
        self.canRestart = canRestart && ["http", "https"].contains(sourceURL?.scheme?.lowercased() ?? "")
    }

    convenience init(record: Record) {
        self.init(filename: record.filename, sourceURL: record.sourceURL,
                  destinationURL: record.fileURL ?? URL(filePath: "/"), canRestart: record.canRestart, id: record.id)
        fileURL = record.fileURL
        state = record.state == .downloading ? .failed : record.state
        detail = record.state == .downloading ? "Interrupted" : nil
        totalBytes = record.totalBytes
        if state == .completed { progress = 1; bytesDownloaded = totalBytes }
        refreshFileAvailability()
    }

    var record: Record {
        Record(id: id, sourceURL: sourceURL, canRestart: canRestart, filename: filename,
               state: state, totalBytes: totalBytes, fileURL: fileURL)
    }

    var fileExtension: String { (filename as NSString).pathExtension.lowercased() }
    var fileIcon: NSImage {
        if let cachedIcon { return cachedIcon }
        let image = NSWorkspace.shared.icon(for: UTType(filenameExtension: fileExtension) ?? .data)
        cachedIcon = image
        return image
    }

    func setDestination(_ url: URL) {
        fileURL = url
        filename = url.lastPathComponent
        cachedIcon = nil
    }

    func startAgain() {
        stopObserving()
        progress = 0
        bytesDownloaded = 0
        totalBytes = -1
        detail = nil
        state = .downloading
    }

    func observeProgress(of download: WKDownload) {
        let token = attempt
        let p = download.progress
        progressObservers = [p.observe(\.completedUnitCount, options: [.initial, .new]) { [weak self] p, _ in
            let done = p.completedUnitCount, total = p.totalUnitCount
            Task { @MainActor in
                guard let self, self.attempt == token, self.state == .downloading else { return }
                self.updateProgress(completed: done, total: total)
            }
        }]
    }

    func updateProgress(completed: Int64, total: Int64) {
        guard state == .downloading else { return }
        bytesDownloaded = max(0, completed)
        totalBytes = total
        progress = total > 0 ? min(1, Double(bytesDownloaded) / Double(total)) : 0
    }

    func markCompleted() {
        stopObserving()
        if let url = fileURL, let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64 {
            totalBytes = size
            bytesDownloaded = size
        }
        progress = 1
        state = .completed
        refreshFileAvailability()
    }

    func markFailed(_ message: String) {
        stopObserving()
        detail = message
        state = .failed
    }

    func markCancelled() {
        stopObserving()
        state = .cancelled
    }

    func refreshFileAvailability() {
        guard state == .completed else { return }
        fileExists = fileURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
    }

    func showOpenFailure() { detail = "Could not open this file" }

    private func stopObserving() {
        attempt = UUID()
        progressObservers = []
    }
}
