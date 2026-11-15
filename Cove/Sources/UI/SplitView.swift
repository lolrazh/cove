import SwiftUI

/// A stable page deck for both single and split pages. A pane keeps the same
/// SwiftUI identity and WebKit host while its frame changes.
struct SplitPageView: View {
    @ObservedObject var tabManager: TabManager
    let appServices: AppServices
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var previousIDs: [UUID] = []
    static let gap: CGFloat = 10

    private var panes: [TabSession] { tabManager.shownTabs }
    private var ids: [UUID] { panes.map(\.id) }
    private var axis: SplitAxis { tabManager.activeSplit?.axis ?? .horizontal }
    private var fractions: [Double] { tabManager.activeSplit?.fractions ?? [1] }
    private var animatesChange: Bool {
        !reduceMotion && !Set(previousIDs).isDisjoint(with: ids)
    }

    var body: some View {
        GeometryReader { geometry in
            let horizontal = axis == .horizontal
            let total = horizontal ? geometry.size.width : geometry.size.height
            let length = max(total - Self.gap * CGFloat(max(panes.count - 1, 0)), 1)
            ZStack(alignment: .topLeading) {
                ForEach(Array(panes.enumerated()), id: \.element.id) { index, tab in
                    let start = fractions.prefix(index).reduce(0, +) * length + Self.gap * CGFloat(index)
                    let extent = fractions[index] * length
                    VStack(spacing: 0) {
                        NavigationBar(session: tab, tabManager: tabManager,
                                      presentsSiteControls: tab.id == tabManager.activeTabID)
                        PageView(tab: tab, appServices: appServices, showsLoadingProgress: false)
                            .overlay { BoostEditorOverlay(tabManager: tabManager, page: tab) }
                            .overlay { CaptureOverlay(tabManager: tabManager, page: tab) }
                    }
                    .simultaneousGesture(TapGesture().onEnded { tabManager.selectTab(tab.id) })
                    .chromeCard()
                    .overlay {
                        ConcentricRectangle.chrome()
                            .stroke(.tint.opacity(panes.count > 1 && tab.id == tabManager.activeTabID ? 0.45 : 0), lineWidth: 1)
                            .padding(0.5).allowsHitTesting(false)
                    }
                    .frame(width: horizontal ? extent : geometry.size.width,
                           height: horizontal ? geometry.size.height : extent)
                    .offset(x: horizontal ? start : 0, y: horizontal ? 0 : start)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
                if let split = tabManager.activeSplit {
                    ForEach(Array(split.dividers.enumerated()), id: \.offset) { index, position in
                        let start = position * length + Self.gap * CGFloat(index)
                        SplitDivider(axis: axis, onReset: { tabManager.equalizeSplit(split.id) }) { location in
                            let position = (location - Self.gap * (CGFloat(index) + 0.5)) / length
                            tabManager.moveSplitDivider(split.id, divider: index, to: position,
                                                        minimumFraction: min(220 / length, 1 / Double(panes.count)))
                        }
                        .frame(width: horizontal ? Self.gap : geometry.size.width,
                               height: horizontal ? geometry.size.height : Self.gap)
                        .offset(x: horizontal ? start : 0, y: horizontal ? 0 : start)
                    }
                }
            }
            .animation(animatesChange ? .spring(response: 0.34, dampingFraction: 0.88) : nil, value: ids)
            .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.88), value: axis)
            .coordinateSpace(.named(SplitDivider.space))
        }
        .background(ChromePalette.shell)
        .onChange(of: ids, initial: true) { _, ids in previousIDs = ids }
    }
}

private struct SplitDivider: View {
    static let space = "split"
    let axis: SplitAxis
    let onReset: () -> Void
    let onDrag: (CGFloat) -> Void
    @State private var hovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Color.clear
            .overlay {
                Capsule().fill(.primary.opacity(hovered ? 0.22 : 0.08))
                    .frame(width: axis == .horizontal ? 3 : 28, height: axis == .horizontal ? 28 : 3)
            }
            .contentShape(Rectangle())
            .pointerStyle(axis == .horizontal ? .columnResize : .rowResize)
            .onHover { hovered = $0 }
            .onTapGesture(count: 2) {
                withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.88), onReset)
            }
            .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .named(Self.space))
                .onChanged { onDrag(axis == .horizontal ? $0.location.x : $0.location.y) })
            .accessibilityLabel("Resize split panes")
            .accessibilityAction(named: "Equal sizes", onReset)
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
