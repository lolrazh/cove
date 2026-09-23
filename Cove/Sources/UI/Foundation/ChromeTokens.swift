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
    static let sidebarInset: CGFloat = gutter
    static let sidebarRowHeight: CGFloat = 32
    /// Width of the invisible edge that reveals hidden tabs.
    static let revealEdge: CGFloat = 8

    static let navigationBarHeight: CGFloat = 44
    static let iconButtonSize: CGFloat = 28
}

/// Colors come from the system, so light and dark mode, increased contrast and
/// the accent color all work without any code of ours.
enum ChromePalette {
    /// The frame behind the tabs and the content card: the system's color for
    /// the area behind a page. On macOS 27 the plain window color matches the
    /// page color exactly, which would make the card vanish.
    static let shell = Color(nsColor: .underPageBackgroundColor)
    /// The content card, and anything standing in for a web page.
    static let content = Color(nsColor: .textBackgroundColor)

    /// Interaction fills, from the system fill hierarchy. The same everywhere, so
    /// a hovered tab, button and tile all look alike.
    static var resting: some ShapeStyle { .fill.quaternary }
    static var hover: some ShapeStyle { .fill.secondary }
    static var pressed: some ShapeStyle { .fill }
}

enum ChromeMotion {
    static let hover = Animation.easeOut(duration: 0.12)
    static let press = Animation.easeOut(duration: 0.08)
    static let shell = Animation.smooth(duration: 0.26)
}

/// Minimum corner radii, one per component size. Actual radii come from
/// `ConcentricRectangle`: near the window's corners a shape follows them, and
/// further in it falls back to its minimum.
///
/// Text and icon sizes need no tokens of our own: views use the system text
/// styles (`.body` 13pt, `.callout` 12pt, `.subheadline` 11pt, `.caption` 10pt
/// on macOS), and SF Symbols size themselves from the surrounding text style.
enum ChromeRadius {
    /// Small accessories inside a row, like a tab's close button.
    static let accessory: CGFloat = 5
    /// Icon buttons and text fields.
    static let control: CGFloat = 8
    /// Tabs and sidebar rows.
    static let tab: CGFloat = 10
    /// Large surfaces inside the page, like new tab tiles.
    static let tile: CGFloat = 14
}

extension Shape where Self == ConcentricRectangle {
    /// The one corner shape in Cove: continuous corners, concentric with the
    /// enclosing container (ultimately the window), never tighter than `minimum`.
    static func chrome(minimum: CGFloat = ChromeRadius.control) -> ConcentricRectangle {
        ConcentricRectangle(corners: .concentric(minimum: .fixed(minimum)), isUniform: true)
    }
}
