import SwiftUI

enum ChromeButtonKind {
    case toolbar
    case tabAccessory
    case panelAction
    case row
}

struct ChromeButtonStyle: ButtonStyle {
    var kind: ChromeButtonKind = .toolbar
    var isSelected: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        ChromeButtonBody(configuration: configuration, kind: kind, isSelected: isSelected)
    }
}

private struct ChromeButtonBody: View {
    let configuration: ButtonStyle.Configuration
    let kind: ChromeButtonKind
    let isSelected: Bool

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        let metrics = self.metrics
        let shape = RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)

        return configuration.label
            .frame(
                minWidth: metrics.minWidth,
                maxWidth: metrics.fillsWidth ? .infinity : nil,
                minHeight: metrics.minHeight,
                alignment: metrics.alignment
            )
            .padding(.horizontal, metrics.horizontalPadding)
            .padding(.vertical, metrics.verticalPadding)
            .background {
                shape.fill(backgroundColor)
            }
            .overlay {
                if metrics.drawsBorder {
                    shape.stroke(borderColor, lineWidth: 1)
                }
            }
            .contentShape(shape)
            .opacity(isEnabled ? 1 : ChromeOpacity.disabled)
            .scaleEffect(metrics.supportsPressScale && configuration.isPressed ? 0.98 : 1)
            .animation(ChromeMotion.hover, value: isHovered)
            .animation(ChromeMotion.press, value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }

    private var backgroundColor: Color {
        if configuration.isPressed {
            return ChromePalette.pressedFill
        }
        if isSelected {
            return ChromePalette.selectedFill
        }
        if isHovered {
            return ChromePalette.hoverFill
        }
        return .clear
    }

    private var borderColor: Color {
        if isSelected {
            return ChromePalette.chromeStrokeStrong
        }
        if isHovered || configuration.isPressed {
            return ChromePalette.chromeStroke
        }
        return ChromePalette.fieldStroke.opacity(0.75)
    }

    private var metrics: ChromeButtonMetrics {
        switch kind {
        case .toolbar:
            return ChromeButtonMetrics(
                minWidth: ChromeMetrics.iconButtonSize.width,
                minHeight: ChromeMetrics.iconButtonSize.height,
                horizontalPadding: 0,
                verticalPadding: 0,
                cornerRadius: ChromeMetrics.controlCornerRadius,
                drawsBorder: false,
                fillsWidth: false,
                alignment: .center,
                supportsPressScale: true
            )
        case .tabAccessory:
            return ChromeButtonMetrics(
                minWidth: 18,
                minHeight: 18,
                horizontalPadding: 0,
                verticalPadding: 0,
                cornerRadius: 6,
                drawsBorder: false,
                fillsWidth: false,
                alignment: .center,
                supportsPressScale: true
            )
        case .panelAction:
            return ChromeButtonMetrics(
                minWidth: nil,
                minHeight: 28,
                horizontalPadding: 8,
                verticalPadding: 0,
                cornerRadius: 8,
                drawsBorder: false,
                fillsWidth: false,
                alignment: .center,
                supportsPressScale: true
            )
        case .row:
            return ChromeButtonMetrics(
                minWidth: nil,
                minHeight: nil,
                horizontalPadding: 0,
                verticalPadding: 0,
                cornerRadius: ChromeMetrics.controlCornerRadius,
                drawsBorder: false,
                fillsWidth: true,
                alignment: .leading,
                supportsPressScale: false
            )
        }
    }
}

private struct ChromeButtonMetrics {
    let minWidth: CGFloat?
    let minHeight: CGFloat?
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let cornerRadius: CGFloat
    let drawsBorder: Bool
    let fillsWidth: Bool
    let alignment: Alignment
    let supportsPressScale: Bool
}
