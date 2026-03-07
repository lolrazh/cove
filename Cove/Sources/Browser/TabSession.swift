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
        initialURL: String? = nil,
        initialRequest: URLRequest? = nil,
        showsStartPage: Bool = true,
        settings: BrowserSettingsStore,
        services: TabSessionServices,
        requestBuilder: NavigationRequestBuilder = NavigationRequestBuilder(),
        onOpenInNewTab: (@MainActor (URLRequest) -> Void)? = nil
    ) {
        self.id = UUID()
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
        services.webKitEnvironment.applyBrowserUserAgent(to: webView)
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
        services.webKitEnvironment.applyBrowserUserAgent(to: webView)
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
}

extension TabSession: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let url = webView.url?.absoluteString ?? ""
        let title = webView.title ?? ""
        services.historyStore.recordVisit(url: url, title: title)
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
