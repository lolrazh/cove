import Foundation
import Combine
import Testing
import WebKit
@testable import Cove

@MainActor
struct DownloadTests {
    private func item(_ directory: URL, name: String = "file.txt") -> DownloadItem {
        DownloadItem(filename: name, sourceURL: URL(string: "https://example.com/file"),
                     destinationURL: directory.appendingPathComponent(name))
    }

    @Test func progressKeepsItsUnitAndColumnAcrossDigitBoundaries() {
        let size = DownloadProgressSize(total: 1_000_000, locale: Locale(identifier: "en_US"))
        #expect(size.unit == "MB")
        #expect(size.number(99_000) == "0.1")
        #expect(size.number(100_000) == "0.1")
        #expect(size.columnTemplate == "0.0")
        #expect(size.suffix == "/1 MB")
        let unknown = DownloadProgressSize(total: -1, locale: Locale(identifier: "en_US"))
        #expect(unknown.number(999_000) == "999")
        #expect(unknown.number(1_000_000) == "1000")
        #expect(unknown.unit == "kB")
    }

    @Test func gigabyteProgressUsesOneSharedUnitWithoutPaddedDecimals() {
        let size = DownloadProgressSize(total: 2_100_000_000, locale: Locale(identifier: "en_US"))
        #expect(size.description(completed: 100_000_000) == "0.1/2.1 GB")
        #expect(size.description(completed: 1_000_000_000) == "1.0/2.1 GB")
        #expect(size.columnTemplate == "0.0")
        let german = DownloadProgressSize(total: 2_100_000_000, locale: Locale(identifier: "de_DE"))
        #expect(german.description(completed: 100_000_000) == "0,1/2,1 GB")
    }

