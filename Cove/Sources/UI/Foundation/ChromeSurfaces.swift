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

/// Hidden chrome arriving from a window edge: a short slide, or a crossfade
/// under Reduce Motion.
private struct ChromeSlide: ViewModifier {
    let isShown: Bool
    let hiddenOffset: CGSize

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .offset(isShown || reduceMotion ? .zero : hiddenOffset)
            .opacity(isShown || !reduceMotion ? 1 : 0)
            .allowsHitTesting(isShown)
            .accessibilityHidden(!isShown)
            .animation(reduceMotion ? ChromeMotion.chromeExit : (isShown ? ChromeMotion.slide : ChromeMotion.chromeExit), value: isShown)
    }
}

extension View {
    func chromeSlide(isShown: Bool, from hiddenOffset: CGSize) -> some View {
        modifier(ChromeSlide(isShown: isShown, hiddenOffset: hiddenOffset))
    }

    func chromeHoverSurface(
        restingFill: Bool = false,
        minimumRadius: CGFloat = ChromeRadius.control
    ) -> some View {
        modifier(ChromeHoverSurface(restingFill: restingFill, minimumRadius: minimumRadius))
    }

    /// A page's card: the page's color, clipped to the window's concentric
    /// corners and lifted off the frame by the card shadow.
    func chromeCard() -> some View {
        // Each corner follows its own window corner. A docked sidebar or top
        // tab strip moves only some corners away from the window edge.
        let shape = ConcentricRectangle(
            corners: .concentric(minimum: .fixed(ChromeRadius.control)),
            isUniform: false
        )
        return clipShape(shape)
            // A concentric clip also becomes the hit area, and resolves in the
            // wrong place: without this the card swallows clicks meant for the tabs.
            .contentShape(Rectangle())
            // The shadow sits behind the clip, or the clip would cut it off.
            .background {
                shape
                    .fill(ChromePalette.content)
                    .chromeShadow(.card)
            }
    }

    /// Chrome floating over the page, like the revealed sidebar or tab strip:
    /// the shell color, raised by a shadow alone, with no outline.
    func chromeFloatingSurface(minimumRadius: CGFloat = ChromeRadius.control) -> some View {
        background {
            ChromeAmbientBackground()
                .clipShape(ConcentricRectangle.chrome(minimum: minimumRadius))
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
