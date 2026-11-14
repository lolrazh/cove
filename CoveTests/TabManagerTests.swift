import AppKit
import Combine
import WebKit
import Foundation
import Testing
@testable import Cove

@Suite(.serialized)
@MainActor
struct TabManagerTests {
    private func makeManager(defaults: UserDefaults, archive: TabArchive? = nil, session: SessionStore? = nil) -> TabManager {
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
                          pins: PinStore(fileURL: nil), profiles: nil, documents: nil, session: session)
    }

    @Test func `cold pages seed their canvas from saved color and real changes are saved`() async throws {
        let legacy = Data(#"{"url":"file:///dev/null","title":"Light"}"#.utf8)
        var saved = try JSONDecoder().decode(SavedTab.self, from: legacy)
        #expect(saved.backgroundRGB == nil)
        saved.backgroundRGB = 0xf1f4f8
        saved = try JSONDecoder().decode(SavedTab.self, from: JSONEncoder().encode(saved))
        #expect(saved.backgroundRGB == 0xf1f4f8)
        let suite = "TabManagerTests-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let manager = makeManager(defaults: defaults)
        #expect(manager.services.context.pageBackgrounds.color(for: saved.url) == nil)
        let tab = TabSession(restoring: saved, showsStartPage: false, settings: manager.settings, services: manager.services)
        #expect(tab.pageBackgroundColor.flatMap(PageBackground.rgbValue) == saved.backgroundRGB)
        let page = tab.wake()
        #expect(tab.isAwaitingInitialContent)
        defer { tab.sleep() }
        #expect(PageBackground.rgbValue(of: page.underPageBackgroundColor) == saved.backgroundRGB)
        var saves = 0
        let observation = tab.savedTabChanges.sink { saves += 1 }
        defer { observation.cancel() }
        page.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
        page.loadHTMLString("<html><body style='background:#14283c'>Dark</body></html>", baseURL: URL(string: saved.url))
        for _ in 0..<300 {
            if tab.savedTab.backgroundRGB == 0x14283c { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(tab.savedTab.backgroundRGB == 0x14283c)
        #expect(!tab.isAwaitingInitialContent)
        #expect(PageBackground.rgbValue(of: page.underPageBackgroundColor) == 0x14283c)
        saves = 0
        _ = try await page.evaluateJavaScript("document.body.style.background = '#ffffff'")
        for _ in 0..<300 {
            if tab.savedTab.backgroundRGB == 0xffffff { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(tab.savedTab.backgroundRGB == 0xffffff)
        #expect(saves > 0)
        #expect(PageBackground.color(rgbValue: -1) == nil)
        #expect(PageBackground.color(rgbValue: 0x1000000) == nil)
        #expect(tab.wake() === page)
        #expect(!tab.isAwaitingInitialContent)
        tab.sleep()
        let replacement = tab.wake()
        #expect(tab.isAwaitingInitialContent)
        tab.webView(page, didFinish: nil)
        #expect(tab.isAwaitingInitialContent)
        tab.webView(replacement, didFinish: nil)
        #expect(!tab.isAwaitingInitialContent)
    }

    @Test func `link groups respect intent focus and manual singleton lifetime`() throws {
        let suite = "TabGroups-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let manager = makeManager(defaults: defaults)
        let opener = try #require(manager.activeTab)
        opener.navigate("file:///dev/null#parent")
        func request(_ name: String) -> URLRequest { URLRequest(url: URL(string: "file:///dev/null#\(name)")!) }
        manager.addTab(request: request("foreground"), nextTo: opener.id, grouping: .foregroundLink)
        #expect(manager.tabGroups.isEmpty)
        manager.selectTab(opener.id)
        manager.addTab(request: request("child"), nextTo: opener.id, grouping: .backgroundLink)
        #expect(manager.activeTabID == opener.id)
        let group = try #require(manager.group(for: opener.id))
        #expect(group.isAutomatic)
        #expect(group.members.count == 2)
        let childID = try #require(group.members.last)
        manager.addTab(request: request("joined"), nextTo: childID, grouping: .foregroundLink)
        let joined = try #require(manager.activeTabID)
        #expect(manager.group(for: joined)?.id == group.id)
        manager.closeTab(joined)
        manager.closeTab(childID)
        #expect(manager.group(for: opener.id) == nil)
        let manual = try #require(manager.createGroup(tabIDs: [opener.id]))
        manager.renameGroup(manual, to: "  Research  ")
        manager.setGroupSymbol(manual, to: "book")
        #expect(manager.group(for: opener.id)?.customName == "Research")
        #expect(manager.group(for: opener.id)?.symbolName == "book")
        manager.duplicateTab(opener.id)
        #expect(manager.activeTabID != opener.id)
        #expect(Set(manager.tabs.map(\.id)).count == manager.tabs.count)
        #expect(manager.group(for: opener.id)?.members == [opener.id])
    }

    @Test func `groups keep splits whole and batch close never focuses a retiring page`() throws {
        let suite = "TabGroups-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let manager = makeManager(defaults: defaults)
        let a = try #require(manager.activeTabID)
        manager.activeTab?.navigate("file:///dev/null#a")
        manager.addTab(url: "file:///dev/null#b")
        let b = try #require(manager.activeTabID)
        manager.addTab(url: "file:///dev/null#c")
        let c = try #require(manager.activeTabID)
        manager.selectTab(a)
        manager.openInSplitView(b)
        let id = try #require(manager.createGroup(tabIDs: [a]))
        #expect(Set(manager.group(for: a)?.members ?? []) == Set([a, b]))
        manager.selectTab(a)
        manager.toggleGroupCollapsed(id)
        #expect(manager.selectTabForInteraction(b, modifiers: .command))
        #expect(manager.selectedTabIDs == Set([a, b]))
        #expect(manager.activeTabID == a)
        manager.selectedTabIDs = []
        manager.tabSelectionAnchorID = nil
        manager.toggleGroupCollapsed(id)
        manager.moveTabs([c], toGroup: id)
        #expect(manager.group(for: c)?.members.count == 3)
        manager.ungroupTabs([a])
        #expect(manager.group(for: a) == nil && manager.group(for: b) == nil)
        #expect(manager.group(for: c)?.members == [c])
        manager.moveTabs([a], toGroup: id)
        var focused: [UUID] = []
        let observation = manager.$activeTabID.dropFirst().sink { if let id = $0 { focused.append(id) } }
        defer { observation.cancel() }
        manager.closeGroup(id)
        #expect(manager.tabs.count == 1 && manager.activeTab?.isNewTabPage == true)
        #expect(!focused.contains(a) && !focused.contains(b) && !focused.contains(c))
        for _ in 0..<3 { manager.reopenClosedTab() }
        #expect(manager.tabs.map(\.id) == [a, b, c])
        #expect(manager.tabGroups.first?.members == [a, b, c])
        manager.selectTab(c)
        manager.selectedTabIDs = [a, b]
        manager.closeActiveTab()
        #expect(manager.tabs.map(\.id) == [c])
        #expect(manager.activeTabID == c)
        #expect(manager.selectedTabIDs.isEmpty)
    }

    @Test func `closing a group prefers regular neighbors without waking a pin`() throws {
        let suite = "TabGroups-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let manager = makeManager(defaults: defaults)
        let pin = try #require(manager.activeTab)
        pin.navigate("file:///dev/null#pin")
        manager.pinTab(pin.id)
        manager.addTab(url: "file:///dev/null#loose")
        let loose = try #require(manager.activeTabID)
        pin.sleep()
        manager.addTab(url: "file:///dev/null#a")
        let a = try #require(manager.activeTabID)
        manager.addTab(url: "file:///dev/null#b")
        let b = try #require(manager.activeTabID)
        let group = try #require(manager.createGroup(tabIDs: [a, b]))
        manager.closeGroup(group)
        #expect(manager.activeTabID == loose)
        #expect(pin.isAsleep)
        manager.reopenClosedTab()
        manager.reopenClosedTab()
        manager.addTab(url: "file:///dev/null#next")
        let next = try #require(manager.activeTabID)
        manager.selectTab(a)
        manager.closeGroup(group)
        #expect(manager.activeTabID == next)
        #expect(pin.isAsleep)
        manager.closeTabs([loose, next])
        #expect(manager.activeTabID == pin.id)
    }

    @Test func `moving and grouping keep sidebar and keyboard order identical`() throws {
        let suite = "TabGroups-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let manager = makeManager(defaults: defaults)
        manager.activeTab?.navigate("file:///dev/null#a")
        for name in ["b", "c", "d", "e"] { manager.addTab(url: "file:///dev/null#\(name)") }
        let ids = manager.tabs.map(\.id)
        _ = manager.createGroup(tabIDs: Array(ids.prefix(3)))
        let second = try #require(manager.createGroup(tabIDs: Array(ids.suffix(2))))
        manager.moveTabs([ids[1]], toGroup: second)
        #expect(manager.tabs.map(\.id) == [ids[0], ids[2], ids[1], ids[3], ids[4]])
        #expect(TabManager.arrangedToday(manager.today, groups: manager.tabGroups).map(\.id) == manager.today.map(\.id))
        _ = manager.createGroup(tabIDs: [ids[2], ids[3]])
        #expect(TabManager.arrangedToday(manager.today, groups: manager.tabGroups).map(\.id) == manager.today.map(\.id))
        let document = UUID()
        manager.today.insert(.document(document), at: 1)
        #expect(manager.today.contains { $0.documentID == document })
        #expect(Set(manager.tabs.map(\.id)) == Set(ids))
        #expect(TabManager.arrangedToday(manager.today, groups: manager.tabGroups).map(\.id) == manager.today.map(\.id))
    }

    @Test func `archive group identity reconnects a dissolved group after restart`() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suite = "TabGroups-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let before = makeManager(defaults: defaults, archive: TabArchive(directory: directory))
        let parent = try #require(before.activeTab)
        parent.navigate("file:///dev/null#parent")
        before.addTab(request: URLRequest(url: URL(string: "file:///dev/null#child")!), nextTo: parent.id, grouping: .backgroundLink)
        let original = try #require(before.group(for: parent.id))
        let child = try #require(original.members.last)
        before.closeTab(child)
        #expect(before.tabGroups.isEmpty)
        let sessionURL = directory.appendingPathComponent("session.plist")
        try PropertyListEncoder().encode([before.savedWindow]).write(to: sessionURL)
        let after = makeManager(defaults: defaults, archive: TabArchive(directory: directory), session: SessionStore(fileURL: sessionURL))
        #expect(after.tabs.map(\.id) == [parent.id])
        after.reopenClosedTab()
        #expect(after.tabs.map(\.id) == [parent.id, child])
        #expect(after.group(for: child)?.id == original.id)
        #expect(after.group(for: child)?.members == [parent.id, child])
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

    @Test func `immediate undo reuses the page and ignores old save replies`() async throws {
        let suite = "TabManagerTests-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let manager = makeManager(defaults: defaults)
        let original = try #require(manager.activeTab)
        original.navigate("file:///dev/null#draft")
        let page = try #require(original.webView)
        for _ in 0..<3 {
            manager.closeActiveTab()
            manager.reopenClosedTab()
            #expect(manager.activeTab === original)
            #expect(manager.activeTab?.webView === page)
        }
        // Old WebKit callbacks and cancelled deadlines must not sleep the undo.
        try await Task.sleep(for: .milliseconds(150))
        #expect(manager.activeTab === original)
        #expect(original.webView === page)
        #expect(!original.isAsleep)
        #expect(manager.tabs.count == 1)
        #expect(manager.archive.entries.isEmpty)
    }

    @Test func `pending undo in another window rebinds page callbacks`() throws {
        let suite = "TabManagerTests-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = makeManager(defaults: defaults)
        let original = try #require(first.activeTab)
        original.navigate("file:///dev/null#draft")
        first.closeActiveTab()
        let firstSelection = first.activeTabID
        // Two windows of a profile share browsing services and its archive.
        let second = TabManager(settings: first.settings, services: first.services, archive: first.archive,
                                pins: PinStore(fileURL: nil), profiles: nil, documents: nil, session: nil)
        second.reopenClosedTab()
        #expect(second.activeTab === original)
        #expect(second.tabs.count == 1)
        second.addTab(url: "file:///dev/null#other")
        original.host?.select()
        #expect(second.activeTab === original)
        #expect(first.activeTabID == firstSelection)
        original.host?.openInNewTab(URLRequest(url: URL(string: "file:///dev/null#child")!))
        #expect(second.activeTab?.currentURL == "file:///dev/null#child")
        #expect(first.tabs.count == 1)
    }

    @Test func `removing and trimming archives cancel pending page saves`() async throws {
        let suite = "TabManagerTests-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let archive = TabArchive(directory: nil, limit: 1)
        let manager = makeManager(defaults: defaults, archive: archive)
        let first = try #require(manager.activeTab)
        first.navigate("file:///dev/null#first")
        manager.closeActiveTab()
        manager.addTab(url: "file:///dev/null#second")
        let second = try #require(manager.activeTab)
        manager.closeActiveTab()
        #expect(first.isAsleep)
        let last = try #require(archive.lastClosed)
        archive.remove(last.id)
        #expect(second.isAsleep)
        try await Task.sleep(for: .milliseconds(150))
        #expect(archive.entries.isEmpty)
        #expect(first.webView == nil && second.webView == nil)
    }

    @Test func `pending saves have both a page limit and a deadline`() async throws {
        let suite = "TabManagerTests-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let manager = makeManager(defaults: defaults)
        var closed: [TabSession] = []
        // A never-shown test window keeps pages attached, so detach callbacks
        // cannot complete these jobs. Nothing is placed on a user display.
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 600, height: 400),
                              styleMask: [], backing: .buffered, defer: true)
        defer { window.contentView?.subviews.forEach { $0.removeFromSuperview() } }
        for index in 0..<10 {
            manager.addTab(url: "file:///dev/null#\(index)")
            let tab = try #require(manager.activeTab)
            let page = try #require(tab.webView)
            try #require(window.contentView).addSubview(page)
            #expect(page.window === window)
            closed.append(tab)
            manager.closeActiveTab()
        }
        #expect(closed.filter { !$0.isAsleep }.count == 8)
        #expect(closed.prefix(2).allSatisfy { $0.isAsleep })
        // The main actor also handles WebKit process startup in the full
        // suite. Yield until deadline jobs run, with a bounded test timeout.
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while closed.contains(where: { !$0.isAsleep }), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(closed.allSatisfy { $0.isAsleep })
        #expect(manager.archive.entries.count == 10)
        manager.reopenClosedTab()
        #expect(manager.activeTab?.currentURL == "file:///dev/null#9")
        #expect(manager.activeTab !== closed.last)
    }

}
