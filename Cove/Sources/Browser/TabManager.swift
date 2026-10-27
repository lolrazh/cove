import SwiftUI
import Foundation
import Combine

enum TabLayout: String {
    case horizontal
    case sidebar
}

@MainActor
final class TabManager: ObservableObject {
    /// Every open tab, oldest first: the top strip's order. The sidebar's Today
    /// section lists the same tabs newest first.
    @Published var tabs: [TabSession] = []
    /// Arc's sections above Today: a live tab for each pin the store keeps,
    /// Favorites as a row and Pinned as a tree with folders. Built from the
    /// store, so every window shows the same pins with tabs of its own.
    @Published private(set) var favorites: [TabSession] = []
    @Published private(set) var pinned = SidebarTree<TabSession>()
    /// A folder just made, for the sidebar to offer a name for.
    @Published var folderToName: UUID?
    /// The selected tab is the one on screen, so it's always awake; the
    /// others may sleep once they've been left alone long enough.
    @Published var activeTabID: UUID? {
        didSet {
            oldValue.flatMap(tab)?.markUsed()
            activeTab?.markUsed()
            activeTab?.wake()
        }
    }
    @Published var tabLayout: TabLayout
    @Published private(set) var hideTabs: Bool
    /// The background tab the media player controls.
    @Published private(set) var mediaTab: TabSession?
    /// Whether the active page's site controls are open.
    @Published var isShowingSiteControls = false
    /// Confirmations shown over this window's page.
    let toasts = ToastCenter()

    private let settings: BrowserSettingsStore
    private let services: TabSessionServices
    /// Where this window's closed and idle tabs go: the shared archive, or a
    /// private window's own, kept in memory and gone with the window.
    let archive: TabArchive
    /// The shared pins, or a private window's own empty, unsaved ones.
    private let pinStore: PinStore
    private let sweepClock = TabSweepClock()
    private var cancellables: Set<AnyCancellable> = []
    /// The live tab behind each pin, by the pin's ID, and what keeps the
    /// store up to date with where it is.
    private var pinnedTabs: [UUID: TabSession] = [:]
    private var pinnedTabRecorders: [UUID: AnyCancellable] = [:]

    /// This window's Command Bar. Lazy only because it needs `self`.
    private(set) lazy var commandBar = CommandBarModel(
        tabManager: self,
        settings: settings,
        historyStore: services.historyStore,
        faviconStore: services.faviconStore,
        archive: archive
    )

    /// This window's Library. Lazy for the same reason.
    private(set) lazy var library = LibraryModel(tabManager: self, services: services, archive: archive)

    var activeTab: TabSession? {
        activeTabID.flatMap(tab)
    }

    /// Any tab in the window: in Today, Pinned or Favorites.
    func tab(_ id: UUID) -> TabSession? {
        pinnedTabs[id] ?? tabs.first { $0.id == id }
    }

    var allTabs: [TabSession] {
        favorites + pinned.tabs + tabs
    }

    /// The tabs as they're shown: Favorites, then Pinned, then Today, top to
    /// bottom in the sidebar, where Today lists the newest first, or left to
    /// right in the strip. Switching with the keyboard, dragging, and Close
    /// Tabs Below all follow this order.
    var tabsInDisplayOrder: [TabSession] {
        favorites + shownPinnedTabs + (tabLayout == .sidebar ? tabs.reversed() : tabs)
    }

    /// The pinned tabs on screen: the strip shows them all, the sidebar keeps
    /// collapsed folders' tabs out of sight.
    var shownPinnedTabs: [TabSession] {
        tabLayout == .sidebar ? pinned.visibleTabs : pinned.tabs
    }

