import SwiftUI

/// Hover for things that act like buttons but hold their own controls, such as
/// rows with an action button.
private struct ChromeHoverSurface: ViewModifier {
    let restingFill: Bool
    let minimumRadius: CGFloat

    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .background(fill, in: .chrome(minimum: minimumRadius))
            .contentShape(Rectangle())
            .animation(ChromeMotion.hover, value: isHovered)
            .onHover { isHovered = $0 }
    }

    private var fill: AnyShapeStyle {
        if isHovered { return AnyShapeStyle(ChromePalette.hover) }
        if restingFill { return AnyShapeStyle(ChromePalette.resting) }
        return AnyShapeStyle(.clear)
    }
}

extension View {
    func chromeHoverSurface(
        restingFill: Bool = false,
        minimumRadius: CGFloat = ChromeRadius.control
    ) -> some View {
        modifier(ChromeHoverSurface(restingFill: restingFill, minimumRadius: minimumRadius))
    }

    /// Chrome floating over the page, like the revealed sidebar or tab strip:
    /// the shell color, raised by a shadow alone, with no outline.
    func chromeFloatingSurface(minimumRadius: CGFloat = ChromeRadius.control) -> some View {
        background {
            ConcentricRectangle.chrome(minimum: minimumRadius)
                .fill(ChromePalette.shell)
                .chromeShadow(.floating)
        }
    }
}

private struct ChromeShadowModifier: ViewModifier {
    let level: ChromeShadow
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.shadow(
            color: .black.opacity(level.opacity(in: colorScheme)),
            radius: level.radius,
            y: level.y
        )
    }
}

extension View {
    func chromeShadow(_ level: ChromeShadow) -> some View {
        modifier(ChromeShadowModifier(level: level))
    }
}
