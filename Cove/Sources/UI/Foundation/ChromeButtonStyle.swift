import SwiftUI

/// A borderless chrome button: nothing at rest, a system fill on hover and press.
struct ChromeButtonStyle: ButtonStyle {
    enum Size {
        /// A square icon button, sized for the navigation bar and tab row.
        case icon
        /// A small accessory inside a row, like a tab's close button.
        case accessory
        /// A full-width list row.
        case row
    }

    var size: Size = .icon

    func makeBody(configuration: Configuration) -> some View {
        ChromeButtonBody(configuration: configuration, size: size)
    }
}

private struct ChromeButtonBody: View {
    let configuration: ButtonStyle.Configuration
    let size: ChromeButtonStyle.Size

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        configuration.label
            .font(font)
            .frame(minWidth: side, minHeight: side)
            .frame(maxWidth: size == .row ? .infinity : nil, alignment: size == .row ? .leading : .center)
            .background(fill, in: shape)
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed && size != .row ? 0.96 : 1)
            .animation(ChromeMotion.hover, value: isHovered)
            .animation(ChromeMotion.press, value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }

    private var shape: ConcentricRectangle {
        .chrome(minimum: size == .accessory ? ChromeRadius.accessory : ChromeRadius.control)
    }

    /// Icons size themselves from this; call sites don't set fonts.
    private var font: Font? {
        switch size {
        case .icon: .body.weight(.medium)
        case .accessory: .subheadline.weight(.semibold)
        case .row: nil
        }
    }

    private var side: CGFloat? {
        switch size {
        case .icon: ChromeMetrics.iconButtonSize
        case .accessory: 20
        case .row: nil
        }
    }

    private var fill: AnyShapeStyle {
        if configuration.isPressed { return AnyShapeStyle(ChromePalette.pressed) }
        if isHovered && isEnabled { return AnyShapeStyle(ChromePalette.hover) }
        return AnyShapeStyle(.clear)
    }
}

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
}
