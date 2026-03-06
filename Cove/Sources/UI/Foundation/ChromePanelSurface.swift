import SwiftUI
import AppKit

enum ChromeSurfaceTone {
    case browserShell
    case window
    case topChrome
    case panel
    case sidebar
    case card
}

struct ChromePanelSurface: ViewModifier {
    let tone: ChromeSurfaceTone
    var cornerRadius: CGFloat = ChromeMetrics.panelCornerRadius
    var showsShadow: Bool = false
    var borderWidth: CGFloat? = nil

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return content
            .background {
                backgroundView(shape: shape)
            }
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(borderColor, lineWidth: resolvedBorderWidth)
            }
            .shadow(
                color: showsShadow ? ChromePalette.shadow : .clear,
                radius: showsShadow ? 16 : 0,
                y: showsShadow ? 8 : 0
            )
    }

    @ViewBuilder
    private func backgroundView(shape: RoundedRectangle) -> some View {
        switch tone {
        case .browserShell:
            shape.fill(ChromePalette.shellFill)
        case .window:
            shape.fill(ChromePalette.window)
        case .topChrome:
            shape.fill(ChromePalette.chromeFill)
        case .panel:
            shape.fill(.regularMaterial)
        case .sidebar:
            VisualEffectMaterialBackground(material: .sidebar, blendingMode: .withinWindow)
                .clipShape(shape)
        case .card:
            shape.fill(ChromePalette.subtleCardFill)
        }
    }

    private var borderColor: Color {
        switch tone {
        case .browserShell:
            return ChromePalette.chromeStrokeStrong
        case .window:
            return ChromePalette.chromeStrokeStrong
        case .topChrome, .panel, .sidebar:
            return ChromePalette.chromeStroke
        case .card:
            return ChromePalette.fieldStroke
        }
    }

    private var resolvedBorderWidth: CGFloat {
        if let borderWidth {
            return borderWidth
        }

        switch tone {
        case .browserShell:
            return ChromeMetrics.windowBorderWidth
        case .window:
            return ChromeMetrics.windowBorderWidth
        case .topChrome, .panel, .sidebar, .card:
            return ChromeMetrics.surfaceBorderWidth
        }
    }
}

struct ChromeInteractiveSurface: ViewModifier {
    var isSelected: Bool = false
    var cornerRadius: CGFloat = ChromeMetrics.controlCornerRadius
    var showsBorder: Bool = false

    @State private var isHovered = false

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return content
            .background {
                shape.fill(backgroundColor)
            }
            .overlay {
                if showsBorder {
                    shape.strokeBorder(borderColor, lineWidth: ChromeMetrics.surfaceBorderWidth)
                }
            }
            .contentShape(shape)
            .animation(ChromeMotion.hover, value: isHovered)
            .onHover { isHovered = $0 }
    }

    private var backgroundColor: Color {
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
        if isHovered {
            return ChromePalette.chromeStroke
        }
        return ChromePalette.fieldStroke.opacity(0.8)
    }
}

struct VisualEffectMaterialBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = .active
    }
}

extension View {
    func chromePanelSurface(
        _ tone: ChromeSurfaceTone,
        cornerRadius: CGFloat = ChromeMetrics.panelCornerRadius,
        showsShadow: Bool = false,
        borderWidth: CGFloat? = nil
    ) -> some View {
        modifier(
            ChromePanelSurface(
                tone: tone,
                cornerRadius: cornerRadius,
                showsShadow: showsShadow,
                borderWidth: borderWidth
            )
        )
    }

    func chromeInteractiveSurface(
        isSelected: Bool = false,
        cornerRadius: CGFloat = ChromeMetrics.controlCornerRadius,
        showsBorder: Bool = false
    ) -> some View {
        modifier(ChromeInteractiveSurface(isSelected: isSelected, cornerRadius: cornerRadius, showsBorder: showsBorder))
    }

    func chromeWindowSurface() -> some View {
        chromePanelSurface(
            .window,
            cornerRadius: ChromeMetrics.windowCornerRadius,
            borderWidth: ChromeMetrics.windowBorderWidth
        )
    }
}
