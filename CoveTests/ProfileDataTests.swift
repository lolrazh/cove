import Foundation
import Combine
import Testing
import WebKit
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
    @Test func switchingProfilesChangesEveryDataSourceAndRetainsTabs() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suite = "ProfileSwitchTests-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer {
            try? FileManager.default.removeItem(at: root)
            defaults.removePersistentDomain(forName: suite)
        }
        defaults.set(false, forKey: BrowserSettingKeys.contentBlockingEnabled)
        let settings = BrowserSettingsStore(defaults: defaults)
        let extensions = ExtensionLibrary(directory: nil)
        let store = ProfileStore(fileURL: nil) { id in
            let data = ProfileData(id: id, settings: settings, root: root)
            return .profile(id, faviconStore: data.favicons, extensions: extensions, profileData: data, persistent: false)
        }
        let first = store.profiles.profiles[0]
        var second = first
        store.change { second = $0.addProfile() }
        let context = store.context(for: first)
        let data = try #require(context.profileData)
        let services = TabSessionServices(historyStore: data.history, faviconStore: data.favicons,
            downloadManager: data.downloads, webKitEnvironment: data.environment,
            contentBlocker: data.blocker, context: context, siteZoom: data.zoom, boosts: data.boosts)
        let pins = PinStore(fileURL: nil)
        let manager = TabManager(settings: settings, services: services, archive: data.archive,
            pins: pins, profiles: store, documents: data.documents, session: nil)
        manager.addTab(url: "file:///dev/null")
        let pinned = try #require(manager.activeTabID)
        manager.pinTab(pinned)
        data.history.recordVisit(url: "https://only-personal.example", title: "Only Personal")
        let cookie = try #require(HTTPCookie(properties: [.domain: "isolation.example", .path: "/", .name: "profile", .value: "personal"]))
        await context.dataStore.httpCookieStore.setCookie(cookie)
        let secondContext = store.context(for: second)
        #expect(await secondContext.dataStore.httpCookieStore.allCookies().isEmpty)
        manager.switchToProfile(second.id)
        #expect(manager.services.context === secondContext)
        #expect(manager.pinned.isEmpty)
        #expect(manager.archive !== data.archive)
        #expect(manager.documentStore !== data.documents)
        manager.commandBar.present(.newTab)
        #expect(!manager.commandBar.results.contains { $0.destination == "https://only-personal.example" })
        manager.commandBar.dismiss()
        let secondTab = try #require(manager.activeTabID)
        var parkedSaves = 0
        var savedBackgroundProfile: SavedProfile?
        let sessionChanges = manager.parkedSessionChanges.sink { [weak manager] in
            parkedSaves += 1
            savedBackgroundProfile = manager?.savedWindow.profiles.first { $0.profileID == first.id }
        }
        defer { sessionChanges.cancel() }
        // A child opened by the parked profile cannot join the visible one.
        manager.addTab(request: URLRequest(url: URL(string: "file:///dev/null?child")!), nextTo: pinned, grouping: .backgroundLink)
        #expect(parkedSaves == 1)
        #expect(savedBackgroundProfile?.tabs.contains { $0.url.contains("child") } == true)
        #expect(savedBackgroundProfile?.tabGroups?.first?.pinnedOpenerID == pinned)
        #expect(savedBackgroundProfile?.tabGroups?.first?.members.count == 1)
        #expect(manager.tabGroups.isEmpty)
        #expect(manager.activeTabID == secondTab)
        #expect(!manager.tabs.contains { $0.currentURL.contains("child") })
        manager.switchToProfile(first.id)
        #expect(manager.pinned.tabs.map(\.id) == [pinned])
        #expect(manager.tabs.contains { $0.currentURL.contains("child") })
        #expect(manager.tabGroups.count == 1)
        #expect(manager.tabGroups.first?.pinnedOpenerID == pinned)
        #expect(manager.tabGroups.first?.members.count == 1)
        #expect(manager.services.historyStore === data.history)
        manager.switchToProfile(second.id)
        #expect(manager.activeTabID == secondTab)
        #expect(manager.tabGroups.isEmpty)
        let removedData = try #require(secondContext.profileData)
        removedData.history.recordVisit(url: "https://only-work.example", title: "Only Work")
        store.deleteProfile(second.id)
        #expect(removedData.history.recentlyVisited.isEmpty)
        #expect(!data.history.recentlyVisited.isEmpty)
        #expect(manager.activeProfileID == first.id)
        #expect(!manager.allTabs.contains { $0.id == secondTab })
        #expect(!data.archive.entries.contains { $0.url.contains("child") })
        manager.allTabs.forEach { $0.close() }
    }

}
