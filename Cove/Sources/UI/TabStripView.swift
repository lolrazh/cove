import SwiftUI

struct TabStripView: View {
    @ObservedObject var tabManager: TabManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draggedTabID: UUID?

    private enum Metrics {
        static let tabSpacing: CGFloat = 4
        static let minTabWidth: CGFloat = 100
        /// Tabs widen with the window: up to an eighth of the strip, within
        /// these bounds.
        static let maxTabWidthFraction: CGFloat = 1 / 8
        static let maxTabWidthRange: ClosedRange<CGFloat> = 120...220
    }

    private var tabOrder: [UUID] {
        (pinnedTabs + tabManager.tabs).map(\.id)
    }

    /// Favorites and pinned tabs lead the strip as favicon-only tabs, like
    /// Safari's pinned tabs; the sidebar's folders are flattened.
    private var pinnedTabs: [TabSession] {
        tabManager.favorites + tabManager.pinned.tabs
    }

    private var tabAnimation: Animation? {
        reduceMotion ? nil : ChromeMotion.tab
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
            ForEach(pinnedTabs) { tab in
                tabItem(tab, presentation: .compact, width: ChromeMetrics.compactTabWidth)
            }
            ForEach(tabManager.tabs) { tab in
                tabItem(tab, presentation: .horizontal, width: sharedTabWidth)
            }
            Button(action: { tabManager.newTab() }) {
                Image(systemName: ChromeSymbols.Tabs.add)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(ChromeButtonStyle(size: .titlebar))
            .help("New Tab")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .acceptsTabDrops(dragging: $draggedTabID)
        .animation(tabAnimation, value: tabOrder)
    }

    private func tabItem(_ tab: TabSession, presentation: ChromeTabPresentation, width: CGFloat) -> some View {
        ChromeTabItem(
            tab: tab,
            tabManager: tabManager,
            presentation: presentation,
            isActive: tab.id == tabManager.activeTabID,
            canClose: tabManager.canCloseTab(tab.id),
            width: width
        )
        .reorderableTab(tab.id, in: tabManager, dragging: $draggedTabID)
        .background { WindowDragExclusion() }
        .transition(.tabSlot(.horizontal))
    }

    private func resolvedSharedTabWidth(for availableWidth: CGFloat) -> CGFloat {
        let tabCount = max(tabManager.tabs.count, 1)
        let interTabSpacing = CGFloat(max(tabCount - 1, 0)) * Metrics.tabSpacing
        let pinnedReservation = CGFloat(pinnedTabs.count) * (ChromeMetrics.compactTabWidth + Metrics.tabSpacing)
        let nonTabReservation = Metrics.tabSpacing + ChromeMetrics.tabHeight + pinnedReservation
        let distributableWidth = max(0, availableWidth - nonTabReservation - interTabSpacing)
        let proposedWidth = distributableWidth / CGFloat(tabCount)

        let maxTabWidth = min(
            max(availableWidth * Metrics.maxTabWidthFraction, Metrics.maxTabWidthRange.lowerBound),
            Metrics.maxTabWidthRange.upperBound
        )
        return min(max(proposedWidth, Metrics.minTabWidth), maxTabWidth)
    }
}

/// Keeps the window still when a drag starts on a top tab. The strip is in the
/// titlebar, where AppKit moves the window on any drag before SwiftUI sees it,
/// so the window is unmovable while the pointer is over a tab. The strip's
/// empty space still moves it.
private struct WindowDragExclusion: NSViewRepresentable {
    func makeNSView(context: Context) -> TrackingView {
        let view = TrackingView()
        // Follows the view's visible rect on its own.
        view.addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: view
        ))
        return view
    }

    func updateNSView(_ nsView: TrackingView, context: Context) {}

    final class TrackingView: NSView {
        private var isHovered = false {
            didSet { window?.isMovable = !isHovered }
        }

        override func mouseEntered(with event: NSEvent) {
            isHovered = true
        }

        override func mouseExited(with event: NSEvent) {
            isHovered = false
        }

        /// A tab closed under the pointer never sees it leave.
        override func viewWillMove(toWindow newWindow: NSWindow?) {
            if newWindow == nil, isHovered {
                isHovered = false
            }
        }
    }
}
