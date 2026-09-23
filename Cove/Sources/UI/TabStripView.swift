import SwiftUI

struct TabStripView: View {
    @ObservedObject var tabManager: TabManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Metrics {
        static let tabSpacing: CGFloat = 4
        static let horizontalPadding: CGFloat = 0
        static let minTabWidth: CGFloat = 112
        static let maxTabWidth: CGFloat = 200
    }

    private var tabOrder: [UUID] {
        tabManager.tabs.map(\.id)
    }

    private var tabReorderAnimation: Animation? {
        reduceMotion ? nil : .snappy(duration: 0.16, extraBounce: 0.02)
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal, showsIndicators: false) {
                tabRow(availableWidth: geometry.size.width)
                    .frame(
                        minWidth: geometry.size.width,
                        minHeight: ChromeMetrics.tabHeight,
                        maxHeight: ChromeMetrics.tabHeight,
                        alignment: .leading
                    )
            }
            // The active tab reaches below the strip into the content card.
            .scrollClipDisabled()
        }
        .frame(height: ChromeMetrics.tabHeight)
    }

    private func tabRow(availableWidth: CGFloat) -> some View {
        let sharedTabWidth = resolvedSharedTabWidth(for: availableWidth)

        return HStack(spacing: Metrics.tabSpacing) {
            ForEach(tabManager.tabs) { tab in
                ChromeTabItem(
                    tab: tab,
                    presentation: .horizontal,
                    isActive: tab.id == tabManager.activeTabID,
                    onSelect: { tabManager.selectTab(tab.id) },
                    onClose: { tabManager.closeTab(tab.id) },
                    canClose: tabManager.tabs.count > 1,
                    width: sharedTabWidth
                )
            }
            Button(action: { tabManager.addTab() }) {
                Image(systemName: ChromeSymbols.Tabs.add)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(ChromeButtonStyle())
            .help("New tab")
        }
        .padding(.horizontal, Metrics.horizontalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(tabReorderAnimation, value: tabOrder)
    }

    private func resolvedSharedTabWidth(for availableWidth: CGFloat) -> CGFloat {
        let tabCount = max(tabManager.tabs.count, 1)
        let interTabSpacing = CGFloat(max(tabCount - 1, 0)) * Metrics.tabSpacing
        let nonTabReservation =
            (Metrics.horizontalPadding * 2) +
            Metrics.tabSpacing +
            ChromeMetrics.iconButtonSize
        let distributableWidth = max(0, availableWidth - nonTabReservation - interTabSpacing)
        let proposedWidth = distributableWidth / CGFloat(tabCount)

        return min(max(proposedWidth, Metrics.minTabWidth), Metrics.maxTabWidth)
    }
}
