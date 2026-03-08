import Foundation
import Combine
import AppKit
import WebKit

struct TabSessionServices {
    let historyStore: HistoryStore
    let faviconStore: FaviconStore
    let downloadManager: DownloadManager
    let webKitEnvironment: WebKitEnvironment
}

@MainActor
final class TabSession: NSObject, Identifiable, ObservableObject {
    let id: UUID

    @Published var isNewTabPage: Bool
    @Published var currentURL: String = ""
    @Published var pageTitle: String = ""
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var isLoading: Bool = false
    @Published var estimatedProgress: Double = 0
    @Published var favicon: NSImage?

    let webView: WKWebView

    private let settings: BrowserSettingsStore
    private let services: TabSessionServices
    private let requestBuilder: NavigationRequestBuilder
    private let onOpenInNewTab: (@MainActor (URLRequest) -> Void)?
    private var observers: [NSKeyValueObservation] = []
    private var faviconTask: Task<Void, Never>?
    private var faviconSiteKey: String?
    private var faviconRequestID: UUID?

    init(
        id: UUID = UUID(),
        initialURL: String? = nil,
        initialRequest: URLRequest? = nil,
        showsStartPage: Bool = true,
        settings: BrowserSettingsStore,
        services: TabSessionServices,
        requestBuilder: NavigationRequestBuilder = NavigationRequestBuilder(),
        onOpenInNewTab: (@MainActor (URLRequest) -> Void)? = nil
    ) {
        self.id = id
        self.isNewTabPage = showsStartPage
        self.settings = settings
        self.services = services
        self.requestBuilder = requestBuilder
        self.onOpenInNewTab = onOpenInNewTab
        self.webView = services.webKitEnvironment.makeWebView()
        super.init()

        webView.navigationDelegate = self
        webView.uiDelegate = self

        setupObservers()
        if let initialRequest {
            loadRequest(initialRequest)
        } else if let initialURL {
            loadURL(initialURL)
        }
    }

    deinit {
        faviconTask?.cancel()
    }

    func navigate(_ input: String) {
        guard let request = request(for: input) else { return }
        isNewTabPage = false
        loadRequest(request)
    }

    func loadURL(_ input: String) {
        guard let request = request(for: input) else { return }
        loadRequest(request)
    }

    func loadRequest(_ request: URLRequest) {
        webView.load(request)
    }

    func goBack() {
        webView.goBack()
    }

    func goForward() {
        webView.goForward()
    }

    func reload() {
        guard webView.url != nil else { return }
        updateFavicon(for: webView.url, force: true)
        webView.reload()
    }

    func stopLoading() {
        webView.stopLoading()
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

    private func handleURLChange(_ url: URL?) {
        currentURL = url?.absoluteString ?? ""
        updateFavicon(for: url)
    }

    private func request(for input: String) -> URLRequest? {
        requestBuilder.request(for: input, searchEngine: settings.searchEngine)
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

        if let cached = services.faviconStore.get(domain: siteKey) {
            faviconRequestID = nil
            favicon = cached
            return
        }

        let requestID = UUID()
        faviconRequestID = requestID
        faviconTask = Task(priority: .userInitiated) { [weak self] in
            guard let data = await Self.fetchFaviconData(from: faviconURL, timeoutInterval: 1.5),
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
                self.services.faviconStore.store(domain: siteKey, imageData: data)
                self.completeFaviconRequest(ifMatches: requestID)
            }
        }
    }

