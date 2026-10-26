import SwiftUI
import WebKit

struct WebViewRepresentable: NSViewRepresentable {
    let tab: TabSession

    /// A page that comes on screen (replacing the start page, or on switching
    /// tabs) takes keyboard focus, as in Safari. Otherwise AppKit hands it to the
    /// next key view, the address field, which then shows the URL selected.
    func makeNSView(context: Context) -> WKWebView {
        let webView = tab.webView
        DispatchQueue.main.async { [tab] in
            webView.window?.makeFirstResponder(webView)
            tab.pageDidAppear(in: webView.window)
        }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
    }
}
