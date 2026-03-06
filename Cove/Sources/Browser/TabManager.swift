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

    var activeTab: Tab? {
        tabs.first { $0.id == activeTabID }
    }

    init() {
        tabLayout = settings.preferredTabLayout.tabLayout
        isSidebarVisible = settings.preferredTabLayout == .sidebar

        settings.$preferredTabLayout
            .removeDuplicates()
            .sink { [weak self] preferredLayout in
                self?.apply(layout: preferredLayout.tabLayout, persistsPreference: false)
            }
            .store(in: &cancellables)

        settings.$autoHideSidebar
            .removeDuplicates()
            .sink { [weak self] autoHide in
                guard let self else { return }
                if !autoHide && self.tabLayout == .sidebar {
                    self.isSidebarVisible = true
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
            if wasActive {
                let replacementID: UUID
                if index < tabs.count - 1 {
                    replacementID = tabs[index + 1].id
                } else {
                    replacementID = tabs[index - 1].id
                }
                activeTabID = replacementID
            }

            tabs.remove(at: index)
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
            isSidebarVisible = true
        } else {
            isSidebarVisible = false
        }

        if persistsPreference {
            let preferredLayout: PreferredTabLayout = layout == .horizontal ? .horizontal : .sidebar
            settings.setPreferredTabLayout(preferredLayout)
        }
    }
}
