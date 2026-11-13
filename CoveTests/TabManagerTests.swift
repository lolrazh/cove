import Combine
import Foundation
import Testing
@testable import Cove

@Suite(.serialized)
@MainActor
struct TabManagerTests {
    private func makeManager(defaults: UserDefaults) -> TabManager {
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
        return TabManager(settings: settings, services: services, archive: TabArchive(directory: nil),
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
    }

}
