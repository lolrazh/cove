import SwiftUI

struct TabStripView: View {
    @ObservedObject var tabManager: TabManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var tabOrder: [UUID] {
        tabManager.tabs.map(\.id)
    }

    private var tabReorderAnimation: Animation? {
        reduceMotion ? nil : .snappy(duration: 0.16, extraBounce: 0.02)
    }

    var body: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(tabManager.tabs) { tab in
                        ChromeTabItem(
                            tab: tab,
                            presentation: .horizontal,
                            isActive: tab.id == tabManager.activeTabID,
                            onSelect: { tabManager.selectTab(tab.id) },
                            onClose: { tabManager.closeTab(tab.id) },
                            canClose: tabManager.tabs.count > 1
                        )
                    }
                }
                .padding(.horizontal, 2)
                .animation(tabReorderAnimation, value: tabOrder)
            }

            Button(action: { tabManager.addTab() }) {
                Image(systemName: ChromeSymbols.Tabs.add)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(ChromeButtonStyle(kind: .toolbar))
            .help("New tab")

            Button(action: {
                withAnimation(ChromeMotion.shell) {
                    tabManager.toggleLayout()
                }
            }) {
                layoutToggleIcon
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(ChromeButtonStyle(kind: .toolbar))
            .help("Switch to sidebar tabs")
        }
        .frame(height: ChromeMetrics.tabStripHeight)
    }

    private var layoutToggleIcon: some View {
        let icon = Image(systemName: ChromeSymbols.Tabs.sidebarLayout)
            .font(.system(size: 11, weight: .medium))

        return Group {
            if reduceMotion {
                icon
            } else {
                icon.symbolEffect(.bounce, value: tabManager.tabLayout)
            }
        }
    }
}
