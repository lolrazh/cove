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

    private(set) var webView: WKWebView

    private let settings: BrowserSettingsStore
    private let services: TabSessionServices
    private let requestBuilder: NavigationRequestBuilder
    private let onOpenInNewTab: (@MainActor (URLRequest) -> Void)?
    private let faviconFetcher: FaviconFetcher
    private var observers: [NSKeyValueObservation] = []
    private var webViewCanGoBack = false
    private var webViewCanGoForward = false
    private var hasSyntheticStartPageEntry: Bool
    private var syntheticForwardToWebContent = false

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
        self.hasSyntheticStartPageEntry = showsStartPage
        self.settings = settings
        self.services = services
        self.requestBuilder = requestBuilder
        self.onOpenInNewTab = onOpenInNewTab
        self.faviconFetcher = FaviconFetcher(store: services.faviconStore)
        self.webView = services.webKitEnvironment.makeWebView()
        super.init()

        configureWebView(webView)
        setupObservers()
        refreshNavigationState()
        if let initialRequest {
            loadRequest(initialRequest)
        } else if let initialURL {
            loadURL(initialURL)
        }
    }

    func navigate(_ input: String) {
        guard let request = request(for: input) else { return }

        if isNewTabPage && syntheticForwardToWebContent {
            replaceWebViewForFreshNavigation()
            syntheticForwardToWebContent = false
        }

        if isNewTabPage {
            hasSyntheticStartPageEntry = true
        }

        isNewTabPage = false
        loadRequest(request)
        refreshNavigationState()
    }

    func loadURL(_ input: String) {
        guard let request = request(for: input) else { return }
        loadRequest(request)
    }

    func loadRequest(_ request: URLRequest) {
        webView.load(request)
    }

    func goBack() {
        guard !isNewTabPage else { return }

        if webViewCanGoBack {
            webView.goBack()
        } else if hasSyntheticStartPageEntry {
            showSyntheticStartPage()
        }
    }

    func goForward() {
        if isNewTabPage {
            guard syntheticForwardToWebContent else { return }
            revealWebViewFromSyntheticStartPage()
            return
        }

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

    // MARK: - Observers

    private func setupObservers() {
        observers = [
            webView.observe(\.url) { [weak self] webView, _ in
                Task { @MainActor in self?.handleURLChange(webView.url) }
            },
            webView.observe(\.title) { [weak self] webView, _ in
                Task { @MainActor in self?.handleTitleChange(webView.title) }
            },
            webView.observe(\.canGoBack) { [weak self] webView, _ in
                Task { @MainActor in
                    self?.webViewCanGoBack = webView.canGoBack
                    self?.refreshNavigationState()
                }
            },
            webView.observe(\.canGoForward) { [weak self] webView, _ in
                Task { @MainActor in
                    self?.webViewCanGoForward = webView.canGoForward
                    self?.refreshNavigationState()
                }
            },
            webView.observe(\.isLoading) { [weak self] webView, _ in
                Task { @MainActor in self?.handleLoadingChange(webView.isLoading) }
            },
            webView.observe(\.estimatedProgress) { [weak self] webView, _ in
                Task { @MainActor in self?.handleEstimatedProgressChange(webView.estimatedProgress) }
            },
        ]
    }

    private func handleURLChange(_ url: URL?) {
        guard !isShowingSyntheticStartPage else { return }
        currentURL = url?.absoluteString ?? ""
        updateFavicon(for: url)
    }

    private func handleTitleChange(_ title: String?) {
        guard !isShowingSyntheticStartPage else { return }
        pageTitle = title ?? ""
    }

    private func handleLoadingChange(_ isLoading: Bool) {
        guard !isShowingSyntheticStartPage else { return }
        self.isLoading = isLoading
    }

    private func handleEstimatedProgressChange(_ progress: Double) {
        guard !isShowingSyntheticStartPage else { return }
        estimatedProgress = progress
    }

    // MARK: - Navigation helpers

    private func request(for input: String) -> URLRequest? {
        requestBuilder.request(for: input, searchEngine: settings.searchEngine)
    }

    private func configureWebView(_ webView: WKWebView) {
        webView.navigationDelegate = self
        webView.uiDelegate = self
    }

    private func replaceWebViewForFreshNavigation() {
        observers.removeAll()
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil

        let replacement = services.webKitEnvironment.makeWebView()
        webView = replacement
        configureWebView(replacement)

        webViewCanGoBack = false
        webViewCanGoForward = false
        currentURL = ""
        pageTitle = ""
        isLoading = false
        estimatedProgress = 0
        faviconFetcher.reset()
        favicon = nil
        setupObservers()
    }

    private func showSyntheticStartPage() {
        isNewTabPage = true
        syntheticForwardToWebContent = true
        currentURL = ""
        pageTitle = ""
        isLoading = false
        estimatedProgress = 0
        faviconFetcher.reset()
        favicon = nil
        refreshNavigationState()
    }

    private func revealWebViewFromSyntheticStartPage() {
        isNewTabPage = false
        syntheticForwardToWebContent = false
        currentURL = webView.url?.absoluteString ?? ""
        pageTitle = webView.title ?? ""
        isLoading = webView.isLoading
        estimatedProgress = webView.estimatedProgress
        refreshNavigationState()
        updateFavicon(for: webView.url)
    }

    private func refreshNavigationState() {
        if isNewTabPage {
            canGoBack = false
            canGoForward = syntheticForwardToWebContent
            return
        }

        canGoBack = webViewCanGoBack || hasSyntheticStartPageEntry
        canGoForward = webViewCanGoForward
    }

    private var isShowingSyntheticStartPage: Bool {
        isNewTabPage && syntheticForwardToWebContent
    }

    // MARK: - Favicon

    private func updateFavicon(for pageURL: URL?, force: Bool = false) {
        faviconFetcher.update(for: pageURL, force: force) { [weak self] image in
            self?.favicon = image
        }
    }
}

// MARK: - WKNavigationDelegate

extension TabSession: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let url = webView.url?.absoluteString ?? ""
        let title = webView.title ?? ""
        services.historyStore.recordVisit(url: url, title: title)
        faviconFetcher.upgradeFromPage(webView, currentImage: favicon) { [weak self] image in
            self?.favicon = image
        }
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
        if !navigationResponse.canShowMIMEType { return .download }
        return .allow
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        services.downloadManager.handleDownload(download)
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        services.downloadManager.handleDownload(download)
    }
}

// MARK: - WKUIDelegate

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
