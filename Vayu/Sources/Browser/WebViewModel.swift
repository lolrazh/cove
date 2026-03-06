import SwiftUI
import WebKit
import AppKit

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
    private var faviconTask: Task<Void, Never>?
    private var faviconSiteKey: String?
    private var faviconRequestID: UUID?
    private static let browserUserAgent = makeBrowserUserAgent()

    init(initialURL: String? = nil) {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.preferences.isElementFullscreenEnabled = true

        webView = WKWebView(frame: .zero, configuration: config)
        super.init()

        applyBrowserUserAgent()
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
                    self?.handleURLChange(webView.url)
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

    deinit {
        faviconTask?.cancel()
    }

    private func handleURLChange(_ url: URL?) {
        currentURL = url?.absoluteString ?? ""
        updateFavicon(for: url)
    }

    func loadURL(_ input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        applyBrowserUserAgent()

        let url: URL?
        if looksLikeURL(trimmed) {
            if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
                url = URL(string: trimmed)
            } else {
                url = URL(string: "https://\(trimmed)")
            }
        } else {
            let query = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
            url = URL(string: "https://www.google.com/search?q=\(query)")
        }

        if let url {
            webView.load(URLRequest(url: url))
        }
    }

    private func updateFavicon(for pageURL: URL?, force: Bool = false) {
        guard let pageURL,
              let siteKey = faviconSiteKey(for: pageURL),
              let faviconURL = canonicalFaviconURL(for: pageURL) else {
            resetFavicon()
            return
        }

        let siteChanged = faviconSiteKey != siteKey
        if !siteChanged && !force && (favicon != nil || faviconTask != nil) {
            return
        }

        faviconSiteKey = siteKey
        faviconTask?.cancel()
        faviconTask = nil

        if siteChanged || force {
            favicon = nil
        }

        if let cached = FaviconStore.shared.get(domain: siteKey) {
            faviconRequestID = nil
            favicon = cached
            return
        }

        let requestID = UUID()
        faviconRequestID = requestID
        faviconTask = Task(priority: .utility) { [weak self] in
            guard let data = await Self.fetchFaviconData(from: faviconURL),
                  !Task.isCancelled,
                  let image = Self.renderFavicon(from: data) else {
                await MainActor.run { [weak self] in
                    self?.completeFaviconRequest(ifMatches: requestID)
                }
                return
            }

            await MainActor.run { [weak self] in
                guard let self,
                      self.faviconRequestID == requestID,
                      self.faviconSiteKey == siteKey else { return }
                self.favicon = image
                FaviconStore.shared.store(domain: siteKey, imageData: data)
                self.completeFaviconRequest(ifMatches: requestID)
            }
        }
    }

    private func resetFavicon() {
        faviconTask?.cancel()
        faviconTask = nil
        faviconSiteKey = nil
        faviconRequestID = nil
        favicon = nil
    }

    private func completeFaviconRequest(ifMatches requestID: UUID) {
        guard faviconRequestID == requestID else { return }
        faviconTask = nil
        faviconRequestID = nil
    }

    private func faviconSiteKey(for pageURL: URL) -> String? {
        guard let host = pageURL.host?.lowercased() else { return nil }

        if let port = pageURL.port {
            return "\(host):\(port)"
        }

        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    private func canonicalFaviconURL(for pageURL: URL) -> URL? {
        guard let scheme = pageURL.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = pageURL.host else { return nil }

        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.port = pageURL.port
        components.path = "/favicon.ico"
        return components.url
    }

    func goBack() { webView.goBack() }
    func goForward() { webView.goForward() }

    func reload() {
        if webView.url != nil {
            applyBrowserUserAgent()
            updateFavicon(for: webView.url, force: true)
            webView.reload()
        }
    }

    func stopLoading() { webView.stopLoading() }

    nonisolated private static func fetchFaviconData(from url: URL) async -> Data? {
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 4)

        guard let (data, response) = try? await URLSession.shared.data(for: request),
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

    nonisolated private static func makeBrowserUserAgent() -> String {
        let safariVersion = installedSafariVersion() ?? "18.0"
        return "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/\(safariVersion) Safari/605.1.15"
    }

    nonisolated private static func installedSafariVersion() -> String? {
        guard let safariURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari"),
              let safariBundle = Bundle(url: safariURL),
              let safariVersion = safariBundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              !safariVersion.isEmpty else {
            return nil
        }

        return safariVersion
    }

    private func applyBrowserUserAgent() {
        if webView.customUserAgent != Self.browserUserAgent {
            webView.customUserAgent = Self.browserUserAgent
        }
    }

    private func looksLikeURL(_ input: String) -> Bool {
        if input.hasPrefix("http://") || input.hasPrefix("https://") { return true }
        if input.contains(" ") { return false }

        // Strip path/query/fragment for host detection
        let host = input.split(separator: "/").first.map(String.init) ?? input
        let hostWithoutPort = host.split(separator: ":").first.map(String.init) ?? host

        // localhost (with optional port/path)
        if hostWithoutPort == "localhost" { return true }

        // IPv4: 192.168.1.1, 127.0.0.1, etc.
        let parts = hostWithoutPort.split(separator: ".")
        if parts.count == 4 && parts.allSatisfy({ $0.allSatisfy(\.isNumber) }) { return true }

        // IPv6: [::1], [fe80::1], etc.
        if input.hasPrefix("[") { return true }

        // Domain with TLD: example.com, sub.example.co.uk
        if parts.count >= 2, let tld = parts.last, tld.count >= 2, tld.allSatisfy(\.isLetter) {
            return true
        }

        return false
    }
}

extension WebViewModel: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let url = webView.url?.absoluteString ?? ""
        let title = webView.title ?? ""
        HistoryStore.shared.recordVisit(url: url, title: title)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction
    ) async -> WKNavigationActionPolicy {
        if navigationAction.targetFrame?.isMainFrame != false {
            updateFavicon(for: navigationAction.request.url)
        }

        return .allow
    }

    // If the response can't be displayed (e.g. zip, dmg, pdf download), convert to download
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse
    ) async -> WKNavigationResponsePolicy {
        if !navigationResponse.canShowMIMEType {
            return .download
        }
        return .allow
    }

    // Hand off downloads to DownloadManager
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        DownloadManager.shared.handleDownload(download)
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        DownloadManager.shared.handleDownload(download)
    }
}
