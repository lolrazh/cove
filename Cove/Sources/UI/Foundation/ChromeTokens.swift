import SwiftUI
import AppKit

/// Layout for the browser frame. Everything hangs off two numbers macOS gives us:
/// the compact titlebar height and the traffic-light cluster, which is vertically
/// centered in it. Tabs share that centerline, so `gutter` is both the gap around
/// the content card and the gap above and below the tabs.
enum ChromeMetrics {
    /// Height of the `.unifiedCompact` titlebar. The traffic lights center on it.
    static let titlebarHeight: CGFloat = 40
    /// Gap between the window edge, the tab row and the content card.
    static let gutter: CGFloat = 6
    /// Tabs fill the titlebar minus a gutter above and below.
    static let tabHeight: CGFloat = titlebarHeight - gutter * 2
    /// Space between the zoom button and the first tab.
    static let trafficLightTrailingGap: CGFloat = 10

    static let sidebarWidth: CGFloat = 240
    static let sidebarInset: CGFloat = 10
    static let sidebarRowHeight: CGFloat = 32
    /// Width of the invisible edge that reveals hidden tabs.
    static let revealEdge: CGFloat = 8

    static let navigationBarHeight: CGFloat = 44
    static let iconButtonSize: CGFloat = 28
}

/// Surface colors come from the system, so light and dark mode, increased
/// contrast and the accent color all work without any code of ours. Hover,
/// pressed and selected states use the system fill hierarchy (`.fill.tertiary` …).
enum ChromePalette {
    /// The frame behind the tabs and the content card: the system's color for
    /// the area behind a page. On macOS 27 the plain window color matches the
    /// page color exactly, which would make the card vanish.
    static let shell = Color(nsColor: .underPageBackgroundColor)
    /// The content card, and anything standing in for a web page.
    static let content = Color(nsColor: .textBackgroundColor)
}

enum ChromeMotion {
    static let hover = Animation.easeOut(duration: 0.12)
    static let press = Animation.easeOut(duration: 0.08)
    static let shell = Animation.smooth(duration: 0.26)
}

extension Shape where Self == ConcentricRectangle {
    /// The one corner shape in Cove: continuous corners, concentric with the
    /// enclosing container (ultimately the window), never tighter than `minimum`.
    static func chrome(minimum: CGFloat = 8) -> ConcentricRectangle {
        ConcentricRectangle(corners: .concentric(minimum: .fixed(minimum)), isUniform: true)
    }
}
