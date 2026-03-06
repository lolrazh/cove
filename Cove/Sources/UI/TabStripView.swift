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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
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
                .animation(tabReorderAnimation, value: tabOrder)

                Button(action: { tabManager.addTab() }) {
                    Image(systemName: ChromeSymbols.Tabs.add)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(ChromeButtonStyle(kind: .toolbar))
                .help("New tab")
            }
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: ChromeMetrics.tabStripHeight)
    }
}
