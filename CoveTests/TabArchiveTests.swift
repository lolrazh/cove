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
        archive.add(savedTab("https://example.com/", title: "Example", customTitle: "Notes", interactionState: state))

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
        before.add(savedTab("https://a.example/"), at: Date(timeIntervalSince1970: 1))
        before.add(savedTab("https://b.example/"), at: Date(timeIntervalSince1970: 2))

        #expect(archive().entries.map(\.url) == ["https://b.example/", "https://a.example/"])
    }

    @Test func `a start page is not kept, and the oldest entries go beyond the limit`() {
        let archive = archive(limit: 2)
        archive.add(savedTab(""))
        #expect(archive.entries.isEmpty)

        for day in 1...3 {
            archive.add(savedTab("https://example.com/\(day)"), at: Date(timeIntervalSince1970: TimeInterval(day)))
        }
        #expect(archive.entries.map(\.url) == ["https://example.com/3", "https://example.com/2"])
        #expect(self.archive(limit: 2).entries.count == 2)
    }
}
