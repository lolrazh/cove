import Foundation

@MainActor
final class AppServices {
    let settingsStore: BrowserSettingsStore
    let historyStore: HistoryStore
    let faviconStore: FaviconStore
    let downloadManager: DownloadManager
    let contentBlockerManager: ContentBlockerManager
    let webKitEnvironment: WebKitEnvironment

    private var didPrepareLaunch = false

    init(defaults: UserDefaults = .standard) {
        let settingsStore = BrowserSettingsStore(defaults: defaults)
        let historyStore = HistoryStore(settings: settingsStore)
        let faviconStore = FaviconStore()
        let downloadManager = DownloadManager(settings: settingsStore)
        let contentBlockerManager = ContentBlockerManager(settings: settingsStore)

        self.settingsStore = settingsStore
        self.historyStore = historyStore
        self.faviconStore = faviconStore
        self.downloadManager = downloadManager
        self.contentBlockerManager = contentBlockerManager
        self.webKitEnvironment = WebKitEnvironment(contentBlockerManager: contentBlockerManager)
    }

    var tabSessionServices: TabSessionServices {
        TabSessionServices(
            historyStore: historyStore,
            faviconStore: faviconStore,
            downloadManager: downloadManager,
            webKitEnvironment: webKitEnvironment
        )
    }

    func prepareForLaunch() {
        guard !didPrepareLaunch else { return }
        didPrepareLaunch = true

        guard settingsStore.contentBlockingEnabled else { return }

        Task { [contentBlockerManager] in
            await contentBlockerManager.load()
        }
    }
}
