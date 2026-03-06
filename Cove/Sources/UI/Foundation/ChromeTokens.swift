import SwiftUI
import AppKit

enum ChromeMetrics {
    static let windowCornerRadius: CGFloat = 14
    static let windowInset: CGFloat = 10
    static let topChromeSpacing: CGFloat = 8
    static let topChromePadding: CGFloat = 10
    static let controlCornerRadius: CGFloat = 10
    static let fieldCornerRadius: CGFloat = 12
    static let panelCornerRadius: CGFloat = 16
    static let tabCornerRadius: CGFloat = 10
    static let topBarMinHeight: CGFloat = 44
    static let tabStripHeight: CGFloat = 38
    static let iconButtonSize = CGSize(width: 30, height: 30)
    static let sidebarWidth: CGFloat = 240
    static let sidebarRevealHandleWidth: CGFloat = 12
}

enum ChromePalette {
    static let window = Color(nsColor: .windowBackgroundColor)
    static let chromeFill = Color.primary.opacity(0.035)
    static let chromeStroke = Color.primary.opacity(0.08)
    static let chromeStrokeStrong = Color.primary.opacity(0.12)
    static let hoverFill = Color.primary.opacity(0.05)
    static let pressedFill = Color.primary.opacity(0.08)
    static let selectedFill = Color.primary.opacity(0.11)
    static let fieldFill = Color.primary.opacity(0.055)
    static let fieldStroke = Color.primary.opacity(0.08)
    static let fieldFocusStroke = Color.accentColor.opacity(0.45)
    static let subtleCardFill = Color.primary.opacity(0.025)
    static let tertiaryFill = Color.primary.opacity(0.018)
    static let handleFill = Color.primary.opacity(0.14)
    static let shadow = Color.black.opacity(0.12)
}

enum ChromeMotion {
    static let hover = Animation.easeOut(duration: 0.12)
    static let press = Animation.easeOut(duration: 0.08)
    static let shell = Animation.easeInOut(duration: 0.22)
    static let spring = Animation.snappy(duration: 0.18, extraBounce: 0.02)
    static let loading = Animation.linear(duration: 0.24)
}

enum ChromeOpacity {
    static let disabled: Double = 0.42
}
