import Foundation
import Combine
import AppKit
import WebKit

/// A page that couldn't be loaded, shown as an error page in its place.
struct LoadFailure: Equatable {
    let url: URL?
    let message: String
}

struct TabSessionServices {
    let historyStore: HistoryStore
    let faviconStore: FaviconStore
    let downloadManager: DownloadManager
    let webKitEnvironment: WebKitEnvironment
    let contentBlocker: ContentBlockerManager
    let context: BrowsingContext
    let siteZoom: SiteZoomStore
}

@MainActor
final class TabSession: NSObject, Identifiable, ObservableObject {
    /// Whether the tab holds a live page. A background tab sleeps after a
    /// while: its web view is released and the sidebar keeps showing it from
    /// its title, favicon and URL. The selected tab is always awake.
    enum Page {
        case awake(WKWebView)
        /// WebKit's copy of the back/forward list, to wake from. Nil for a page
        /// that never loaded, which wakes by loading its URL afresh.
        case asleep(interactionState: Data?)
    }

    let id: UUID

    @Published private(set) var page: Page
    @Published var isNewTabPage: Bool
    @Published var currentURL: String = ""
    @Published var pageTitle: String = ""
    /// A name the user gave the tab, shown instead of the page's title.
    @Published private(set) var customTitle: String?
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var isLoading: Bool = false
    @Published var estimatedProgress: Double = 0
    @Published var favicon: NSImage?
    @Published private(set) var loadFailure: LoadFailure?
    /// The link under the pointer, for the preview in the page's corner.
    @Published private(set) var hoveredLink: URL?
    /// Whether the page is playing sound, muted or not.
    @Published private(set) var isPlayingAudio = false
    @Published private(set) var isMuted = false
    /// The media the page last played with sound, for the sidebar's player.
    /// A sleeping page has none.
    @Published private(set) var nowPlaying: NowPlaying?
    /// When the tab was last selected or last left; what idle time counts from.
    private(set) var lastUsedAt: Date

    /// The find bar's state. Follows the web view when it's replaced, and
    /// wakes the page if it has to.
    private(set) lazy var findInPage = FindInPage { [unowned self] in wake() }

    private let settings: BrowserSettingsStore
    let services: TabSessionServices
    private let requestBuilder: NavigationRequestBuilder
    private let onOpenInNewTab: (@MainActor (URLRequest) -> Void)?
    private let onSelect: (@MainActor () -> Void)?
    private var dialogWindowWaiters: [CheckedContinuation<NSWindow?, Never>] = []
    private let faviconFetcher: FaviconFetcher
    /// The page's media, to play, pause and skip; nil while asleep.
    private(set) var media: PageMedia?
    private var observers: [NSKeyValueObservation] = []
    private var webViewCanGoBack = false
    private var webViewCanGoForward = false
    private var hasSyntheticStartPageEntry: Bool
    private var syntheticForwardToWebContent = false
    /// The page holds typed input, as `FormInput` last reported.
    private var hasUnsavedInput = false
    /// A page recorded in history before its title was known (example.com sets
    /// it after `didFinish`). Its visit gets the title when it arrives.
    private var visitAwaitingTitle: String?

    init(
        id: UUID = UUID(),
        initialURL: String? = nil,
        initialRequest: URLRequest? = nil,
        restoring saved: SavedTab? = nil,
        showsStartPage: Bool = true,
        settings: BrowserSettingsStore,
        services: TabSessionServices,
        requestBuilder: NavigationRequestBuilder = NavigationRequestBuilder(),
        onSelect: (@MainActor () -> Void)? = nil,
        onOpenInNewTab: (@MainActor (URLRequest) -> Void)? = nil
    ) {
        self.id = id
        self.isNewTabPage = showsStartPage
        self.hasSyntheticStartPageEntry = showsStartPage
        self.settings = settings
        self.services = services
        self.requestBuilder = requestBuilder
        self.onOpenInNewTab = onOpenInNewTab
        self.onSelect = onSelect
        self.faviconFetcher = FaviconFetcher(store: services.faviconStore)
        self.page = .asleep(interactionState: saved?.interactionState)
        self.customTitle = saved?.customTitle
        self.lastUsedAt = saved?.lastUsedAt ?? .now
        super.init()

        refreshNavigationState()
        if let saved, !isNewTabPage {
            restore(saved)
        } else if let initialRequest {
            loadRequest(initialRequest)
        } else if let initialURL {
            loadURL(initialURL)
        } else {
            wake()
        }
    }

