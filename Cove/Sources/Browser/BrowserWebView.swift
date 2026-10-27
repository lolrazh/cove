import AppKit
import WebKit

/// The page's web view. WebKit takes ⌃ shortcuts like ⌃Tab for the page,
/// which never gets to keep them in Safari either, so the menu bar has them
/// first: the Tab menu can switch tabs (⌃Tab, ⌃⇧Tab) and the Spaces menu
/// spaces (⌃1–9) while the page has focus. Other ⌃ keys still reach the page,
/// after extensions' shortcuts.
final class BrowserWebView: WKWebView {
    /// A click in the page, which focuses its pane in a split. SwiftUI's
    /// gestures never see clicks inside a web view.
    var onMouseDown: (() -> Void)?
    /// The extension whose pages this web view shows, made from its
    /// configuration; nil for the web. WebKit loads each only in its own.
    weak var extensionPage: WKWebExtensionContext?

    override func mouseDown(with event: NSEvent) {
        onMouseDown?()
        super.mouseDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.control),
           NSApp.mainMenu?.performKeyEquivalent(with: event) == true {
            return true
        }
        // Extensions' keyboard shortcuts, from their manifests' `commands`.
        if configuration.webExtensionController?.extensionContexts.contains(where: { $0.performCommand(for: event) }) == true {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
