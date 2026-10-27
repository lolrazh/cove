import AppKit
import WebKit

/// The page's web view. WebKit takes ⌃Tab and ⌃⇧Tab for the page, which never
/// gets to keep them in Safari either, so the menu bar has them first and the
/// Tab menu can switch tabs while the page has focus.
final class BrowserWebView: WKWebView {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.keyCode == 48, event.modifierFlags.contains(.control),
           NSApp.mainMenu?.performKeyEquivalent(with: event) == true {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
