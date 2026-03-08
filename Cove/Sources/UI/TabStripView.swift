import SwiftUI

struct TabStripView: View {
    @ObservedObject var tabManager: TabManager
    var laneHeight: CGFloat = ChromeMetrics.topStripLaneHeight
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Metrics {
        static let tabSpacing: CGFloat = 4
        static let horizontalPadding: CGFloat = 2
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
                        minHeight: laneHeight,
                        maxHeight: laneHeight,
                        alignment: .leading
                    )
            }
        }
        .frame(height: laneHeight)
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
                    horizontalWidth: sharedTabWidth
                )
            }
            Button(action: { tabManager.addTab() }) {
                Image(systemName: ChromeSymbols.Tabs.add)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(ChromeButtonStyle(kind: .toolbar))
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
            ChromeMetrics.iconButtonSize.width
        let distributableWidth = max(0, availableWidth - nonTabReservation - interTabSpacing)
        let proposedWidth = distributableWidth / CGFloat(tabCount)

        return min(max(proposedWidth, Metrics.minTabWidth), Metrics.maxTabWidth)
    }
}