    /// What the tab is called: the user's name for it, or the page's title.
    var title: String {
        customTitle ?? pageTitle
    }

    var isAsleep: Bool {
        if case .asleep = page { true } else { false }
    }

    /// The live web view, for what only it can answer, like the window it's
    /// in; nil while asleep. Acting on the page goes through `wake()`.
    var webView: WKWebView? {
        if case .awake(let webView) = page { webView } else { nil }
    }

    /// Whether the page is doing something a reload would interrupt: playing
    /// audio, using the camera or microphone, or holding typed input.
    var isInUse: Bool {
        guard case .awake(let webView) = page else { return false }
        return hasUnsavedInput
            || isPlayingAudio
            || webView.cameraCaptureState != .none
            || webView.microphoneCaptureState != .none
    }

    /// The tab was selected, or was just left: either way it's in use now.
    func markUsed() {
        lastUsedAt = .now
    }

    /// The tab as saved for the next launch. A start page saves no URL.
    var savedTab: SavedTab {
        let interactionState: Data? = switch page {
        case .awake(let webView): webView.interactionState as? Data
        case .asleep(let interactionState): interactionState
        }
        return SavedTab(
            url: isNewTabPage ? "" : currentURL,
            title: isNewTabPage ? "" : pageTitle,
            customTitle: customTitle,
            interactionState: isNewTabPage ? nil : interactionState,
            lastUsedAt: lastUsedAt
        )
    }

    /// Fires whenever something in `savedTab` changes enough to save.
    var savedTabChanges: AnyPublisher<Void, Never> {
        $currentURL.map { _ in }
            .merge(with: $customTitle.map { _ in })
            .eraseToAnyPublisher()
    }

    /// A tab from the last session, or the archive, shows what it showed until
    /// it's selected and woken; its back/forward list comes back with it.
    private func restore(_ saved: SavedTab) {
        currentURL = saved.url
        pageTitle = saved.title
        updateFavicon(for: URL(string: saved.url))
    }

    // MARK: - Sleeping

    /// Brings a sleeping page back, in a new web view that takes up the saved
    /// back/forward list or loads the page afresh. Every action on the page
    /// starts here, so an awake page just answers with its web view.
    @discardableResult
    func wake() -> WKWebView {
        switch page {
        case .awake(let webView):
            return webView
        case .asleep(let interactionState):
            let webView = services.webKitEnvironment.makeWebView(in: services.context)
            page = .awake(webView)
            configureWebView(webView)
            setupObservers(for: webView)
            if let interactionState {
                webView.interactionState = interactionState
            } else if !currentURL.isEmpty {
                loadURL(currentURL)
            }
            return webView
        }
    }

    /// Releases the page's web view, keeping its back/forward list to wake
    /// from. A page that failed to load keeps only its URL, so waking tries it
    /// again. Whether the page may sleep is `TabIdlePolicy`'s call.
    func sleep() {
        guard case .awake(let webView) = page else { return }
        let interactionState = loadFailure == nil ? webView.interactionState as? Data : nil
        releaseWebView(webView)
        page = .asleep(interactionState: interactionState)
        media = nil
        isLoading = false
        estimatedProgress = 0
        loadFailure = nil
        hoveredLink = nil
        isPlayingAudio = false
        nowPlaying = nil
        hasUnsavedInput = false
    }

    func navigate(_ input: String) {
        guard let request = request(for: input) else { return }

        if isNewTabPage && syntheticForwardToWebContent {
            discardPage()
            syntheticForwardToWebContent = false
        }

        if isNewTabPage {
            hasSyntheticStartPageEntry = true
        }

        isNewTabPage = false
        let webView = wake()
        webView.load(request)
        refreshNavigationState()
        // Typing a destination hands focus to the page, as in Safari, which also
        // ends editing in the address field so it can show the new URL.
        webView.window?.makeFirstResponder(webView)
    }

    func loadURL(_ input: String) {
        guard let request = request(for: input) else { return }
        loadRequest(request)
    }

