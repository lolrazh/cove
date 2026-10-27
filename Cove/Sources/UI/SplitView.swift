import SwiftUI

/// The split on screen: its tabs' pages side by side (or stacked), each in a
/// card of its own, with a divider to drag between each pair. A click in a
/// pane focuses it, and the focused pane is outlined in the accent color.
struct SplitPageView: View {
    let split: TabSplit<UUID>
    @ObservedObject var tabManager: TabManager
    let appServices: AppServices

    /// The gap between panes, which is also the divider's handle.
    private static let gap = ChromeMetrics.cardInset

    var body: some View {
        GeometryReader { geometry in
            let total = split.axis == .horizontal ? geometry.size.width : geometry.size.height
            let length = max(total - Self.gap * CGFloat(split.panes.count - 1), 0)
            let layout = split.axis == .horizontal ? AnyLayout(HStackLayout(spacing: 0)) : AnyLayout(VStackLayout(spacing: 0))

            layout {
                ForEach(Array(zip(split.panes.indices, panes)), id: \.1.id) { index, tab in
                    if index > 0 {
                        SplitDivider(axis: split.axis) { location in
                            // The divider's middle sits after the panes before
                            // it and the gaps between them.
                            let position = (location - Self.gap * (CGFloat(index) - 0.5)) / length
                            tabManager.moveSplitDivider(split.id, divider: index - 1, to: position)
                        }
                    }
                    SplitPane(tab: tab, isFocused: tab.id == tabManager.activeTabID, appServices: appServices) {
                        tabManager.selectTab(tab.id)
                    }
                        .frame(
                            width: split.axis == .horizontal ? length * split.fractions[index] : nil,
                            height: split.axis == .vertical ? length * split.fractions[index] : nil
                        )
                }
            }
            .coordinateSpace(.named(SplitDivider.space))
        }
        .background(ChromePalette.shell)
    }

    private var panes: [TabSession] {
        split.panes.compactMap(tabManager.tab)
    }
}

private struct SplitPane: View {
    let tab: TabSession
    let isFocused: Bool
    let appServices: AppServices
    /// A click on a start page; a click in a web view reaches the tab itself.
    let onFocus: () -> Void

    var body: some View {
        PageView(tab: tab, appServices: appServices)
            .simultaneousGesture(TapGesture().onEnded(onFocus))
            .chromeCard()
            .overlay {
                ConcentricRectangle.chrome()
                    .stroke(.tint, lineWidth: 2)
                    .padding(1)
                    .opacity(isFocused ? 0.6 : 0)
                    .animation(ChromeMotion.hover, value: isFocused)
                    .allowsHitTesting(false)
            }
    }
}

/// The gap between two panes: drag it to give one more room than the other.
private struct SplitDivider: View {
    static let space = "split"

    let axis: SplitAxis
    /// The pointer's place along the split's axis, in the split's space.
    let onDrag: (CGFloat) -> Void

    var body: some View {
        Color.clear
            .frame(
                width: axis == .horizontal ? ChromeMetrics.cardInset : nil,
                height: axis == .vertical ? ChromeMetrics.cardInset : nil
            )
            .contentShape(Rectangle())
            .pointerStyle(axis == .horizontal ? .columnResize : .rowResize)
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .named(Self.space))
                    .onChanged { drag in
                        onDrag(axis == .horizontal ? drag.location.x : drag.location.y)
                    }
            )
    }
}

/// While a Today tab is dragged over the page, its leading and trailing
/// edges take it into a split there, previewing where the pane would go.
struct SplitDropZones: View {
    @ObservedObject var tabManager: TabManager

    var body: some View {
        if let draggedTabID = tabManager.draggedTabID, tabManager.canOpenInSplitView(draggedTabID) {
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    SplitDropZone(placement: .leading, tabID: draggedTabID, tabManager: tabManager)
                        .frame(width: geometry.size.width / 4)
                    Spacer()
                    SplitDropZone(placement: .trailing, tabID: draggedTabID, tabManager: tabManager)
                        .frame(width: geometry.size.width / 4)
                }
            }
            .transition(.opacity)
        }
    }
}

private struct SplitDropZone: View {
    let placement: TabManager.SplitPlacement
    let tabID: UUID
    let tabManager: TabManager

    @State private var isTargeted = false

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .overlay {
                ConcentricRectangle.chrome()
                    .fill(.tint.opacity(0.18))
                    .stroke(.tint.opacity(0.5), lineWidth: 2)
                    .padding(ChromeMetrics.cardInset)
                    .opacity(isTargeted ? 1 : 0)
                    .animation(ChromeMotion.hover, value: isTargeted)
            }
            .onDrop(of: [.coveTab], isTargeted: $isTargeted) { _ in
                tabManager.draggedTabID = nil
                tabManager.openInSplitView(tabID, at: placement)
                return true
            }
    }
}
