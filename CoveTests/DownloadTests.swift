import Foundation
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
        #expect(size.suffix == "of 1 MB")
        let unknown = DownloadProgressSize(total: -1, locale: Locale(identifier: "en_US"))
        #expect(unknown.number(999_000) == "999")
        #expect(unknown.number(1_000_000) == "1000")
        #expect(unknown.unit == "kB")
    }

    @Test func gigabyteProgressUsesOneSharedUnitWithoutPaddedDecimals() {
        let size = DownloadProgressSize(total: 2_100_000_000, locale: Locale(identifier: "en_US"))
        #expect(size.description(completed: 100_000_000) == "0.1 of 2.1 GB")
        #expect(size.description(completed: 1_000_000_000) == "1 of 2.1 GB")
        #expect(size.columnTemplate == "0.0")
        let german = DownloadProgressSize(total: 2_100_000_000, locale: Locale(identifier: "de_DE"))
        #expect(german.description(completed: 100_000_000) == "0,1 of 2,1 GB")
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
