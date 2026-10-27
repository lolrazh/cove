import Foundation
import Testing
@testable import Cove

@MainActor
struct TabArchiveTests {
    private let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("CoveTests-\(UUID().uuidString)")

    private func archive(limit: Int = 500) -> TabArchive {
        TabArchive(directory: directory, limit: limit)
    }

    private func savedTab(_ url: String, title: String = "", customTitle: String? = nil, interactionState: Data? = nil) -> SavedTab {
        SavedTab(url: url, title: title, customTitle: customTitle, interactionState: interactionState, lastUsedAt: nil)
    }

    @Test func `an archived tab comes back whole, once`() throws {
        let archive = archive()
        let state = Data([1, 2, 3])
        archive.add(savedTab("https://example.com/", title: "Example", customTitle: "Notes", interactionState: state), reason: .idle)

        // The entry goes by the user's name; the tab comes back with both.
        let entry = try #require(archive.entries.first)
        #expect(entry.title == "Notes")
        let restored = archive.take(entry.id)
        #expect(restored?.url == "https://example.com/")
        #expect(restored?.title == "Example")
        #expect(restored?.customTitle == "Notes")
        #expect(restored?.interactionState == state)
        #expect(archive.entries.isEmpty)
        #expect(archive.take(entry.id) == nil)
    }

    @Test func `entries survive a relaunch, newest first`() {
        let before = archive()
        before.add(savedTab("https://a.example/"), reason: .idle, at: Date(timeIntervalSince1970: 1))
        before.add(savedTab("https://b.example/"), reason: .idle, at: Date(timeIntervalSince1970: 2))

        #expect(archive().entries.map(\.url) == ["https://b.example/", "https://a.example/"])
    }

    @Test func `a start page is not kept, and the oldest entries go beyond the limit`() {
        let archive = archive(limit: 2)
        archive.add(savedTab(""), reason: .closed)
        #expect(archive.entries.isEmpty)

        for day in 1...3 {
            archive.add(savedTab("https://example.com/\(day)"), reason: .idle, at: Date(timeIntervalSince1970: TimeInterval(day)))
        }
        #expect(archive.entries.map(\.url) == ["https://example.com/3", "https://example.com/2"])
        #expect(self.archive(limit: 2).entries.count == 2)
    }

    @Test func `closed tabs are told apart from idle ones, and survive a relaunch`() throws {
        let before = archive()
        before.add(savedTab("https://closed.example/"), reason: .closed, at: Date(timeIntervalSince1970: 1))
        before.add(savedTab("https://idle.example/"), reason: .idle, at: Date(timeIntervalSince1970: 2))

        // Reopen Last Closed Tab skips the newer idle tab.
        let after = archive()
        let closed = try #require(after.lastClosed)
        #expect(closed.url == "https://closed.example/")
        after.remove(closed.id)
        #expect(after.lastClosed == nil)
        #expect(archive().entries.map(\.url) == ["https://idle.example/"])
    }

    @Test func `an archive from before closed tabs were kept still opens`() throws {
        let old = try Database(path: directory.appendingPathComponent("archive.db").path)
        old.execute("CREATE TABLE archive (id TEXT PRIMARY KEY, url TEXT NOT NULL, title TEXT NOT NULL DEFAULT '', custom_title TEXT, interaction_state BLOB, archived_at REAL NOT NULL)")
        try old.run("INSERT INTO archive (id, url, archived_at) VALUES (?, ?, ?)", params: [UUID().uuidString, "https://old.example/", 1.0])

        let archive = archive()
        #expect(archive.entries.map(\.reason) == [.idle])
        archive.add(savedTab("https://new.example/"), reason: .closed)
        #expect(self.archive().lastClosed?.url == "https://new.example/")
    }

    @Test func `a private window's archive is its own and keeps nothing`() {
        let archive = TabArchive(directory: nil)
        archive.add(savedTab("https://private.example/"), reason: .closed)
        #expect(archive.lastClosed?.url == "https://private.example/")
        #expect(TabArchive(directory: nil).entries.isEmpty)
    }
}
