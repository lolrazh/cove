import SwiftUI
import Foundation
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
    @Published private(set) var hideTabs: Bool

    private let settings: BrowserSettingsStore
    private var cancellables: Set<AnyCancellable> = []

    var activeTab: Tab? {
        tabs.first { $0.id == activeTabID }
    }

    init(settings: BrowserSettingsStore = .shared) {
        self.settings = settings
        self.tabLayout = settings.showsTabsInSidebar ? .sidebar : .horizontal
        self.hideTabs = settings.hideTabs
        bindSettings()
        addTab()
    }

    func setLayout(_ layout: TabLayout) {
        settings.setShowsTabsInSidebar(layout == .sidebar)
    }

    func toggleLayout() {
        setLayout(tabLayout == .horizontal ? .sidebar : .horizontal)
    }

    func setHideTabs(_ hide: Bool) {
        settings.setHideTabs(hide)
    }

    func addTab(url: String? = nil) {
        let tab: Tab

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

    func addTab(request: URLRequest) {
        let tab = makeTab(initialRequest: request, showsStartPage: false)
        open(tab)
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
        showsStartPage: Bool = false
    ) -> Tab {
        Tab(
            initialURL: initialURL,
            initialRequest: initialRequest,
            showsStartPage: showsStartPage
        ) { [weak self] request in
            self?.addTab(request: request)
        }
    }

    private func open(_ tab: Tab) {
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

}
