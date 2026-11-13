import SwiftUI

/// A tab's slot in the top strip. Sidebar rows appear in place while their
/// list moves the surrounding rows; closed rows leave immediately.
private struct ChromeTabSlot: ViewModifier {
    let axis: Axis
    let isCollapsed: Bool
    let isClosing: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(isClosing ? 0.97 : 1)
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
        if axis == .vertical {
            // Normal insertions in the Dia recording are already opaque and
            // at their destination in the first changed frame. Its separate
            // offset-and-fade reveal path is not used for these insertions.
            return .asymmetric(
                insertion: .identity,
                removal: .opacity.animation(.linear(duration: 0))
            )
        }
        let open = ChromeTabSlot(axis: axis, isCollapsed: false, isClosing: false)
        return .asymmetric(
            insertion: .modifier(active: ChromeTabSlot(axis: axis, isCollapsed: true, isClosing: false), identity: open),
            removal: .modifier(active: ChromeTabSlot(axis: axis, isCollapsed: true, isClosing: true), identity: open)
        )
    }
}
