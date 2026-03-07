import SwiftUI

enum TabLayout: String {
    case horizontal
    case sidebar
}

@MainActor
final class TabManager: ObservableObject {
    @Published var tabs: [Tab] = []
    @Published var activeTabID: UUID?
    @Published var tabLayout: TabLayout
    @Published var areTabsVisible: Bool
    @Published private(set) var hideTabs: Bool

    private let settings = BrowserSettingsStore.shared

    var activeTab: Tab? {
        tabs.first { $0.id == activeTabID }
    }

    init() {
        let hide = settings.hideTabs
        self.tabLayout = settings.showsTabsInSidebar ? .sidebar : .horizontal
        self.hideTabs = hide
        self.areTabsVisible = !hide
        addTab()
    }

    func setLayout(_ layout: TabLayout) {
        guard tabLayout != layout else { return }
        tabLayout = layout
        areTabsVisible = !hideTabs
        settings.setShowsTabsInSidebar(layout == .sidebar)
    }

    func toggleLayout() {
        setLayout(tabLayout == .horizontal ? .sidebar : .horizontal)
    }

    func setHideTabs(_ hide: Bool) {
        hideTabs = hide
        areTabsVisible = !hide
        settings.setHideTabs(hide)
    }

    func addTab(url: String? = nil) {
        let tab: Tab

        if let url {
            tab = Tab(url: url, showsStartPage: false)
        } else {
            switch settings.destinationForNewTab() {
            case .startPage:
                tab = Tab(showsStartPage: true)
            case .url(let destination):
                tab = Tab(url: destination, showsStartPage: false)
            }
        }

        tabs.append(tab)
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

            tabs.remove(at: index)

            if let replacementID {
                activeTabID = replacementID
            }
        }
    }

    func selectTab(_ id: UUID) {
        activeTabID = id
    }

    func revealTabs() {
        withAnimation(ChromeMotion.shell) {
            areTabsVisible = true
        }
    }

    func hideTabsIfNeeded() {
        guard hideTabs else { return }
        withAnimation(ChromeMotion.shell) {
            areTabsVisible = false
        }
    }

}
