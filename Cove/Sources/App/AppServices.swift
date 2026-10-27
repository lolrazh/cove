import Combine
import Foundation

@MainActor
final class AppServices {
    let settingsStore: BrowserSettingsStore
    let historyStore: HistoryStore
    let faviconStore: FaviconStore
    let downloadManager: DownloadManager
    let contentBlockerManager: ContentBlockerManager
    let webKitEnvironment: WebKitEnvironment
    let externalURLRouter: ExternalURLRouter
    let tabArchive = TabArchive()
    /// What the default profile browses with; other profiles' contexts come
    /// from the space store, and private windows make their own.
    let browsingContext: BrowsingContext
    let spaceStore: SpaceStore
    let pinStore = PinStore()
    let sessionStore = SessionStore()
    let siteZoom = SiteZoomStore()
    let boosts = BoostInjector(store: BoostStore())

    private var didPrepareLaunch = false
    private var spacePruning: AnyCancellable?

    init(defaults: UserDefaults = .standard) {
        let settingsStore = BrowserSettingsStore(defaults: defaults)
        let historyStore = HistoryStore(settings: settingsStore)
        let faviconStore = FaviconStore()
        let downloadManager = DownloadManager(settings: settingsStore)
        let contentBlockerManager = ContentBlockerManager(settings: settingsStore)
        let externalURLRouter = ExternalURLRouter()

        self.settingsStore = settingsStore
        self.historyStore = historyStore
        self.faviconStore = faviconStore
        let browsingContext = BrowsingContext.standard(faviconStore: faviconStore)
        self.browsingContext = browsingContext
        self.spaceStore = SpaceStore(
            initialTheme: ChromeTheme(rawValue: defaults.string(forKey: BrowserSettingKeys.legacyThemeColor) ?? "")
        ) { profileID in
            profileID == Profile.defaultID ? browsingContext : .profile(profileID, faviconStore: faviconStore)
        }
        self.downloadManager = downloadManager
        self.contentBlockerManager = contentBlockerManager
        self.webKitEnvironment = WebKitEnvironment(contentBlockerManager: contentBlockerManager)
        self.externalURLRouter = externalURLRouter

        // Pins follow their spaces and profiles, whichever window or Settings
        // deleted them.
        spacePruning = spaceStore.$spaces.sink { [pinStore] spaces in
            pinStore.change { $0.prune(to: spaces) }
        }
    }

    func tabSessionServices(in context: BrowsingContext) -> TabSessionServices {
        TabSessionServices(
            historyStore: historyStore,
            faviconStore: context.faviconStore,
            downloadManager: downloadManager,
            webKitEnvironment: webKitEnvironment,
            contentBlocker: contentBlockerManager,
            context: context,
            siteZoom: siteZoom,
            boosts: boosts
        )
    }

    func prepareForLaunch() {
        guard !didPrepareLaunch else { return }
        didPrepareLaunch = true
        spaceStore.removeOrphanedDataStores()

        guard settingsStore.contentBlockingEnabled else { return }

        Task { [contentBlockerManager] in
            await contentBlockerManager.load()
        }
    }
}
