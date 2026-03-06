import SwiftUI
import Combine

enum TabLayout: String {
    case horizontal
    case sidebar
}

@MainActor
final class TabManager: ObservableObject {
    @Published var tabs: [Tab] = []
    @Published var activeTabID: UUID?
    @Published var tabLayout: TabLayout
    @Published var isSidebarVisible: Bool

    private let settings = BrowserSettingsStore.shared
    private var cancellables: Set<AnyCancellable> = []

    func toggleLayout() {
        let nextLayout: TabLayout = tabLayout == .horizontal ? .sidebar : .horizontal
        apply(layout: nextLayout, persistsPreference: true)
    }

    func setLayout(_ layout: TabLayout) {
        apply(layout: layout, persistsPreference: true)
    }

    var activeTab: Tab? {
        tabs.first { $0.id == activeTabID }
    }

    init() {
        tabLayout = settings.showsTabsInSidebar ? .sidebar : .horizontal
        isSidebarVisible = settings.showsTabsInSidebar ? !settings.hideTabs : false

        settings.$showsTabsInSidebar
            .sink { [weak self] showsTabsInSidebar in
                self?.apply(layout: showsTabsInSidebar ? .sidebar : .horizontal, persistsPreference: false)
            }
            .store(in: &cancellables)

        settings.$hideTabs
            .removeDuplicates()
            .sink { [weak self] hideTabs in
                guard let self else { return }
                if self.tabLayout == .sidebar {
                    self.isSidebarVisible = !hideTabs
                }
            }
            .store(in: &cancellables)

        addTab()
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

    func revealSidebar() {
        guard tabLayout == .sidebar else { return }
        withAnimation(ChromeMotion.shell) {
            isSidebarVisible = true
        }
    }

    private func apply(layout: TabLayout, persistsPreference: Bool) {
        tabLayout = layout

        if layout == .sidebar {
            isSidebarVisible = !settings.hideTabs
        } else {
            isSidebarVisible = false
        }

        if persistsPreference {
            settings.setShowsTabsInSidebar(layout == .sidebar)
        }
    }
}
