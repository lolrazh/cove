import SwiftUI

enum TabLayout: String {
    case horizontal
    case sidebar
}

@MainActor
final class TabManager: ObservableObject {
    @Published var tabs: [Tab] = []
    @Published var activeTabID: UUID?
    @Published var tabLayout: TabLayout = .horizontal
    @Published var isSidebarVisible: Bool = true

    func toggleLayout() {
        tabLayout = tabLayout == .horizontal ? .sidebar : .horizontal
    }

    var activeTab: Tab? {
        tabs.first { $0.id == activeTabID }
    }

    init() {
        addTab()
    }

    func addTab(url: String = "https://www.google.com") {
        let tab = Tab(url: url)
        tabs.append(tab)
        activeTabID = tab.id
    }

    func closeTab(_ id: UUID) {
        guard tabs.count > 1 else { return } // keep at least one tab

        if let index = tabs.firstIndex(where: { $0.id == id }) {
            let wasActive = (id == activeTabID)
            tabs.remove(at: index)

            if wasActive {
                // Activate the tab at the same index, or the last one
                let newIndex = min(index, tabs.count - 1)
                activeTabID = tabs[newIndex].id
            }
        }
    }

    func selectTab(_ id: UUID) {
        activeTabID = id
    }
}
