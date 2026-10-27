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
    /// Arc's sections above Today. Nothing moves tabs into them yet; the
    /// sidebar already lays them out so pinning and favorites slot in.
    @Published private(set) var favorites: [TabSession] = []
    @Published private(set) var pinned: [TabSession] = []
    /// The selected tab is the one on screen, so it's always awake; the
    /// others may sleep once they've been left alone long enough.
    @Published var activeTabID: UUID? {
        didSet {
            tabs.first { $0.id == oldValue }?.markUsed()
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
    private let sweepClock = TabSweepClock()
    private var cancellables: Set<AnyCancellable> = []

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
        tabs.first { $0.id == activeTabID }
    }

    /// The tabs as they're shown: top to bottom in the sidebar, where Today
    /// lists the newest first, or left to right in the strip. Switching with
    /// the keyboard, dragging, and Close Tabs Below all follow this order.
    var tabsInDisplayOrder: [TabSession] {
        tabLayout == .sidebar ? tabs.reversed() : tabs
    }

    /// A private window passes an in-memory archive and no session, so
    /// nothing of it is written down or comes back.
    init(
        settings: BrowserSettingsStore,
        services: TabSessionServices,
        archive: TabArchive,
        session: SessionStore?
    ) {
        self.settings = settings
        self.services = services
        self.archive = archive
        self.tabLayout = settings.showsTabsInSidebar ? .sidebar : .horizontal
        self.hideTabs = settings.hideTabs
        bindSettings()
        trackMedia()
        sweepClock.ticks
            .sink { [weak self] underMemoryPressure in self?.sweepIdleTabs(underMemoryPressure: underMemoryPressure) }
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
        let mediaChanged = $tabs
            .map { tabs in Publishers.MergeMany(tabs.map { $0.$nowPlaying.map { _ in } }) }
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
        initialURL: String? = nil,
        initialRequest: URLRequest? = nil,
        showsStartPage: Bool = false,
        restoring saved: SavedTab? = nil
    ) -> TabSession {
        let tabID = UUID()

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

    func closeTab(_ id: UUID) {
        guard tabs.count > 1 else { return }

        if let index = tabs.firstIndex(where: { $0.id == id }) {
            let wasActive = (id == activeTabID)
            let replacementID: UUID? = if wasActive {
                if index < tabs.count - 1 {
                    tabs[index + 1].id
                } else {
                    tabs[index - 1].id
                }
            } else {
                nil
            }

            // Into the archive, as in Arc, where it keeps its back/forward
            // list for Reopen Last Closed Tab.
            let closed = tabs.remove(at: index)
            closed.close()
            archive.add(closed.savedTab, reason: .closed)

            if let replacementID {
                activeTabID = replacementID
            }
        }
    }

    /// Reopens the most recently closed tab.
    func reopenClosedTab() {
        guard let closed = archive.lastClosed else { return }
        reopenArchivedTab(closed.id)
    }

    // MARK: - Idle tabs

    /// Sleeps background tabs idle past the setting and archives Today tabs
    /// idle past theirs. Short of memory, every background tab that can sleep
    /// does.
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

    /// Drag and drop: the dragged tab takes the place of the one under it.
    func moveTab(_ id: UUID, onto target: UUID) {
        tabs.move(id, onto: target)
    }

    /// A copy of the tab beside it, back and forward history included.
    func duplicateTab(_ id: UUID) {
        guard let tab = tabs.first(where: { $0.id == id }) else { return }
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

    /// Closes the tabs shown after this one: below it in the sidebar, to its
    /// right in the strip. It becomes active if the active tab is among them.
    func closeTabs(below id: UUID) {
        let closing = tabsInDisplayOrder.elements(after: id)
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
