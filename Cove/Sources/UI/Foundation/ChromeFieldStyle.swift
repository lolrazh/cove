import SwiftUI

/// A text field on a quiet system fill that deepens on hover, the way Arc's
/// pill does. Focus uses a fine theme-colored outline, with the stronger system
/// ring under Increased Contrast. Callers pad their content
/// first; the fill wraps whatever it is given.
private struct ChromeFieldStyle: ViewModifier {
    let isFocused: Bool
    let minimumRadius: CGFloat

    @State private var isHovered = false
    @Environment(\.chromeTheme) private var theme
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let shape = ConcentricRectangle.chrome(minimum: minimumRadius)

        content
            .background(fill, in: shape)
            .overlay {
                shape
                    .stroke(contrast == .increased ? Color(nsColor: .keyboardFocusIndicatorColor) : (theme.tint ?? .accentColor),
                            lineWidth: contrast == .increased ? 3 : 1)
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