    func loadRequest(_ request: URLRequest) {
        wake().load(request)
    }

    func goBack() {
        guard !isNewTabPage else { return }

        if webViewCanGoBack {
            wake().goBack()
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

        wake().goForward()
    }

    func reload() {
        let webView = wake()
        guard webView.url != nil else { return }
        updateFavicon(for: webView.url, force: true)
        webView.reload()
    }

    /// Tries the failed page again; it may never have become `webView.url`.
    func retry() {
        guard let url = loadFailure?.url else { return reload() }
        loadRequest(URLRequest(url: url))
    }

    func stopLoading() {
        guard case .awake(let webView) = page else { return }
        webView.stopLoading()
    }

    /// Names the tab. An empty name gives it back the page's title.
    func rename(_ title: String) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        customTitle = title.isEmpty ? nil : title
    }

    func toggleMuted() {
        isMuted.toggle()
        media?.setMuted(isMuted)
    }

    /// The page's zoom, remembered for its site.
    var pageZoom: Double {
        get { webView.map { Double($0.pageZoom) } ?? services.siteZoom.zoom(for: URL(string: currentURL)) }
        set {
            let webView = wake()
            webView.pageZoom = newValue
            services.siteZoom.setZoom(newValue, for: webView.url)
        }
    }

    /// The page came on screen, so dialogs waiting for it can show.
    func pageDidAppear(in window: NSWindow?) {
        dialogWindowWaiters.forEach { $0.resume(returning: window) }
        dialogWindowWaiters.removeAll()
    }

    /// The tab closed: dialogs waiting for it are dismissed, as if cancelled.
    func close() {
        pageDidAppear(in: nil)
    }

    // MARK: - Observers

    private func setupObservers(for webView: WKWebView) {
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
        // After a failed load the web view returns to its last page, but the
        // address bar keeps showing the page that failed, as in Safari.
        guard !isShowingSyntheticStartPage, loadFailure == nil else { return }
        currentURL = url?.absoluteString ?? ""
        updateFavicon(for: url)
    }

    private func handleTitleChange(_ title: String?) {
        guard !isShowingSyntheticStartPage else { return }
        pageTitle = title ?? ""

        if let url = visitAwaitingTitle, url == currentURL, !pageTitle.isEmpty {
            services.historyStore.updateTitle(pageTitle, forLatestVisitTo: url)
            visitAwaitingTitle = nil
        }
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
        LinkHover.install(in: webView.configuration.userContentController) { [weak self] link in
            self?.hoveredLink = link
        }
        FormInput.install(in: webView.configuration.userContentController) { [weak self] hasInput in
            self?.hasUnsavedInput = hasInput
        }
        media = PageMedia(webView: webView, isMuted: isMuted) { [weak self] status in
            self?.isPlayingAudio = status.isAudible
            self?.nowPlaying = status.nowPlaying
        }
    }

    private func releaseWebView(_ webView: WKWebView) {
        observers.removeAll()
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
    }

    /// Forgets the page kept behind the start page, so navigating from there
    /// starts a fresh back/forward list.
    private func discardPage() {
        if case .awake(let webView) = page {
            releaseWebView(webView)
        }
        page = .asleep(interactionState: nil)
        media = nil

        webViewCanGoBack = false
        webViewCanGoForward = false
        currentURL = ""
        pageTitle = ""
        isLoading = false
        estimatedProgress = 0
        loadFailure = nil
        hoveredLink = nil
        isPlayingAudio = false
        nowPlaying = nil
        faviconFetcher.reset()
        favicon = nil
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
        let webView = wake()
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
        loadFailure = nil
        hoveredLink = nil
        hasUnsavedInput = false
        // URL changes were ignored while the failure showed.
        handleURLChange(webView.url)
    }

    /// A new page: its audio starts fresh, and its site opens at the zoom it
    /// was left at.
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        media?.reset()
        webView.pageZoom = services.siteZoom.zoom(for: webView.url)
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        showFailure(error)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let url = webView.url?.absoluteString ?? ""
        let title = webView.title ?? ""
        if !services.context.isPrivate {
            services.historyStore.recordVisit(url: url, title: title)
            visitAwaitingTitle = title.isEmpty ? url : nil
        }
        faviconFetcher.upgradeFromPage(webView, currentImage: favicon) { [weak self] image in
            self?.favicon = image
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showFailure(error)
    }

