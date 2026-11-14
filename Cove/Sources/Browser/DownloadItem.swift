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
    @Published private(set) var transfer = DownloadTransfer()
    var bytesDownloaded: Int64 { transfer.completed }
    var totalBytes: Int64 { transfer.total }
    var remainingSeconds: Int? { state == .downloading ? transfer.remainingSeconds : nil }
    var progress: Double {
        state == .completed ? 1 : (totalBytes > 0 ? min(1, Double(bytesDownloaded) / Double(totalBytes)) : 0)
    }
    @Published private(set) var fileURL: URL?
    @Published private(set) var detail: String?
    @Published private(set) var fileExists = true
    private var progressObservation: AnyCancellable?
    private var rateEstimate = DownloadRateEstimate()
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
        transfer = DownloadTransfer(completed: state == .completed ? max(0, record.totalBytes) : 0,
                                    total: record.totalBytes)
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
        transfer = DownloadTransfer()
        detail = nil
        state = .downloading
    }

    func observeProgress(of download: WKDownload) {
        let token = attempt
        let p = download.progress
        // One atomic UI sample per quarter-second, including stalled transfers.
        // Byte notifications can arrive in bursts; do not redraw for every chunk.
        updateProgress(completed: p.completedUnitCount, total: p.totalUnitCount)
        progressObservation = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect().sink { [weak self] _ in
                guard let self, self.attempt == token, self.state == .downloading else { return }
                self.updateProgress(completed: p.completedUnitCount, total: p.totalUnitCount)
            }
    }

    func updateProgress(completed: Int64, total: Int64,
                        now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard state == .downloading else { return }
        let done = max(bytesDownloaded, max(0, completed))
        let knownTotal = total > 0 ? total : totalBytes
        let remaining = rateEstimate.sample(completed: done, total: knownTotal, now: now)
        let next = DownloadTransfer(completed: done, total: knownTotal, remainingSeconds: remaining)
        if transfer != next { transfer = next }
    }

    func markCompleted() {
        stopObserving()
        if let url = fileURL, let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64 {
            transfer = DownloadTransfer(completed: size, total: size)
        }
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
        progressObservation = nil
        rateEstimate = DownloadRateEstimate()
    }
}

/// Publish the size and estimate together, so rows never render a partial update.
struct DownloadTransfer: Equatable {
    var completed: Int64 = 0
    var total: Int64 = -1
    var remainingSeconds: Int?
}

/// A smoothed estimate from monotonic time. Hide it during warm-up or a stall.
struct DownloadRateEstimate {
    private var previous: (time: TimeInterval, bytes: Int64)?
    private var startedAt: TimeInterval = 0
    private var lastAdvance: TimeInterval = 0
    private var rate: Double = 0

    mutating func sample(completed: Int64, total: Int64, now: TimeInterval) -> Int? {
        guard let previous else {
            self.previous = (now, completed)
            startedAt = now
            lastAdvance = now
            return nil
        }
        let elapsed = now - previous.time
        guard elapsed > 0 else { return nil }
        let gained = max(0, completed - previous.bytes)
        self.previous = (now, completed)
        if gained > 0 { lastAdvance = now }
        let speed = Double(gained) / elapsed
        let weight = 1 - exp(-elapsed / 2)
        rate = rate == 0 ? speed : rate + weight * (speed - rate)
        guard now - startedAt >= 0.75, now - lastAdvance < 3,
              rate > 0, total > completed else { return nil }
        let seconds = ceil(Double(total - completed) / rate)
        guard seconds.isFinite, seconds < Double(Int.max) else { return nil }
        return max(1, Int(seconds))
    }
}
