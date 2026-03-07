import AppKit
import WebKit

@MainActor
final class WebKitEnvironment {
    static let shared = WebKitEnvironment()

    private let browserUserAgent: String

    private init() {
        self.browserUserAgent = Self.makeBrowserUserAgent()
    }

    func makeWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.isElementFullscreenEnabled = true
        ContentBlockerManager.shared.attach(to: configuration.userContentController)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        configure(webView)
        return webView
    }

    func applyBrowserUserAgent(to webView: WKWebView) {
        if webView.customUserAgent != browserUserAgent {
            webView.customUserAgent = browserUserAgent
        }
    }

    private func configure(_ webView: WKWebView) {
        applyBrowserUserAgent(to: webView)
        webView.allowsBackForwardNavigationGestures = true
    }

    private static func makeBrowserUserAgent() -> String {
        let safariVersion = installedSafariVersion() ?? "18.0"
        return "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/\(safariVersion) Safari/605.1.15"
    }

    private static func installedSafariVersion() -> String? {
        guard let safariURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari"),
              let safariBundle = Bundle(url: safariURL),
              let safariVersion = safariBundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              !safariVersion.isEmpty else {
            return nil
        }

        return safariVersion
    }
}
