import SwiftUI

/// A text field on a quiet system fill. Focus shows the system focus ring color
/// around the outside, the way native fields do, instead of a permanent outline.
/// Callers pad their content first; the fill wraps whatever it is given.
private struct ChromeFieldStyle: ViewModifier {
    let isFocused: Bool
    let minimumRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = ConcentricRectangle.chrome(minimum: minimumRadius)

        content
            .background(ChromePalette.resting, in: shape)
            .overlay {
                shape
                    .stroke(Color(nsColor: .keyboardFocusIndicatorColor), lineWidth: 3)
                    .opacity(isFocused ? 1 : 0)
            }
            .animation(ChromeMotion.hover, value: isFocused)
    }
}

extension View {
    func chromeFieldStyle(focused isFocused: Bool, minimumRadius: CGFloat = ChromeRadius.control) -> some View {
        modifier(ChromeFieldStyle(isFocused: isFocused, minimumRadius: minimumRadius))
    }
}