    /// Cancellations aren't failures: another navigation replaced this one, or
    /// the response became a download, which WebKit reports as its "frame load
    /// interrupted" error, or WebKit's media player took over a video or audio
    /// file, its "plug-in handled load" (the constants for both are deprecated).
    private func showFailure(_ error: Error) {
        let error = error as NSError
        let isCancellation = (error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled)
            || (error.domain == "WebKitErrorDomain" && [102, 204].contains(error.code))
        guard !isCancellation else { return }

        let url = error.userInfo[NSURLErrorFailingURLErrorKey] as? URL
        loadFailure = LoadFailure(url: url, message: error.localizedDescription)
        if let url {
            currentURL = url.absoluteString
        }
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction
    ) async -> WKNavigationActionPolicy {
        if navigationAction.targetFrame?.isMainFrame == true {
            updateFavicon(for: navigationAction.request.url)
            services.contentBlocker.update(
                webView.configuration.userContentController,
                for: navigationAction.request.url
            )
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

    /// HTTP logins get a sheet; everything else, like server trust, gets WebKit's
    /// default handling. Cancelling shows the page the server sends instead.
    func webView(
        _ webView: WKWebView,
        respondTo challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        let loginMethods = [
            NSURLAuthenticationMethodHTTPBasic,
            NSURLAuthenticationMethodHTTPDigest,
            NSURLAuthenticationMethodNTLM,
        ]
        guard loginMethods.contains(challenge.protectionSpace.authenticationMethod) else {
            return (.performDefaultHandling, nil)
        }
        guard let window = await dialogWindow(),
              let credential = await PageDialogs.logIn(to: challenge, in: window) else {
            return (.rejectProtectionSpace, nil)
        }
        return (.useCredential, credential)
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

    /// The window to show one of the page's dialogs on. A page in a background
    /// tab has none, so its tab is selected first, as Safari does for alerts,
    /// and the dialog waits for the page to come on screen.
    private func dialogWindow() async -> NSWindow? {
        if case .awake(let webView) = page, let window = webView.window { return window }
        onSelect?()
        return await withCheckedContinuation { dialogWindowWaiters.append($0) }
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo
    ) async {
        guard let window = await dialogWindow() else { return }
        await PageDialogs.alert(message, from: frame, in: window)
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo
    ) async -> Bool {
        guard let window = await dialogWindow() else { return false }
        return await PageDialogs.confirm(message, from: frame, in: window)
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo
    ) async -> String? {
        guard let window = await dialogWindow() else { return nil }
        return await PageDialogs.prompt(prompt, defaultText: defaultText, from: frame, in: window)
    }

    func webView(
        _ webView: WKWebView,
        decideMediaCapturePermissionsFor origin: WKSecurityOrigin,
        initiatedBy frame: WKFrameInfo,
        type: WKMediaCaptureType
    ) async -> WKPermissionDecision {
        await decidePermission(for: SitePermissions.Device.devices(for: type), origin: origin)
    }

    @available(macOS 27.0, *)
    func webView(
        _ webView: WKWebView,
        requestGeolocationPermissionFor origin: WKSecurityOrigin,
        initiatedBy frame: WKFrameInfo
    ) async -> WKPermissionDecision {
        await decidePermission(for: [.location], origin: origin)
    }

    private func decidePermission(
        for devices: [SitePermissions.Device],
        origin: WKSecurityOrigin
    ) async -> WKPermissionDecision {
        guard let window = await dialogWindow() else { return .deny }
        return await services.context.sitePermissions.decide(devices, for: origin) {
            await PageDialogs.allow(devices, for: origin, in: window)
        }
    }

    func webView(
        _ webView: WKWebView,
        runOpenPanelWith parameters: WKOpenPanelParameters,
        initiatedByFrame frame: WKFrameInfo
    ) async -> [URL]? {
        guard let window = await dialogWindow() else { return nil }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canChooseDirectories = parameters.allowsDirectories
        return await panel.beginSheetModal(for: window) == .OK ? panel.urls : nil
    }
}
