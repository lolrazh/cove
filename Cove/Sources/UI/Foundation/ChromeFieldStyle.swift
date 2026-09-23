import SwiftUI

/// A text field on a quiet system fill. Focus shows the system focus ring color
/// around the outside, the way native fields do, instead of a permanent outline.
private struct ChromeFieldStyle: ViewModifier {
    let isFocused: Bool
    let isLarge: Bool

    func body(content: Content) -> some View {
        let shape = ConcentricRectangle.chrome(minimum: isLarge ? ChromeRadius.tile : ChromeRadius.control)

        content
            .padding(.horizontal, isLarge ? 16 : 10)
            .padding(.vertical, isLarge ? 11 : 5)
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
    func chromeFieldStyle(focused isFocused: Bool, large: Bool = false) -> some View {
        modifier(ChromeFieldStyle(isFocused: isFocused, isLarge: large))
    }
}