    /// A private window passes an in-memory archive and no session, so
    /// nothing of it is written down or comes back.
    init(
        settings: BrowserSettingsStore,
        services: TabSessionServices,
        archive: TabArchive,
        pins: PinStore,
        session: SessionStore?
    ) {
        self.settings = settings
        self.services = services
        self.archive = archive
        self.pinStore = pins
        self.tabLayout = settings.showsTabsInSidebar ? .sidebar : .horizontal
        self.hideTabs = settings.hideTabs
        bindSettings()
        trackMedia()
        sweepClock.ticks
            .sink { [weak self] underMemoryPressure in self?.sweepIdleTabs(underMemoryPressure: underMemoryPressure) }
            .store(in: &cancellables)
        pins.$pins
            .sink { [weak self] pins in self?.reconcilePinnedTabs(with: pins) }
            .store(in: &cancellables)

        // Restored tabs start asleep; selecting the active one wakes it, so a
        // launch loads one page per window instead of every page.
        let saved = session?.takeRestorableWindow()
        if let saved, !saved.tabs.isEmpty {
            tabs = saved.tabs.map { makeTab(restoring: $0) }
            selectTab(tabs[min(saved.activeTabIndex, tabs.count - 1)].id)
        } else {
            addTab()
        }
        session?.track(self, placement: saved?.placement)
    }

    var isPrivate: Bool {
        services.context.isPrivate
    }

    var savedWindow: SavedWindow {
        SavedWindow(
            tabs: tabs.map(\.savedTab),
            activeTabIndex: tabs.firstIndex { $0.id == activeTabID } ?? 0
        )
    }

    func setLayout(_ layout: TabLayout) {
        guard tabLayout != layout else { return }
        tabLayout = layout
        settings.setShowsTabsInSidebar(layout == .sidebar)
    }

    func toggleLayout() {
        setLayout(tabLayout == .horizontal ? .sidebar : .horizontal)
    }

    func setHideTabs(_ hide: Bool) {
        guard hideTabs != hide else { return }
        hideTabs = hide
        settings.setHideTabs(hide)
    }

    /// What ⌘T and the New Tab buttons do: ask where to go first, or open a
    /// tab holding the start page, as Settings says.
    func newTab() {
        if settings.newTabPreference == .commandBar {
            commandBar.present(.newTab)
        } else {
            addTab()
        }
    }

    /// ⌘L and the URL pill: the current address, ready to be changed.
    func editCurrentURL() {
        commandBar.present(.editURL)
    }

    /// Opens a tab at the end of the strip, which is the top of Today. Tabs
    /// opened from a link instead go next to their opener.
    func addTab(url: String? = nil) {
        let tab: TabSession

        if let url {
            tab = makeTab(initialURL: url, showsStartPage: false)
        } else {
            switch settings.destinationForNewTab() {
            case .startPage:
                tab = makeTab(showsStartPage: true)
            case .url(let destination):
                tab = makeTab(initialURL: destination, showsStartPage: false)
            }
        }

        open(tab)
    }

    func addTab(request: URLRequest, nextTo openerID: UUID? = nil) {
        let tab = makeTab(initialRequest: request, showsStartPage: false)
        open(tab, nextTo: openerID ?? activeTabID)
    }

    /// Opens a link from outside the window in a new tab, reusing the window's
    /// only tab if it's still an untouched start page.
    func openExternalURL(_ url: URL) {
        if tabs.count == 1,
           let activeTab,
           activeTab.isNewTabPage,
           activeTab.currentURL.isEmpty {
            activeTab.navigate(url.absoluteString)
        } else {
            addTab(url: url.absoluteString)
        }
    }

    private func bindSettings() {
        settings.$showsTabsInSidebar
            .removeDuplicates()
            .sink { [weak self] showsTabsInSidebar in
                guard let self else { return }
                let resolvedLayout: TabLayout = showsTabsInSidebar ? .sidebar : .horizontal
                guard self.tabLayout != resolvedLayout else { return }
                self.tabLayout = resolvedLayout
            }
            .store(in: &cancellables)

        settings.$hideTabs
            .removeDuplicates()
            .sink { [weak self] hideTabs in
                guard let self, self.hideTabs != hideTabs else { return }
                self.hideTabs = hideTabs
            }
            .store(in: &cancellables)
    }

