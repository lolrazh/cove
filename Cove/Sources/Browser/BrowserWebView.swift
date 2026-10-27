import AppKit
import WebKit

/// The page's web view. WebKit takes ⌃ shortcuts like ⌃Tab for the page,
/// which never gets to keep them in Safari either, so the menu bar has them
/// first: the Tab menu can switch tabs (⌃Tab, ⌃⇧Tab) and the Spaces menu
/// spaces (⌃1–9) while the page has focus. Other ⌃ keys still reach the page.
final class BrowserWebView: WKWebView {
    /// A click in the page, which focuses its pane in a split. SwiftUI's
    /// gestures never see clicks inside a web view.
    var onMouseDown: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        onMouseDown?()
        super.mouseDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.control),
           NSApp.mainMenu?.performKeyEquivalent(with: event) == true {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
