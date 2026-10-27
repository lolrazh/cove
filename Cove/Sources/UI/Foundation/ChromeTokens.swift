import SwiftUI
import AppKit

/// Layout for the browser frame. Everything hangs off two numbers macOS gives us:
/// the compact titlebar height and the traffic-light cluster, which is vertically
/// centered in it. `gutter` is the gap between the window edge and the chrome in
/// the titlebar band; `cardInset` is the gap around the page card.
enum ChromeMetrics {
    /// Height of the `.unifiedCompact` titlebar. The traffic lights center on it.
    static let titlebarHeight: CGFloat = 40
    /// Gap between the window edge and the tab row, and around floating chrome.
    static let gutter: CGFloat = 6
    /// Gap between the window edge and the page card, like Arc's floating page.
    static let cardInset: CGFloat = 8
    /// Tabs sit closer to the page than to the window edge, so they read as
    /// belonging to it. This leaves them a point below the traffic lights'
    /// centerline, which looks centered next to the lights' larger glyph.
    static let tabBottomInset: CGFloat = 4
    /// Tabs, and buttons beside them, fill the titlebar between those insets.
    static let tabHeight: CGFloat = titlebarHeight - gutter - tabBottomInset
    /// Inset of a tab's close button from the tab's edges. The button fills the
    /// tab's height less this on each side.
    static let tabAccessoryInset: CGFloat = 4
    /// Header height for the floating sidebar, which starts a gutter below the
    /// window's top: it keeps the header on the traffic lights' centerline.
    static let floatingSidebarHeaderHeight: CGFloat = titlebarHeight - gutter * 2
    /// Space between the zoom button and the first tab.
    static let trafficLightTrailingGap: CGFloat = 10

    /// The sidebar is resized by dragging its trailing edge; the lower bound
    /// keeps the header's four controls clear of the traffic lights.
    static let sidebarWidthRange: ClosedRange<CGFloat> = 220...400
    static let sidebarDefaultWidth: CGFloat = 240
    /// Horizontal inset of the sidebar's rows: the same gap to the page card as
    /// the card keeps from the window.
    static let sidebarInset: CGFloat = cardInset
    static let sidebarRowHeight: CGFloat = 32
    /// Space between the sidebar's sections, and above and below the Clear line.
    static let sidebarSectionSpacing: CGFloat = 8
    static let sidebarFooterHeight: CGFloat = 36
    /// Width of the invisible edge that reveals hidden tabs.
    static let revealEdge: CGFloat = 8

    static let navigationBarHeight: CGFloat = 44
    static let iconButtonSize: CGFloat = 28
    /// The loading bar along the top edge of the page.
    static let progressHeight: CGFloat = 2
}

/// Colors come from the system, so light and dark mode, increased contrast and
/// the accent color all work without any code of ours.
enum ChromePalette {
    /// The frame behind the tabs and the content card: the system's color for
    /// the area behind a page, tinted by the window's `ChromeTheme`. On macOS 27
    /// the plain window color matches the page color exactly, which would make
    /// the card vanish.
    static var shell: some ShapeStyle { ChromeFrameStyle() }
    /// The content card, and anything standing in for a web page.
    static let content = Color(nsColor: .textBackgroundColor)
    /// The selected thing in the sidebar, lifted off the frame.
    static var raised: some ShapeStyle { ChromeRaisedStyle() }

    /// Interaction fills, from the system fill hierarchy. The same everywhere, so
    /// a hovered tab, button and tile all look alike.
    static var resting: some ShapeStyle { .fill.quaternary }
    static var hover: some ShapeStyle { .fill.secondary }
    static var pressed: some ShapeStyle { .fill }
}

enum ChromeMotion {
    static let hover = Animation.easeOut(duration: 0.12)
    static let press = Animation.easeOut(duration: 0.08)
    /// The frame rearranging itself: sidebar to top tabs, docked to hidden.
    static let shell = Animation.smooth(duration: 0.26)
    /// Hidden chrome sliding in from a window edge; the overshoot reads as
    /// arriving rather than extending.
    static let slide = Animation.spring(duration: 0.34, bounce: 0.18)
    /// A tab opening or closing, and its neighbors making room.
    static let tab = Animation.smooth(duration: 0.18)
    /// The Command Bar scaling and fading in. Quick: it answers a keystroke.
    static let commandBar = Animation.smooth(duration: 0.18)
    /// A toast appearing over the page.
    static let appear = Animation.spring(duration: 0.3, bounce: 0.2)
    static let fade = Animation.easeOut(duration: 0.25)
    static let progress = Animation.linear(duration: 0.2)
}

/// Elevation, in four steps. Shadows are the only thing that lifts a surface;
/// nothing in the chrome has an outline.
enum ChromeShadow {
    /// Just off the frame: the active sidebar tab.
    case raised
    /// The page card, floating over the frame like Arc's.
    case card
    /// Chrome over the page: the revealed sidebar, toasts, the link preview.
    case floating
    /// A panel over the whole window: the Command Bar.
    case panel

    var radius: CGFloat {
        switch self {
        case .raised: 1
        case .card: 12
        case .floating: 16
        case .panel: 28
        }
    }

    var y: CGFloat {
        switch self {
        case .raised: 1
        case .card: 3
        case .floating: 4
        case .panel: 10
        }
    }

    /// Dark frames swallow shadows, so they get about twice the ink.
    func opacity(in colorScheme: ColorScheme) -> Double {
        let light: Double = switch self {
        case .raised: 0.08
        case .card: 0.12
        case .floating: 0.18
        case .panel: 0.24
        }
        return colorScheme == .dark ? light * 2 : light
    }
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
    /// Tabs, sidebar rows, and buttons in the tab row. Everything in the
    /// titlebar sits a gutter in from the window's edge, so this is the
    /// window's own radius (about 16) less the gutter.
    static let tab: CGFloat = 10
    /// The outward curve where the active top tab meets the content card.
    static let flare: CGFloat = 8
    /// Large surfaces inside the page, like new tab tiles.
    static let tile: CGFloat = 14
}

extension Shape where Self == ConcentricRectangle {
    /// The one corner shape in Cove: continuous corners, concentric with the
    /// enclosing container (ultimately the window), never tighter than `minimum`.
    ///
    /// For drawing only. As a clip or content shape its hit area lands in the
    /// wrong place, so hit areas are plain rectangles (`.contentShape(Rectangle())`).
    static func chrome(minimum: CGFloat = ChromeRadius.control) -> ConcentricRectangle {
        ConcentricRectangle(corners: .concentric(minimum: .fixed(minimum)), isUniform: true)
    }
}
