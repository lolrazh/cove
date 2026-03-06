import SwiftUI

enum ChromeFieldProminence {
    case compact
    case regular
    case hero
}

struct ChromeFieldStyle: ViewModifier {
    let isFocused: Bool
    var prominence: ChromeFieldProminence = .regular

    func body(content: Content) -> some View {
        let metrics = self.metrics
        let shape = RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)

        return content
            .padding(.horizontal, metrics.horizontalPadding)
            .padding(.vertical, metrics.verticalPadding)
            .background {
                shape.fill(ChromePalette.fieldFill)
            }
            .overlay {
                shape.stroke(isFocused ? ChromePalette.fieldFocusStroke : ChromePalette.fieldStroke, lineWidth: 1)
            }
            .contentShape(shape)
            .animation(ChromeMotion.hover, value: isFocused)
    }

    private var metrics: ChromeFieldMetrics {
        switch prominence {
        case .compact:
            return ChromeFieldMetrics(horizontalPadding: 10, verticalPadding: 6, cornerRadius: 10)
        case .regular:
            return ChromeFieldMetrics(horizontalPadding: 12, verticalPadding: 7, cornerRadius: ChromeMetrics.fieldCornerRadius)
        case .hero:
            return ChromeFieldMetrics(horizontalPadding: 16, verticalPadding: 11, cornerRadius: 14)
        }
    }
}

private struct ChromeFieldMetrics {
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let cornerRadius: CGFloat
}

extension View {
    func chromeFieldStyle(
        focused isFocused: Bool,
        prominence: ChromeFieldProminence = .regular
    ) -> some View {
        modifier(ChromeFieldStyle(isFocused: isFocused, prominence: prominence))
    }
}
