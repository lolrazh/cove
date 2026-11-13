import Foundation
import Testing
@testable import Cove

@MainActor
struct ProfileDataTests {
    @Test func browserRecordsAndSiteSettingsStayInsideTheirProfile() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suite = "ProfileDataTests-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer {
            try? FileManager.default.removeItem(at: root)
            defaults.removePersistentDomain(forName: suite)
        }
        defaults.set(false, forKey: BrowserSettingKeys.contentBlockingEnabled)
        let settings = BrowserSettingsStore(defaults: defaults)
        let a = ProfileData(id: UUID(), settings: settings, root: root)
        let b = ProfileData(id: UUID(), settings: settings, root: root)
        let url = URL(string: "https://isolation.example/test")!
        a.history.recordVisit(url: url.absoluteString, title: "Only A")
        a.zoom.setZoom(1.5, for: url)
        a.blocker.setBlocks(false, on: url)
        a.archive.add(SavedTab(url: url.absoluteString, title: "Closed in A", customTitle: nil,
                              interactionState: Data([7]), lastUsedAt: nil), reason: .closed)
        let note = a.documents.create(.note)
        #expect(a.history.search(query: "isolation", limit: 10).count == 1)
        #expect(b.history.search(query: "isolation", limit: 10).isEmpty)
        #expect(b.archive.entries.isEmpty)
        #expect(b.documents.documents[note.id] == nil)
        #expect(b.zoom.zoom(for: url) == 1)
        #expect(b.blocker.blocks(on: url))
        #expect(a.downloads !== b.downloads)
        #expect(a.favicons !== b.favicons)
        let restored = ProfileData(id: a.id, settings: settings, root: root)
        #expect(restored.history.search(query: "isolation", limit: 10).count == 1)
        #expect(restored.zoom.zoom(for: url) == 1.5)
        #expect(!restored.blocker.blocks(on: url))
        let closed = try #require(restored.archive.lastClosed)
        #expect(restored.archive.take(closed.id)?.interactionState == Data([7]))
    }
}
