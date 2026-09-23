import SwiftUI

struct TabStripView: View {
    @ObservedObject var tabManager: TabManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Metrics {
        static let tabSpacing: CGFloat = 4
        static let minTabWidth: CGFloat = 100
        /// Tabs widen with the window: up to an eighth of the strip, within
        /// these bounds.
        static let maxTabWidthFraction: CGFloat = 1 / 8
        static let maxTabWidthRange: ClosedRange<CGFloat> = 120...220
    }

    private var tabOrder: [UUID] {
        tabManager.tabs.map(\.id)
    }

    private var tabAnimation: Animation? {
        reduceMotion ? nil : .smooth(duration: 0.18)
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
                .transition(.tabSlot)
            }
            Button(action: { tabManager.addTab() }) {
                Image(systemName: ChromeSymbols.Tabs.add)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(ChromeButtonStyle(size: .titlebar))
            .help("New Tab")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(tabAnimation, value: tabOrder)
    }

    private func resolvedSharedTabWidth(for availableWidth: CGFloat) -> CGFloat {
        let tabCount = max(tabManager.tabs.count, 1)
        let interTabSpacing = CGFloat(max(tabCount - 1, 0)) * Metrics.tabSpacing
        let nonTabReservation = Metrics.tabSpacing + ChromeMetrics.tabHeight
        let distributableWidth = max(0, availableWidth - nonTabReservation - interTabSpacing)
        let proposedWidth = distributableWidth / CGFloat(tabCount)

        let maxTabWidth = min(
            max(availableWidth * Metrics.maxTabWidthFraction, Metrics.maxTabWidthRange.lowerBound),
            Metrics.maxTabWidthRange.upperBound
        )
        return min(max(proposedWidth, Metrics.minTabWidth), maxTabWidth)
    }
}

/// Opening a tab grows its slot from nothing, revealing the tab from its leading
/// edge while its neighbors slide aside. Closing runs the same in reverse.
private struct TabSlot: ViewModifier {
    let isCollapsed: Bool

    func body(content: Content) -> some View {
        content
            .frame(width: isCollapsed ? 0 : nil, alignment: .leading)
            // Larger than the slot, so the active tab's flares aren't cut off.
            .mask {
                Rectangle()
                    .padding(.horizontal, -ChromeRadius.flare)
                    .padding(.bottom, -ChromeMetrics.tabBottomInset)
            }
            .opacity(isCollapsed ? 0 : 1)
    }
}

private extension AnyTransition {
    static var tabSlot: AnyTransition {
        .modifier(active: TabSlot(isCollapsed: true), identity: TabSlot(isCollapsed: false))
    }
}
