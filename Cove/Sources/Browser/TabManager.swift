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
    @Published var activeTabID: UUID?
    @Published var tabLayout: TabLayout
    @Published private(set) var hideTabs: Bool
    /// Confirmations shown over this window's page.
    let toasts = ToastCenter()

    private let settings: BrowserSettingsStore
    private let services: TabSessionServices
    private let recentlyClosed: RecentlyClosedTabs
    private var cancellables: Set<AnyCancellable> = []

    /// This window's Command Bar. Lazy only because it needs `self`.
    private(set) lazy var commandBar = CommandBarModel(
        tabManager: self,
        settings: settings,
        historyStore: services.historyStore,
        faviconStore: services.faviconStore,
        recentlyClosed: recentlyClosed
    )

    var activeTab: TabSession? {
        tabs.first { $0.id == activeTabID }
    }

    /// The tabs as they're shown: top to bottom in the sidebar, where Today
    /// lists the newest first, or left to right in the strip. Switching with
    /// the keyboard, dragging, and Close Tabs Below all follow this order.
    var tabsInDisplayOrder: [TabSession] {
        tabLayout == .sidebar ? tabs.reversed() : tabs
    }

    init(
        settings: BrowserSettingsStore,
        services: TabSessionServices,
        recentlyClosed: RecentlyClosedTabs,
        session: SessionStore
    ) {
        self.settings = settings
        self.services = services
        self.recentlyClosed = recentlyClosed
        self.tabLayout = settings.showsTabsInSidebar ? .sidebar : .horizontal
        self.hideTabs = settings.hideTabs
        bindSettings()

        let saved = session.takeRestorableWindow()
        if let saved, !saved.tabs.isEmpty {
            tabs = saved.tabs.map { makeTab(restoring: $0) }
            activeTabID = tabs[min(saved.activeTabIndex, tabs.count - 1)].id
        } else {
            addTab()
        }
        session.track(self, placement: saved?.placement)
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

            let closed = tabs.remove(at: index)
            closed.close()
            recentlyClosed.record(url: closed.currentURL, title: closed.pageTitle)

            if let replacementID {
                activeTabID = replacementID
            }
        }
    }

    /// Reopens a recently closed tab, or the most recently closed one.
    func reopenClosedTab(_ id: UUID? = nil) {
        guard let entry = recentlyClosed.take(id) else { return }
        addTab(url: entry.url)
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