    @Test func compactProgressCoversUnitsDigitChangesAndLongEstimates() {
        let locale = Locale(identifier: "en_US")
        let size = DownloadProgressSize(total: 258_000_000, locale: locale)
        #expect(size.description(completed: 25_800_000, remainingSeconds: 18) == "25.8/258 MB · 18s")
        #expect(size.description(completed: 26_000_000, remainingSeconds: 10_380) == "26.0/258 MB · 2h 53m")
        #expect(size.downloadedNumber(99_950_000) == "100.0")
        #expect(size.columnTemplate == "000.0")
        #expect(size.description(completed: 300_000_000) == "258.0/258 MB")
        #expect(DownloadProgressSize(total: 76, locale: locale).description(completed: 7) == "7/76 bytes")
        #expect(DownloadProgressSize(total: -1, locale: locale).description(completed: 1_000_000) == "1000.0 kB")
        #expect(DownloadProgressSize(total: 2_100_000_000_000, locale: locale)
            .description(completed: 100_000_000_000, remainingSeconds: 90_000) == "0.1/2.1 TB · 1d 1h")
        for (seconds, expected) in [(0, "0s"), (18, "18s"), (59, "59s"), (60, "1m 0s"),
                                    (61, "1m 1s"), (3599, "59m 59s"), (3600, "1h 0m"),
                                    (10_380, "2h 53m"), (86_399, "23h 59m"), (86_400, "1d 0h")] {
            #expect(DownloadProgressSize.time(seconds) == expected)
        }
    }

    @Test func estimateWarmsUpTracksSpeedAndHidesWhenStalled() throws {
        var rate = DownloadRateEstimate()
        #expect(rate.sample(completed: 0, total: 10_000, now: 0) == nil)
        #expect(rate.sample(completed: 250, total: 10_000, now: 0.25) == nil)
        #expect(rate.sample(completed: 1_000, total: 10_000, now: 1) == 9)
        let sample = rate.sample(completed: 3_000, total: 10_000, now: 2)
        let faster = try #require(sample)
        #expect(faster < 7 && faster > 3)
        #expect(rate.sample(completed: 3_000, total: 10_000, now: 5) == nil)
        #expect(rate.sample(completed: 4_000, total: 10_000, now: 6) != nil)
        #expect(rate.sample(completed: 5_000, total: -1, now: 7) == nil)
        #expect(rate.sample(completed: 10_000, total: 10_000, now: 8) == nil)
    }

    @Test func progressPublishesOneSnapshotAndDoesNotRegress() {
        let download = item(.temporaryDirectory)
        var updates: [DownloadTransfer] = []
        let subscription = download.$transfer.dropFirst().sink { updates.append($0) }
        download.updateProgress(completed: 10, total: 100, now: 0)
        download.updateProgress(completed: 10, total: 100, now: 0.25)
        #expect(updates.count == 1)
        #expect(updates[0].completed == 10 && updates[0].total == 100)
        download.updateProgress(completed: 5, total: -1, now: 0.5)
        #expect(download.bytesDownloaded == 10 && download.totalBytes == 100)
        download.markCancelled()
        download.updateProgress(completed: 100, total: 100, now: 1)
        #expect(download.bytesDownloaded == 10)
        download.startAgain()
        #expect(download.bytesDownloaded == 0 && download.totalBytes == -1)
        #expect(download.remainingSeconds == nil)
        withExtendedLifetime(subscription) {}
    }

    @Test func namesAvoidFilesAndPendingDownloads() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = directory.appendingPathComponent("file.txt")
        try Data([1]).write(to: first)
        let second = directory.appendingPathComponent("file (1).txt")
        let result = DownloadManager.uniqueDestination(for: "../../file.txt", in: directory, reserved: [second])
        #expect(result == directory.appendingPathComponent("file (2).txt"))
        #expect(DownloadManager.uniqueDestination(for: "..", in: directory).lastPathComponent == "Download")
        #expect(try Data(contentsOf: first) == Data([1]))
    }

    @Test func terminalStatesRejectLateProgressAndRetryResetsIt() {
        let download = item(.temporaryDirectory)
        download.updateProgress(completed: 30, total: 100)
        #expect(download.progress == 0.3)
        download.markCancelled()
        download.updateProgress(completed: 90, total: 100)
        #expect(download.progress == 0.3)
        download.startAgain()
        #expect(download.state == .downloading)
        #expect(download.progress == 0)
        download.updateProgress(completed: 200, total: 100)
        #expect(download.progress == 1)
        download.markFailed("Connection lost")
        download.updateProgress(completed: 1, total: 100)
        #expect(download.progress == 1)
    }

    @Test func restoredActiveDownloadIsInterruptedAndMissingFilesAreExplicit() {
        let download = item(.temporaryDirectory, name: UUID().uuidString)
        let restored = DownloadItem(record: download.record)
        #expect(restored.state == .failed)
        #expect(restored.detail == "Interrupted")
        #expect(restored.canRestart)
        download.markCompleted()
        #expect(!download.fileExists)
        #expect(!DownloadItem(record: download.record).fileExists)
        let blob = DownloadItem(filename: "file", sourceURL: URL(string: "blob:https://example.com/1"), destinationURL: .temporaryDirectory)
        #expect(!blob.canRestart)
    }

    @Test func renamedDestinationUpdatesVisibleName() {
        let download = item(.temporaryDirectory)
        download.setDestination(.temporaryDirectory.appendingPathComponent("Chosen Name.pdf"))
        #expect(download.filename == "Chosen Name.pdf")
        #expect(download.fileExtension == "pdf")
    }

    @Test func historySurvivesRelaunchAndClearDoesNotDeleteFiles() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("file.txt")
        try Data([1, 2, 3]).write(to: file)
        let download = item(root)
        download.markCompleted()
        let records = root.appendingPathComponent("downloads.plist")
        try PropertyListEncoder().encode([download.record]).write(to: records)
        let manager = DownloadManager(settings: BrowserSettingsStore(), recordsURL: records)
        #expect(manager.items.count == 1)
        #expect(!manager.hasSessionDownloads)
        #expect(manager.items[0].totalBytes == 3)
        manager.clearCompleted()
        #expect(DownloadManager(settings: manager.settings, recordsURL: records).items.isEmpty)
        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    @Test func privateDownloadsUseTheirOwnStoreAndHistory() {
        let base = BrowsingContext.profile(UUID(), faviconStore: FaviconStore(databasePath: ":memory:"),
            extensions: ExtensionLibrary(directory: nil), persistent: false)
        let privateContext = BrowsingContext.makePrivate(over: base)
        #expect(privateContext.downloads !== base.downloads)
        #expect(privateContext.downloads.dataStore === privateContext.dataStore)
        #expect(privateContext.downloads.dataStore !== base.dataStore)
    }
}
