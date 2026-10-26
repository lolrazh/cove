import SwiftUI

/// A text field on a quiet system fill that deepens on hover, the way Arc's
/// pill does. Focus shows the system focus ring color around the outside, as
/// native fields do, instead of a permanent outline. Callers pad their content
/// first; the fill wraps whatever it is given.
private struct ChromeFieldStyle: ViewModifier {
    let isFocused: Bool
    let minimumRadius: CGFloat

    @State private var isHovered = false

    func body(content: Content) -> some View {
        let shape = ConcentricRectangle.chrome(minimum: minimumRadius)

        content
            .background(fill, in: shape)
            .overlay {
                shape
                    .stroke(Color(nsColor: .keyboardFocusIndicatorColor), lineWidth: 3)
                    .opacity(isFocused ? 1 : 0)
            }
            .animation(ChromeMotion.hover, value: isFocused)
            .animation(ChromeMotion.hover, value: isHovered)
            .onHover { isHovered = $0 }
    }

    private var fill: AnyShapeStyle {
        isHovered && !isFocused ? AnyShapeStyle(ChromePalette.hover) : AnyShapeStyle(ChromePalette.resting)
    }
}

extension View {
    func chromeFieldStyle(focused isFocused: Bool, minimumRadius: CGFloat = ChromeRadius.control) -> some View {
        modifier(ChromeFieldStyle(isFocused: isFocused, minimumRadius: minimumRadius))
    }
}
