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
            .contentShape(shape)
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
        if configuration.isPressed { return AnyShapeStyle(.fill.secondary) }
        if isHovered && isEnabled { return AnyShapeStyle(.fill.tertiary) }
        return AnyShapeStyle(.clear)
    }
}

/// Hover and selection for things that behave like buttons but hold their own
/// controls, such as tabs with a close button.
private struct ChromeHoverSurface: ViewModifier {
    let isSelected: Bool
    let restingFill: Bool
    let minimumRadius: CGFloat

    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .background(fill, in: .chrome(minimum: minimumRadius))
            .contentShape(.chrome(minimum: minimumRadius))
            .animation(ChromeMotion.hover, value: isHovered)
            .onHover { isHovered = $0 }
    }

    private var fill: AnyShapeStyle {
        if isSelected { return AnyShapeStyle(.fill.secondary) }
        if isHovered { return AnyShapeStyle(.fill.tertiary) }
        if restingFill { return AnyShapeStyle(.fill.quaternary) }
        return AnyShapeStyle(.clear)
    }
}

extension View {
    func chromeHoverSurface(
        isSelected: Bool = false,
        restingFill: Bool = false,
        minimumRadius: CGFloat = ChromeRadius.control
    ) -> some View {
        modifier(ChromeHoverSurface(isSelected: isSelected, restingFill: restingFill, minimumRadius: minimumRadius))
    }
}
