import SwiftUI
import AppKit

enum ChromeMetrics {
    static let windowCornerRadius: CGFloat = 14
    static let shellGutter: CGFloat = 6
    static let windowInset: CGFloat = shellGutter
    static let windowBorderWidth: CGFloat = 0.75
    static let surfaceBorderWidth: CGFloat = 1
    static let topChromeSpacing: CGFloat = 6
    static let topChromePadding: CGFloat = 8
    static var panelCornerRadius: CGFloat { nestedCornerRadius(inside: windowCornerRadius, inset: windowInset) }
    static var controlCornerRadius: CGFloat { nestedCornerRadius(inside: panelCornerRadius, inset: 2) }
    static var fieldCornerRadius: CGFloat { nestedCornerRadius(inside: panelCornerRadius, inset: 1.5) }
    static var tabCornerRadius: CGFloat { nestedCornerRadius(inside: panelCornerRadius, inset: 2) }
    static let shellStripHeight: CGFloat = 36
    static let shellStripBottomSpacing: CGFloat = shellGutter
    static let shellControlsInterButtonSpacing: CGFloat = 6
    static let shellControlsInsetWithinShell: CGFloat = 4
    static let shellControlsButtonSize: CGFloat = 14
    static let shellControlsGapToTabs: CGFloat = 4
    static let shellControlsLeadingInset: CGFloat = shellGutter + shellControlsInsetWithinShell
    static var shellControlsClusterWidth: CGFloat {
        (shellControlsButtonSize * 3) + (shellControlsInterButtonSpacing * 2)
    }
    static var shellControlsReservedWidth: CGFloat {
        shellControlsClusterWidth + shellControlsInsetWithinShell + shellControlsGapToTabs
    }
    static let shellControlsVerticalOffset: CGFloat = 0
    static let mainPanelInnerPadding: CGFloat = 8
    static let topNavigationHorizontalPadding: CGFloat = 10
    static let topNavigationVerticalPadding: CGFloat = 6
    static let mainPanelSectionSpacing: CGFloat = 0
    static let mainPanelSeparatorHeight: CGFloat = 1
    static let topBarMinHeight: CGFloat = 44
    static let topStripLaneHeight: CGFloat = 32
    static let topStripLaneCenterFromTop: CGFloat = shellGutter + (topStripLaneHeight / 2)
    static let tabStripHeight: CGFloat = topStripLaneHeight
    static let topBandHeight: CGFloat = topStripLaneHeight + (shellGutter * 2)
    static let iconButtonSize = CGSize(width: 30, height: 30)
    static let sidebarWidth: CGFloat = 240
    static let sidebarRevealHandleWidth: CGFloat = 12

    private static func nestedCornerRadius(
        inside outerRadius: CGFloat,
        inset: CGFloat,
        minimum: CGFloat = 8
    ) -> CGFloat {
        max(outerRadius - (inset * 0.65), minimum)
    }
}

enum ChromePalette {
    static let window = Color(nsColor: .windowBackgroundColor)
    static let shellFill = Color(nsColor: NSColor(calibratedWhite: 0.12, alpha: 1))
    static let topStripDivider = Color.white.opacity(0.08)
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
