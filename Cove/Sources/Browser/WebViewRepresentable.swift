import SwiftUI
import WebKit

struct WebViewRepresentable: NSViewRepresentable {
    let webView: WKWebView
    /// Called once the page is on screen, with its window.
    let onAppear: (NSWindow?) -> Void

    /// A page that comes on screen (replacing the start page, or on switching
    /// tabs) takes keyboard focus, as in Safari. Otherwise AppKit hands it to the
    /// next key view, the address field, which then shows the URL selected.
    func makeNSView(context: Context) -> WKWebView {
        DispatchQueue.main.async { [webView, onAppear] in
            webView.window?.makeFirstResponder(webView)
            onAppear(webView.window)
        }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
    }
}