    /// Keeps `mediaTab` current as tabs play, pause, open, close and get
    /// selected. `@Published` announces a change before making it, so the
    /// pick waits a turn of the main queue to see it.
    private func trackMedia() {
        let mediaChanged = Publishers.CombineLatest3($tabs, $favorites, $pinned)
            .map { tabs, favorites, pinned in
                Publishers.MergeMany((favorites + pinned.tabs + tabs).map { $0.$nowPlaying.map { _ in } })
            }
            .switchToLatest()
        Publishers.Merge(mediaChanged, $activeTabID.map { _ in })
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.updateMediaTab() }
            .store(in: &cancellables)
    }

    private func updateMediaTab() {
        let tab = tabsInDisplayOrder
            .filter { $0.id != activeTabID }
            .preferringPlaying(\.nowPlaying)
        if tab !== mediaTab {
            mediaTab = tab
        }
    }

    private func makeTab(
        id tabID: UUID = UUID(),
        initialURL: String? = nil,
        initialRequest: URLRequest? = nil,
        showsStartPage: Bool = false,
        restoring saved: SavedTab? = nil
    ) -> TabSession {

        return TabSession(
            id: tabID,
            initialURL: initialURL,
            initialRequest: initialRequest,
            restoring: saved,
            showsStartPage: saved.map { $0.url.isEmpty } ?? showsStartPage,
            settings: settings,
            services: services,
            onSelect: { [weak self] in self?.selectTab(tabID) }
        ) { [weak self] request in
            self?.addTab(request: request, nextTo: tabID)
        }
    }

    private func open(_ tab: TabSession, nextTo openerID: UUID? = nil) {
        if let openerID,
           let openerIndex = tabs.firstIndex(where: { $0.id == openerID }) {
            tabs.insert(tab, at: openerIndex + 1)
        } else {
            tabs.append(tab)
        }

        activeTabID = tab.id
    }

    /// Closes a Today tab, unless it's the last tab in the window. The next
    /// newer tab takes its place on screen, else the next older, else the
    /// pinned tab nearest Today. A pinned tab is kept: closing it resets it.
    func closeTab(_ id: UUID) {
        if let tab = pinnedTabs[id] {
            closePinnedTab(tab)
            return
        }
        guard allTabs.count > 1, let index = tabs.firstIndex(where: { $0.id == id }) else { return }

        let wasActive = (id == activeTabID)
        // Into the archive, as in Arc, where it keeps its back/forward list
        // for Reopen Last Closed Tab.
        let closed = tabs.remove(at: index)
        closed.close()
        archive.add(closed.savedTab, reason: .closed)

        if wasActive {
            activeTabID = (tabs.indices.contains(index) ? tabs[index] : tabsInDisplayOrder.last)?.id
        }
    }

    /// Whether a tab's close button does anything: a Today tab closes unless
    /// it's the last tab; a pinned tab resets, while awake or away from its pin.
    func canCloseTab(_ id: UUID) -> Bool {
        if let tab = pinnedTabs[id] { return !tab.isAsleep || tab.isAwayFromPin }
        return allTabs.count > 1
    }

    /// Reopens the most recently closed tab.
    func reopenClosedTab() {
        guard let closed = archive.lastClosed else { return }
        reopenArchivedTab(closed.id)
    }

    // MARK: - Idle tabs

    /// Sleeps background tabs idle past the setting and archives Today tabs
    /// idle past theirs; pinned tabs and favorites sleep but stay. Short of
    /// memory, every background tab that can sleep does.
    func sweepIdleTabs(underMemoryPressure: Bool = false, now: Date = .now) {
        var policy = TabIdlePolicy(
            sleepAfter: settings.sleepTabsAfter.interval,
            archiveAfter: isPrivate ? nil : settings.archiveTabsAfter.interval
        )
        if underMemoryPressure {
            policy = policy.underMemoryPressure
        }

        for tab in tabs {
            switch policy.action(for: TabIdlePolicy.Tab(tab, isActive: tab.id == activeTabID), at: now) {
            case .sleep: tab.sleep()
            case .archive: archiveTab(tab.id)
            case nil: break
            }
        }
        for tab in pinnedTabs.values
        where policy.neverArchiving.action(for: TabIdlePolicy.Tab(tab, isActive: tab.id == activeTabID), at: now) == .sleep {
            tab.sleep()
        }
    }

    /// Moves a background tab out of Today and into the archive, with its
    /// back/forward list, so it can come back whole.
    private func archiveTab(_ id: UUID) {
        guard id != activeTabID, let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        let archived = tabs.remove(at: index)
        archived.close()
        archive.add(archived.savedTab, reason: .idle)
    }

    /// Brings an archived tab back into Today, selected.
    func reopenArchivedTab(_ id: UUID) {
        guard let saved = archive.take(id) else { return }
        open(makeTab(restoring: saved))
    }

    func selectTab(_ id: UUID) {
        activeTabID = id
    }

    /// ⌃Tab and ⌃⇧Tab: the next or previous tab as shown, wrapping around.
    func selectAdjacentTab(_ offset: Int) {
        guard let activeTabID, let tab = tabsInDisplayOrder.element(offset, from: activeTabID) else { return }
        selectTab(tab.id)
    }

    /// ⌘1 to ⌘8 select a tab by its place, ⌘9 the last one.
    func selectTab(forShortcut number: Int) {
        guard let tab = tabsInDisplayOrder.element(forShortcut: number) else { return }
        selectTab(tab.id)
    }

    /// A copy of the tab beside it in Today, back and forward history included.
    func duplicateTab(_ id: UUID) {
        guard let tab = tab(id) else { return }
        open(makeTab(restoring: tab.savedTab), nextTo: id)
    }

    func closeActiveTab() {
        guard let activeTabID else { return }
        closeTab(activeTabID)
    }

    /// Closes every tab but this one, which stays as the active tab.
    func closeOtherTabs(keeping id: UUID) {
        selectTab(id)
        for tab in tabs where tab.id != id {
            closeTab(tab.id)
        }
    }

    /// Closes the Today tabs shown after this one: below it in the sidebar, to
    /// its right in the strip. It becomes active if the active tab is among them.
    func closeTabs(below id: UUID) {
        let closing = tabsInDisplayOrder.elements(after: id).filter { pinnedTabs[$0.id] == nil }
        if closing.contains(where: { $0.id == activeTabID }) {
            selectTab(id)
        }
        for tab in closing {
            closeTab(tab.id)
        }
    }

    /// Arc's Clear: closes everything in Today and leaves a fresh tab.
    func clearTodayTabs() {
        let closed = tabs
        addTab()
        for tab in closed {
            closeTab(tab.id)
        }
    }

    /// ⌘⇧C, the Command Bar and a tab's Copy Link: the page's address to the
    /// pasteboard, the active tab's unless another is given.
    func copyURL(of tab: TabSession? = nil) {
        guard let url = (tab ?? activeTab)?.currentURL, !url.isEmpty else { return }
        copyLink(url)
    }

    /// Any page's address to the pasteboard, like the Library's Copy Link.
    func copyLink(_ url: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
        toasts.show("Copied URL", symbol: ChromeSymbols.Navigation.link)
    }

    // MARK: - Pinned tabs and favorites

    enum TabSection {
        case favorites
        case pinned
        case today
    }

    func section(of id: UUID) -> TabSection? {
        switch pinStore.pins.section(of: id) {
        case .favorites: .favorites
        case .pinned: .pinned
        case nil: tabs.contains { $0.id == id } ? .today : nil
        }
    }

    /// ⌘D and Pin Tab: a Today tab moves into Pinned, or Favorites, where
    /// it's kept across launches. A start page has nothing to pin.
    func pinTab(_ id: UUID, to section: Pins.Section = .pinned, at position: SidebarPosition = .end) {
        guard let index = tabs.firstIndex(where: { $0.id == id }), !tabs[index].currentURL.isEmpty else { return }
        let tab = tabs.remove(at: index)
        tab.pinnedURL = tab.currentURL
        adoptPinnedTab(tab)
        pinStore.change { $0.add(Pin(id: id, url: tab.currentURL, title: tab.pageTitle), to: section, at: position) }
    }

    /// Unpin Tab: the live tab goes back to Today, at the top, or in the
    /// place of the tab it was dropped on.
    func unpinTab(_ id: UUID, onto target: UUID? = nil) {
        guard let tab = pinnedTabs[id] else { return }
        releasePinnedTab(tab, onto: target)
        pinStore.change { $0.remove(id) }
    }

    func togglePinned(_ id: UUID) {
        pinnedTabs[id] == nil ? pinTab(id) : unpinTab(id)
    }

    /// Drag and drop: the dragged tab takes the place of the one under it,
    /// moving between Favorites, Pinned and Today as needed.
    func moveTab(_ id: UUID, onto target: UUID) {
        guard id != target, let from = section(of: id), let to = section(of: target) else { return }
        switch (from, to) {
        case (.today, .today): tabs.move(id, onto: target)
        case (.today, .favorites): pinTab(id, to: .favorites, at: .before(target))
        case (.today, .pinned): pinTab(id, to: .pinned, at: .before(target))
        case (.favorites, .today), (.pinned, .today): unpinTab(id, onto: target)
        case (.favorites, _), (.pinned, _): pinStore.change { $0.move(id, onto: target) }
        }
    }

    /// A tab dropped on a folder goes in at the end of it.
    func moveTab(_ id: UUID, into folderID: UUID) {
        moveTab(id, to: .pinned, at: .into(folderID))
    }

    /// A tab dropped on a section's empty space goes to the end of it.
    func moveTab(_ id: UUID, toEndOf section: Pins.Section) {
        moveTab(id, to: section, at: .end)
    }

    private func moveTab(_ id: UUID, to section: Pins.Section, at position: SidebarPosition) {
        if pinnedTabs[id] == nil {
            pinTab(id, to: section, at: position)
        } else {
            pinStore.change { $0.move(id, to: section, at: position) }
        }
    }

    /// Closing a pinned tab keeps it: the next tab takes its place on screen
    /// and it goes back to its pinned address, asleep.
    private func closePinnedTab(_ tab: TabSession) {
        if tab.id == activeTabID, let next = tabsInDisplayOrder.element(1, from: tab.id), next.id != tab.id {
            selectTab(next.id)
        }
        tab.resetToPin(title: pinStore.pins.pin(tab.id)?.title ?? "")
        if tab.id == activeTabID {
            tab.wake()
        }
    }

    // MARK: Folders

    /// New Folder: an empty folder at the end of Pinned, or inside another,
    /// or one made around a pinned tab in its place. The sidebar then asks
    /// for its name.
    func newFolder(in parentID: UUID? = nil, around tabID: UUID? = nil) {
        let folder = SidebarFolder<Pin>(name: "New Folder")
        pinStore.change { pins in
            if let tabID, pins.section(of: tabID) == .pinned {
                pins.addFolder(folder, at: .before(tabID))
                pins.move(tabID, to: .pinned, at: .into(folder.id))
            } else {
                pins.addFolder(folder, at: parentID.map(SidebarPosition.into) ?? .end)
            }
        }
        folderToName = folder.id
    }

    /// An empty name leaves the folder as it was.
    func renameFolder(_ id: UUID, to name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        pinStore.change { $0.updateFolder(id) { $0.name = name } }
    }

    func toggleFolderCollapsed(_ id: UUID) {
        pinStore.change { $0.updateFolder(id) { $0.isCollapsed.toggle() } }
    }

    /// Deleting a folder unpins what it held: the tabs go back to Today.
    func deleteFolder(_ id: UUID) {
        for pin in pinStore.pins.pinned.folder(id)?.contents.tabs ?? [] {
            pinnedTabs[pin.id].map { releasePinnedTab($0) }
        }
        pinStore.change { _ = $0.removeFolder(id) }
    }

    /// File › Import Bookmarks…: another browser's bookmark file, chosen in
    /// an open panel, becomes a folder in Pinned.
    func importBookmarks() {
        guard let window = activeTab?.webView?.window ?? NSApp.keyWindow else { return }
        let panel = NSOpenPanel()
        panel.message = "Choose Safari's Bookmarks.plist or Chrome's Bookmarks file."
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Safari")
        Task {
            guard await panel.beginSheetModal(for: window) == .OK, let url = panel.url else { return }
            guard let data = try? Data(contentsOf: url), let bookmarks = try? BookmarkImport.bookmarks(from: data) else {
                toasts.show("Couldn't Read Bookmarks", symbol: ChromeSymbols.Navigation.loadFailed)
                return
            }
            let folder = SidebarFolder(
                name: "Imported from \(BookmarkImport.source(of: data).rawValue)",
                contents: SidebarTree(bookmarks.map(SidebarItem.init))
            )
            pinStore.change { $0.addFolder(folder) }
            toasts.show("Imported \(folder.contents.tabs.count) Bookmarks", symbol: ChromeSymbols.Tabs.folder)
        }
    }

    // MARK: Live tabs for the store's pins

    /// Matches the live tabs to the store's pins: a tab for each new pin,
    /// built asleep where it was left, and the tabs of pins that are gone
    /// closed, unless they're back in Today, as after an unpin here.
    private func reconcilePinnedTabs(with pins: Pins) {
        favorites = pins.favorites.map(liveTab)
        pinned = pins.pinned.map(liveTab)

        for (id, tab) in pinnedTabs where pins.pin(id) == nil {
            pinnedTabs[id] = nil
            pinnedTabRecorders[id] = nil
            guard !tabs.contains(where: { $0.id == id }) else { continue }
            tab.close()
            if id == activeTabID {
                if let next = tabsInDisplayOrder.first {
                    selectTab(next.id)
                } else {
                    addTab()
                }
            }
        }
    }

    private func liveTab(for pin: Pin) -> TabSession {
        if let tab = pinnedTabs[pin.id] {
            if tab.pinnedURL != pin.url { tab.pinnedURL = pin.url }
            return tab
        }
        let saved = pinStore.savedTab(for: pin.id)
            ?? SavedTab(url: pin.url, title: pin.title, customTitle: nil, interactionState: nil, lastUsedAt: nil)
        let tab = makeTab(id: pin.id, restoring: saved)
        tab.pinnedURL = pin.url
        adoptPinnedTab(tab)
        return tab
    }

    /// Takes a live tab in as a pin's, and keeps the store told where it is
    /// and what the pinned page is called. `@Published` announces a change
    /// before making it, so the record waits a turn of the main queue.
    private func adoptPinnedTab(_ tab: TabSession) {
        pinnedTabs[tab.id] = tab
        pinnedTabRecorders[tab.id] = tab.savedTabChanges
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak tab] in
                guard let self, let tab else { return }
                pinStore.record(tab.savedTab, for: tab.id)
                if !tab.isAwayFromPin, !tab.pageTitle.isEmpty {
                    pinStore.change { $0.update(tab.id) { $0.title = tab.pageTitle } }
                }
            }
    }

    /// Hands a pin's live tab back to Today: at the top, or where it was
    /// dropped, on the side of the target it came from.
    private func releasePinnedTab(_ tab: TabSession, onto target: UUID? = nil) {
        tab.pinnedURL = nil
        if let target, let index = tabs.firstIndex(where: { $0.id == target }) {
            tabs.insert(tab, at: tabLayout == .sidebar ? index : index + 1)
        } else {
            tabs.append(tab)
        }
    }

    func goBack() {
        activeTab?.goBack()
    }

    func goForward() {
        activeTab?.goForward()
    }

    func reloadOrStop() {
        guard let activeTab else { return }
        activeTab.isLoading ? activeTab.stopLoading() : activeTab.reload()
    }

}

private extension TabIdlePolicy.Tab {
    @MainActor
    init(_ tab: TabSession, isActive: Bool) {
        self.init(
            isActive: isActive,
            isAsleep: tab.isAsleep,
            hasPage: !tab.currentURL.isEmpty,
            isInUse: tab.isInUse,
            lastUsedAt: tab.lastUsedAt
        )
    }
}
