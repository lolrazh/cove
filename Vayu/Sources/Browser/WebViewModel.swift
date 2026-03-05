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

    init(initialURL: String? = nil) {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.preferences.isElementFullscreenEnabled = true

        webView = WKWebView(frame: .zero, configuration: config)
        super.init()

        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = self

        setupObservers()
        if let initialURL {
            loadURL(initialURL)
        }
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
        guard let pageURL = URL(string: currentURL),
              let host = pageURL.host else { return }

        let domain = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host

        // Check cache first — instant display
        if let cached = FaviconStore.shared.get(domain: domain) {
            self.favicon = cached
            return
        }

        // Extract favicon URLs from page, then fetch with priority chain
        let js = """
        (function() {
            var icons = [];
            var links = document.querySelectorAll('link[rel~="icon"], link[rel="shortcut icon"]');
            for (var i = 0; i < links.length; i++) {
                var link = links[i];
                var size = 0;
                var sizes = link.getAttribute('sizes');
                if (sizes && sizes !== 'any') size = parseInt(sizes.split('x')[0]) || 0;
                var type = link.getAttribute('type') || '';
                var isSvg = type.indexOf('svg') !== -1 || link.href.endsWith('.svg');
                icons.push({ href: link.href, size: size, svg: isSvg });
            }
            // Sort: SVG first, then by size descending
            icons.sort(function(a, b) {
                if (a.svg !== b.svg) return a.svg ? -1 : 1;
                return b.size - a.size;
            });
            return icons.map(function(i) { return i.href; });
        })();
        """
        webView.evaluateJavaScript(js) { [weak self] result, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let candidates = (result as? [String])?.compactMap { URL(string: $0) } ?? []
                self.resolveFavicon(candidates: candidates, domain: domain, pageURL: pageURL)
            }
        }
    }

    private func resolveFavicon(candidates: [URL], domain: String, pageURL: URL) {
        Task.detached {
            // Try page-declared icons first (SVG and large PNGs, no apple-touch-icon)
            for candidate in candidates {
                if let data = await Self.fetchImageData(from: candidate),
                   let image = Self.renderFavicon(from: data) {
                    await MainActor.run { [weak self] in
                        self?.favicon = image
                        FaviconStore.shared.store(domain: domain, imageData: data)
                    }
                    return
                }
            }

            // Fallback: Google Favicon API (returns the clean logomark, not apple-touch-icon)
            let googleURL = URL(string: "https://t1.gstatic.com/faviconV2?client=SOCIAL&type=FAVICON&fallback_opts=TYPE,SIZE,URL&url=https://\(domain)&size=64")!
            if let data = await Self.fetchImageData(from: googleURL),
               let image = Self.renderFavicon(from: data) {
                await MainActor.run { [weak self] in
                    self?.favicon = image
                    FaviconStore.shared.store(domain: domain, imageData: data)
                }
                return
            }

            // Last resort: /favicon.ico
            if let scheme = pageURL.scheme,
               let fallback = URL(string: "\(scheme)://\(domain)/favicon.ico"),
               let data = await Self.fetchImageData(from: fallback),
               let image = Self.renderFavicon(from: data) {
                await MainActor.run { [weak self] in
                    self?.favicon = image
                    FaviconStore.shared.store(domain: domain, imageData: data)
                }
            }
        }
    }

    nonisolated private static func fetchImageData(from url: URL) async -> Data? {
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              !data.isEmpty else { return nil }
        return data
    }

    nonisolated private static func renderFavicon(from data: Data) -> NSImage? {
        guard let image = NSImage(data: data), image.isValid else { return nil }
        let targetSize = NSSize(width: 32, height: 32)
        let rendered = NSImage(size: targetSize, flipped: false) { rect in
            NSGraphicsContext.current?.imageInterpolation = .high
            image.draw(in: rect,
                       from: NSRect(origin: .zero, size: image.size),
                       operation: .copy,
                       fraction: 1.0)
            return true
        }
        rendered.isTemplate = false
        return rendered
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
