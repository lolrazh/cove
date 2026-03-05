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
    @Published var favicon: NSImage?

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

    func fetchFavicon() {
        // Grab ALL icon links with their sizes, then pick the best one.
        // Priority: apple-touch-icon (always high-res) > largest sized icon > /favicon.ico
        let js = """
        (function() {
            var icons = [];
            var links = document.querySelectorAll('link[rel~="icon"], link[rel="shortcut icon"], link[rel="apple-touch-icon"], link[rel="apple-touch-icon-precomposed"]');
            for (var i = 0; i < links.length; i++) {
                var link = links[i];
                var size = 0;
                var sizes = link.getAttribute('sizes');
                if (sizes && sizes !== 'any') {
                    size = parseInt(sizes.split('x')[0]) || 0;
                }
                var isAppleTouch = link.rel.indexOf('apple-touch-icon') !== -1;
                if (isAppleTouch && size === 0) size = 180;
                icons.push({ href: link.href, size: size, apple: isAppleTouch });
            }
            if (icons.length === 0) return null;
            icons.sort(function(a, b) {
                if (a.apple !== b.apple) return a.apple ? -1 : 1;
                return b.size - a.size;
            });
            return icons[0].href;
        })();
        """
        webView.evaluateJavaScript(js) { [weak self] result, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let faviconURL: URL?
                if let href = result as? String {
                    faviconURL = URL(string: href)
                } else if let pageURL = URL(string: self.currentURL),
                          let scheme = pageURL.scheme, let host = pageURL.host {
                    faviconURL = URL(string: "\(scheme)://\(host)/apple-touch-icon.png")
                } else {
                    faviconURL = nil
                }

                guard let url = faviconURL else { return }
                self.downloadFavicon(from: url)
            }
        }
    }

    private func downloadFavicon(from url: URL) {
        Task.detached {
            // Try the given URL first
            var data: Data?
            if let (d, response) = try? await URLSession.shared.data(from: url),
               let http = response as? HTTPURLResponse, http.statusCode == 200 {
                data = d
            }

            // Fallback to /favicon.ico if apple-touch-icon failed
            if data == nil,
               let host = url.host, let scheme = url.scheme,
               !url.path.hasSuffix("favicon.ico"),
               let fallback = URL(string: "\(scheme)://\(host)/favicon.ico"),
               let (d, response) = try? await URLSession.shared.data(from: fallback),
               let http = response as? HTTPURLResponse, http.statusCode == 200 {
                data = d
            }

            guard let data, let image = NSImage(data: data), image.isValid else { return }

            // Render at 32x32 points (64x64 pixels on Retina) for crisp display
            let targetSize = NSSize(width: 32, height: 32)
            let resized = NSImage(size: targetSize, flipped: false) { rect in
                NSGraphicsContext.current?.imageInterpolation = .high
                image.draw(in: rect,
                           from: NSRect(origin: .zero, size: image.size),
                           operation: .copy,
                           fraction: 1.0)
                return true
            }
            resized.isTemplate = false

            await MainActor.run { [weak self] in
                self?.favicon = resized
            }
        }
    }

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
        Task { @MainActor in
            let url = self.currentURL
            let title = self.pageTitle
            HistoryStore.shared.recordVisit(url: url, title: title)
            self.fetchFavicon()
        }
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
