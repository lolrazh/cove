import SwiftUI

/// A tab's slot in the top strip or the sidebar. Opening grows the slot from
/// nothing along the list's axis, revealing the tab from its leading edge while
/// its neighbors make room. Closing shrinks the tab into the collapsing slot
/// as it fades: a small poof.
private struct ChromeTabSlot: ViewModifier {
    let axis: Axis
    let isCollapsed: Bool
    let isClosing: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(isClosing ? 0.8 : 1)
            .frame(
                width: axis == .horizontal && isCollapsed ? 0 : nil,
                height: axis == .vertical && isCollapsed ? 0 : nil,
                alignment: .topLeading
            )
            // Larger than the slot, so the active top tab's flares aren't cut off.
            .mask {
                Rectangle()
                    .padding(.horizontal, -ChromeRadius.flare)
                    .padding(.bottom, -ChromeMetrics.tabBottomInset)
            }
            .opacity(isCollapsed ? 0 : 1)
    }
}

extension AnyTransition {
    static func tabSlot(_ axis: Axis) -> AnyTransition {
        let open = ChromeTabSlot(axis: axis, isCollapsed: false, isClosing: false)
        return .asymmetric(
            insertion: .modifier(active: ChromeTabSlot(axis: axis, isCollapsed: true, isClosing: false), identity: open),
            removal: .modifier(active: ChromeTabSlot(axis: axis, isCollapsed: true, isClosing: true), identity: open)
        )
    }
}
