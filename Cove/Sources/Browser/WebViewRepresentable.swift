import SwiftUI
import WebKit

/// Shows a tab's web view. The web view sits in a container of its own, so it
/// can move to another place on screen (out of a Peek into the page, between
/// split panes, from Little Cove into a browser window) without a reload:
/// SwiftUI only ever adds and removes containers. A container takes the web
/// view once, when it's made or handed a different one, so a container still
/// on screen in a closing transition never takes it back.
struct WebViewRepresentable: NSViewRepresentable {
    let webView: WKWebView
    /// Called once the page is on screen, with its window.
    let onAppear: (NSWindow?) -> Void

    final class Coordinator {
        weak var webView: WKWebView?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    /// A page that comes on screen (replacing the start page, or on switching
    /// tabs) takes keyboard focus, as in Safari. Otherwise AppKit hands it to the
    /// next key view, the address field, which then shows the URL selected.
    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        hold(in: container, context: context)
        DispatchQueue.main.async { [webView, onAppear] in
            webView.window?.makeFirstResponder(webView)
            onAppear(webView.window)
        }
        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        hold(in: container, context: context)
    }

    private func hold(in container: NSView, context: Context) {
        guard context.coordinator.webView !== webView else { return }
        context.coordinator.webView = webView
        container.subviews.forEach { $0.removeFromSuperview() }
        webView.frame = container.bounds
        webView.autoresizingMask = [.width, .height]
        container.addSubview(webView)
    }
}
