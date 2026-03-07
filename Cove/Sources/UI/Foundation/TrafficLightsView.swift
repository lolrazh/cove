import SwiftUI
import AppKit

struct TrafficLightsView: View {
    var isVisible: Bool

    @Environment(\.controlActiveState) private var controlActiveState
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            trafficLightButton(.close)
            trafficLightButton(.minimize)
            trafficLightButton(.zoom)
        }
        .onHover { isHovering = $0 }
        .opacity(isVisible ? 1 : 0)
        .animation(.easeInOut(duration: 0.18), value: isVisible)
    }

    private func trafficLightButton(_ type: TrafficLightType) -> some View {
        Button(action: type.performAction) {
            EmptyView()
        }
        .buttonStyle(TrafficLightButtonStyle(
            type: type,
            isHovering: isHovering,
            isWindowActive: controlActiveState == .key
        ))
    }
}

// MARK: - Button Type

private enum TrafficLightType {
    case close, minimize, zoom

    func performAction() {
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { return }
        switch self {
        case .close: window.close()
        case .minimize: window.miniaturize(nil)
        case .zoom: window.zoom(nil)
        }
    }

    var activeColor: Color {
        switch self {
        case .close: Color(red: 1.0, green: 0.373, blue: 0.337)
        case .minimize: Color(red: 1.0, green: 0.741, blue: 0.180)
        case .zoom: Color(red: 0.153, green: 0.788, blue: 0.247)
        }
    }

    var pressedColor: Color {
        switch self {
        case .close: Color(red: 0.80, green: 0.263, blue: 0.237)
        case .minimize: Color(red: 0.80, green: 0.591, blue: 0.130)
        case .zoom: Color(red: 0.103, green: 0.638, blue: 0.197)
        }
    }

    var borderColor: Color {
        switch self {
        case .close: Color(red: 0.87, green: 0.28, blue: 0.24)
        case .minimize: Color(red: 0.87, green: 0.64, blue: 0.10)
        case .zoom: Color(red: 0.10, green: 0.68, blue: 0.17)
        }
    }
}

// MARK: - Button Style

private struct TrafficLightButtonStyle: ButtonStyle {
    let type: TrafficLightType
    let isHovering: Bool
    let isWindowActive: Bool

    private let diameter: CGFloat = 12

    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            Circle()
                .fill(fillColor(isPressed: configuration.isPressed))

            Circle()
                .strokeBorder(strokeColor(isPressed: configuration.isPressed), lineWidth: 0.5)

            if isHovering || configuration.isPressed {
                symbol
            }
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
    }

    private func fillColor(isPressed: Bool) -> Color {
        if !isWindowActive && !isHovering { return Color(white: 0.80) }
        if isPressed { return type.pressedColor }
        return type.activeColor
    }

    private func strokeColor(isPressed: Bool) -> Color {
        if !isWindowActive && !isHovering { return Color(white: 0.69) }
        if isPressed { return type.pressedColor.opacity(0.8) }
        return type.borderColor
    }

    @ViewBuilder
    private var symbol: some View {
        let symbolColor = Color(white: 0, opacity: 0.5)

        switch type {
        case .close:
            Image(systemName: "xmark")
                .font(.system(size: 7.5, weight: .bold, design: .rounded))
                .foregroundStyle(symbolColor)

        case .minimize:
            Image(systemName: "minus")
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .foregroundStyle(symbolColor)

        case .zoom:
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 7, weight: .bold, design: .rounded))
                .foregroundStyle(symbolColor)
        }
    }
}
