import Combine
import Foundation
import Testing
@testable import Cove

@Suite(.serialized)
@MainActor
struct TabManagerTests {
    private func makeManager(defaults: UserDefaults, archive: TabArchive? = nil) -> TabManager {
        defaults.set(false, forKey: BrowserSettingKeys.contentBlockingEnabled)
        let settings = BrowserSettingsStore(defaults: defaults)
        let favicon = FaviconStore(databasePath: Database.inMemory)
        let library = ExtensionLibrary(directory: nil)
        let context = BrowsingContext.makePrivate(over: .standard(faviconStore: favicon, extensions: library))
        let blocker = ContentBlockerManager(settings: settings, defaults: defaults)
        let services = TabSessionServices(
            historyStore: HistoryStore(settings: settings, databasePath: Database.inMemory),
            faviconStore: context.faviconStore,
            downloadManager: DownloadManager(settings: settings),
            webKitEnvironment: WebKitEnvironment(contentBlockerManager: blocker),
            contentBlocker: blocker, context: context,
            siteZoom: SiteZoomStore(defaults: defaults),
            boosts: BoostInjector(store: BoostStore(fileURL: nil))
        )
        return TabManager(settings: settings, services: services, archive: archive ?? TabArchive(directory: nil),
                          pins: PinStore(fileURL: nil), profiles: nil, documents: nil, session: nil)
    }

    @Test func `zoom feedback follows its page and clears when it closes`() throws {
        let suite = "TabManagerTests-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let manager = makeManager(defaults: defaults)
        let page = try #require(manager.activeTab)
        page.isNewTabPage = false
        manager.zoomIn()
        #expect(page.pageZoom == 1.15)
        #expect(page.zoomFeedback == 1.15)
        #expect(manager.toasts.current == nil)
        manager.zoomOut()
        #expect(page.pageZoom == 1)
        #expect(page.zoomFeedback == 1)
        manager.zoomIn()
        manager.resetZoom()
        #expect(page.pageZoom == 1)
        manager.addTab()
        #expect(manager.activeTab?.zoomFeedback == nil)
        manager.zoomIn()
        #expect(manager.activeTab?.zoomFeedback == nil)
        manager.closeTab(page.id)
        #expect(page.zoomFeedback == nil)
    }

    @Test func `late selection of a closed tab cannot clear the current page`() throws {
        let suite = "TabManagerTests-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let manager = makeManager(defaults: defaults)
        manager.addTab()
        let closed = try #require(manager.activeTabID)
        manager.closeTab(closed)
        let current = try #require(manager.activeTabID)
        manager.selectTab(closed)
        #expect(manager.activeTabID == current)
        #expect(manager.activeTab != nil)
        manager.selectTab(UUID())
        #expect(manager.activeTabID == current)
    }

    @Test func `rapid closes and reopens keep every published selection valid`() throws {
        let suite = "TabManagerTests-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let manager = makeManager(defaults: defaults)
        let selection = manager.$activeTabID.dropFirst().sink { id in
            #expect(id != nil)
            #expect(manager.allTabs.contains { $0.id == id })
        }
        let rows = manager.$today.dropFirst().sink { items in
            #expect(items.contains { $0.id == manager.activeTabID })
        }
        defer { selection.cancel(); rows.cancel() }
        for _ in 0..<20 {
            manager.addTab(url: "file:///dev/null")
            let closed = try #require(manager.activeTabID)
            manager.closeTab(closed)
            manager.selectTab(closed)
            #expect(manager.activeTab != nil)
            manager.reopenClosedTab()
            #expect(manager.activeTab != nil)
            manager.closeActiveTab()
        }
        #expect(manager.allTabs.count == 1)
        #expect(manager.activeTab != nil)
    }
    @Test func `closing the final page leaves a start page and can be undone`() throws {
        let suite = "TabManagerTests-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let manager = makeManager(defaults: defaults)
        let last = try #require(manager.activeTab)
        last.navigate("file:///dev/null")
        #expect(manager.canCloseTab(last.id))
        manager.closeTab(last.id)
        #expect(manager.tabs.count == 1)
        #expect(manager.activeTabID != last.id)
        #expect(manager.activeTab?.isNewTabPage == true)
        #expect(manager.activeTab?.currentURL.isEmpty == true)
        #expect(manager.archive.lastClosed?.url == "file:///dev/null")
        #expect(!manager.canCloseTab(last.id))
        manager.reopenClosedTab()
        #expect(manager.activeTab?.currentURL == "file:///dev/null")
        #expect(manager.tabs.count == 1)
        #expect(manager.tabs.allSatisfy { !$0.isNewTabPage })
    }

    @Test func `rapid restores recover middle slots and keep notes in place`() throws {
        let suite = "TabManagerTests-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let manager = makeManager(defaults: defaults)
        try #require(manager.activeTab).navigate("file:///dev/null#a")
        for suffix in ["b", "c", "d"] { manager.addTab(url: "file:///dev/null#" + suffix) }
        let original = manager.tabs.map(\.currentURL)
        let closed = Array(manager.tabs.dropFirst())
        let note = UUID()
        manager.today.insert(.document(note), at: 1)
        manager.selectTab(closed[0].id)
        manager.closeTab(closed[0].id)
        #expect(manager.activeTabID == closed[1].id)
        manager.closeTab(closed[1].id)
        manager.closeTab(closed[2].id)
        #expect(manager.tabs.count == 1)
        for url in original.dropFirst().reversed() {
            manager.reopenClosedTab()
            #expect(manager.activeTab?.currentURL == url)
        }
        #expect(manager.tabs.map(\.currentURL) == original)
        #expect(manager.today[1].documentID == note)
        #expect(manager.today.count == 5)
        #expect(manager.archive.lastClosed == nil)
    }

    @Test func `restoring from another window does not reuse its slot`() throws {
        let suite = "TabManagerTests-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let archive = TabArchive(directory: nil)
        let first = makeManager(defaults: defaults, archive: archive)
        try #require(first.activeTab).navigate("file:///dev/null#a")
        first.addTab(url: "file:///dev/null#b")
        first.closeTab(first.tabs[0].id)
        #expect(archive.lastClosed?.todayIndex == 0)

        let second = makeManager(defaults: defaults, archive: archive)
        try #require(second.activeTab).navigate("file:///dev/null#x")
        second.addTab(url: "file:///dev/null#y")
        second.reopenClosedTab()
        #expect(second.tabs.map(\.currentURL) == ["file:///dev/null#x", "file:///dev/null#y", "file:///dev/null#a"])
        #expect(second.activeTab?.currentURL == "file:///dev/null#a")
        #expect(first.tabs.map(\.currentURL) == ["file:///dev/null#b"])
    }

    @Test func `restore keeps a start page with forward history`() throws {
        let suite = "TabManagerTests-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let manager = makeManager(defaults: defaults)
        let start = try #require(manager.activeTab)
        manager.addTab(url: "file:///dev/null")
        manager.closeActiveTab()
        // This models a start page reached through Back, with a page to return to.
        start.canGoForward = true
        manager.reopenClosedTab()
        #expect(manager.tabs.count == 2)
        #expect(manager.tabs.first === start)
    }

}
