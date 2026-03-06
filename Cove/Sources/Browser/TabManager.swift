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

    func addTab(url: String? = nil) {
        let tab = Tab(url: url)
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
}