    private func updateFaviconFromPageIfNeeded() {
        guard favicon == nil,
              let pageURL = webView.url,
              let siteKey = faviconSiteKey(for: pageURL),
              faviconSiteKey == siteKey else { return }

        let fallbackURL = canonicalFaviconURL(for: pageURL)
        faviconTask?.cancel()
        faviconTask = nil

        let requestID = UUID()
        faviconRequestID = requestID
        faviconTask = Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            let candidates = await self.documentFaviconCandidates(for: pageURL, fallback: fallbackURL)
            guard let data = await Self.fetchFirstFaviconData(from: candidates, timeoutInterval: 1.5),
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
                self.services.faviconStore.store(domain: siteKey, imageData: data)
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

    private func documentFaviconCandidates(for pageURL: URL, fallback: URL?) async -> [URL] {
        let script = """
        (() => {
          return Array.from(document.querySelectorAll('link[rel][href]'))
            .map(link => {
              const rel = (link.getAttribute('rel') || '').toLowerCase();
              if (!rel.includes('icon')) return null;
              if (rel.includes('apple-touch-icon') || rel.includes('mask-icon')) return null;

              const href = link.href;
              return href && href.length > 0 ? href : null;
            })
            .filter(Boolean);
        })();
        """

        let hrefs: [String] = await withCheckedContinuation { continuation in
            webView.evaluateJavaScript(script) { value, _ in
                if let hrefs = value as? [String] {
                    continuation.resume(returning: hrefs)
                } else if let hrefs = value as? [NSString] {
                    continuation.resume(returning: hrefs.map(String.init))
                } else {
                    continuation.resume(returning: [])
                }
            }
        }

        let candidates = Self.faviconCandidateURLs(from: hrefs, relativeTo: pageURL)
        return Self.normalizedFaviconCandidates(candidates, fallback: fallback)
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

    nonisolated private static func fetchFaviconData(from url: URL, timeoutInterval: TimeInterval) async -> Data? {
        let request = URLRequest(
            url: url,
            cachePolicy: .returnCacheDataElseLoad,
            timeoutInterval: timeoutInterval
        )

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              !data.isEmpty else { return nil }
        return data
    }

    nonisolated private static func fetchFirstFaviconData(
        from urls: [URL],
        timeoutInterval: TimeInterval
    ) async -> Data? {
        let candidates = Array(urls.prefix(6))
        guard !candidates.isEmpty else { return nil }

        return await withTaskGroup(of: Data?.self, returning: Data?.self) { group in
            for url in candidates {
                group.addTask {
                    await Self.fetchFaviconData(from: url, timeoutInterval: timeoutInterval)
                }
            }

            while let data = await group.next() {
                if let data {
                    group.cancelAll()
                    return data
                }
            }

            return nil
        }
    }

    nonisolated private static func faviconCandidateURLs(from hrefs: [String], relativeTo pageURL: URL) -> [URL] {
        return hrefs.compactMap { href in
            guard let url = URL(string: href, relativeTo: pageURL)?.absoluteURL,
                  let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https" else {
                return nil
            }

            return url
        }
    }

    nonisolated private static func normalizedFaviconCandidates(_ urls: [URL], fallback: URL?) -> [URL] {
        var ordered: [URL] = []
        var seen: Set<String> = []

        for url in urls + [fallback].compactMap({ $0 }) {
            let key = url.absoluteString
            if seen.insert(key).inserted {
                ordered.append(url)
            }
        }

        return ordered
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
}

extension TabSession: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let url = webView.url?.absoluteString ?? ""
        let title = webView.title ?? ""
        services.historyStore.recordVisit(url: url, title: title)
        updateFaviconFromPageIfNeeded()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction
    ) async -> WKNavigationActionPolicy {
        if navigationAction.targetFrame?.isMainFrame == true {
            updateFavicon(for: navigationAction.request.url)
        }

        return .allow
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse
    ) async -> WKNavigationResponsePolicy {
        if !navigationResponse.canShowMIMEType {
            return .download
        }
        return .allow
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        services.downloadManager.handleDownload(download)
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        services.downloadManager.handleDownload(download)
    }
}

extension TabSession: WKUIDelegate {
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard navigationAction.targetFrame == nil,
              let url = navigationAction.request.url else {
            return nil
        }

        var request = navigationAction.request
        request.url = url
        onOpenInNewTab?(request)
        return nil
    }
}
