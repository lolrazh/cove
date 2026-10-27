import SwiftUI
import WebKit

/// Shows a tab's web view. The web view sits in a container of its own, so it
/// can move to another place on screen (out of a Peek into the page, between
/// split panes, from Little Cove into a browser window) without a reload:
/// SwiftUI only ever adds and removes the container, and whichever container
/// was made last holds the web view.
struct WebViewRepresentable: NSViewRepresentable {
    let webView: WKWebView
    /// Called once the page is on screen, with its window.
    let onAppear: (NSWindow?) -> Void

    /// A page that comes on screen (replacing the start page, or on switching
    /// tabs) takes keyboard focus, as in Safari. Otherwise AppKit hands it to the
    /// next key view, the address field, which then shows the URL selected.
    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        hold(in: container)
        DispatchQueue.main.async { [webView, onAppear] in
            webView.window?.makeFirstResponder(webView)
            onAppear(webView.window)
        }
        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        hold(in: container)
    }

    private func hold(in container: NSView) {
        guard webView.superview !== container else { return }
        container.subviews.forEach { $0.removeFromSuperview() }
        webView.frame = container.bounds
        webView.autoresizingMask = [.width, .height]
        container.addSubview(webView)
    }
}
