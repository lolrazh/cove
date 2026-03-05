import SwiftUI
import WebKit
import Combine

@MainActor
final class WebViewModel: NSObject, ObservableObject {
    @Published var currentURL: String = ""
    @Published var pageTitle: String = ""
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var isLoading: Bool = false
    @Published var estimatedProgress: Double = 0

    let webView: WKWebView
    private var observers: [NSKeyValueObservation] = []

    init(initialURL: String = "https://www.google.com") {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.preferences.isElementFullscreenEnabled = true

        webView = WKWebView(frame: .zero, configuration: config)
        super.init()

        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = self

        setupObservers()
        loadURL(initialURL)
    }

    private func setupObservers() {
        observers = [
            webView.observe(\.url) { [weak self] webView, _ in
                Task { @MainActor in
                    self?.currentURL = webView.url?.absoluteString ?? ""
                }
            },
            webView.observe(\.title) { [weak self] webView, _ in
                Task { @MainActor in
                    self?.pageTitle = webView.title ?? ""
                }
            },
            webView.observe(\.canGoBack) { [weak self] webView, _ in
                Task { @MainActor in
                    self?.canGoBack = webView.canGoBack
                }
            },
            webView.observe(\.canGoForward) { [weak self] webView, _ in
                Task { @MainActor in
                    self?.canGoForward = webView.canGoForward
                }
            },
            webView.observe(\.isLoading) { [weak self] webView, _ in
                Task { @MainActor in
                    self?.isLoading = webView.isLoading
                }
            },
            webView.observe(\.estimatedProgress) { [weak self] webView, _ in
                Task { @MainActor in
                    self?.estimatedProgress = webView.estimatedProgress
                }
            },
        ]
    }

    func loadURL(_ input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let url: URL?
        if looksLikeURL(trimmed) {
            if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
                url = URL(string: trimmed)
            } else {
                url = URL(string: "https://\(trimmed)")
            }
        } else {
            // Google search
            let query = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
            url = URL(string: "https://www.google.com/search?q=\(query)")
        }

        if let url {
            webView.load(URLRequest(url: url))
        }
    }

    func goBack() { webView.goBack() }
    func goForward() { webView.goForward() }

    func reload() {
        if webView.url != nil {
            webView.reload()
        }
    }

    func stopLoading() { webView.stopLoading() }

    private func looksLikeURL(_ input: String) -> Bool {
        if input.hasPrefix("http://") || input.hasPrefix("https://") { return true }
        if input.contains(" ") { return false }
        // Has a dot followed by at least 2 chars (like .com, .org, .io)
        let domainPattern = #"^[a-zA-Z0-9\-]+\.[a-zA-Z]{2,}"#
        return input.range(of: domainPattern, options: .regularExpression) != nil
    }
}

extension WebViewModel: WKNavigationDelegate {
    nonisolated func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    }

    nonisolated func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction
    ) async -> WKNavigationActionPolicy {
        .allow
    }
}
