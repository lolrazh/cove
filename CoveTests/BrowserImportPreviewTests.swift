import Foundation
import Testing
@testable import Cove

struct BrowserImportPreviewTests {
    @Test func chromiumHistoryUsesVisitDatesAndFiltersUnsafeURLs() throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let path = folder.appendingPathComponent("History")
        let db = try Database(path: path.path)
        try db.run("CREATE TABLE urls (id INTEGER, url TEXT, title TEXT, hidden INTEGER)")
        try db.run("CREATE TABLE visits (url INTEGER, visit_time INTEGER)")
        let timestamp = 1_700_000_000.0
        for (id, url) in [(1, "https://example.com"), (2, "javascript:alert(1)"), (3, "https:invalid")] {
            try db.run("INSERT INTO urls VALUES (?, ?, 'Example', 0)", params: [id, url])
            try db.run("INSERT INTO visits VALUES (?, ?)", params: [id, Int64((timestamp + 11_644_473_600) * 1_000_000)])
        }
        let before = try Data(contentsOf: path)
        let preview = try BrowserImportPreview.read(from: folder, source: .chrome)
        #expect(preview.historyCount == 1)
        #expect(preview.history.first?.visitedAt == Date(timeIntervalSince1970: timestamp))
        #expect(preview.issues.isEmpty)
        #expect(try Data(contentsOf: path) == before)
    }

    @Test func safariHistoryAndPartialFailureStaySeparate() throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let db = try Database(path: folder.appendingPathComponent("History.db").path)
        try db.run("CREATE TABLE history_items (id INTEGER, url TEXT)")
        try db.run("CREATE TABLE history_visits (history_item INTEGER, title TEXT, visit_time REAL)")
        try db.run("INSERT INTO history_items VALUES (1, 'https://webkit.org')")
        try db.run("INSERT INTO history_visits VALUES (1, 'WebKit', 721692800)")
        try Data("broken".utf8).write(to: folder.appendingPathComponent("Bookmarks.plist"))
        let preview = try BrowserImportPreview.read(from: folder, source: .safari)
        #expect(preview.historyCount == 1)
        #expect(preview.history.first?.visitedAt == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(preview.bookmarkCount == 0)
        #expect(preview.issues.count == 1)
    }

    @MainActor @Test func historyImportIsAdditiveIdempotentAndProfileLocal() throws {
        let defaults = UserDefaults(suiteName: "CoveTests.Import.\(UUID())")!
        let settings = BrowserSettingsStore(defaults: defaults)
        let first = HistoryStore(settings: settings, databasePath: Database.inMemory)
        let other = HistoryStore(settings: settings, databasePath: Database.inMemory)
        let visit = ImportedHistoryVisit(url: URL(string: "https://example.com")!, title: "Example", visitedAt: Date(timeIntervalSince1970: 1_700_000_000))
        #expect(try first.importVisits([visit, visit]) == 1)
        #expect(try first.importVisits([visit]) == 0)
        #expect(first.search(query: "Example").count == 1)
        #expect(other.search(query: "").isEmpty)
    }

    @MainActor @Test func failedHistoryImportRollsBackEarlierVisits() throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let path = folder.appendingPathComponent("target.db").path
        let defaults = UserDefaults(suiteName: "CoveTests.Import.\(UUID())")!
        let store = HistoryStore(settings: BrowserSettingsStore(defaults: defaults), databasePath: path)
        let db = try Database(path: path)
        try db.run("CREATE TRIGGER reject_fixture BEFORE INSERT ON history WHEN new.title = 'Reject' BEGIN SELECT RAISE(ABORT, 'fixture'); END")
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let first = ImportedHistoryVisit(url: URL(string: "https://example.com")!, title: "Keep", visitedAt: date)
        let second = ImportedHistoryVisit(url: URL(string: "https://swift.org")!, title: "Reject", visitedAt: date)
        #expect(throws: DatabaseError.self) { try store.importVisits([first, second]) }
        #expect(store.search(query: "").isEmpty)
    }

    @Test func absentSourceFolderDoesNotCreateFiles() throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        #expect(throws: BrowserImportPreview.ImportError.self) {
            try BrowserImportPreview.read(from: folder, source: .other)
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path).isEmpty)
    }

    private func temporaryFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("CoveImport-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
}
