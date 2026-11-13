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
    /// Lazy only because they need `self`.
    private(set) lazy var externalURLRouter = ExternalURLRouter(settings: settingsStore, littleCove: littleCove)
    private(set) lazy var littleCove = LittleCove(appServices: self)
    let tabArchive = TabArchive()
    /// What the default profile browses with; other profiles' contexts come
    /// from the profile store, and private windows make their own.
    let browsingContext: BrowsingContext
    let profileStore: ProfileStore
    let pinStore = PinStore()
    let documentStore = DocumentStore()
    let sessionStore = SessionStore()
    let siteZoom = SiteZoomStore()
    let boosts = BoostInjector(store: BoostStore())
    let extensionLibrary: ExtensionLibrary

    private var didPrepareLaunch = false
    private var profilePruning: AnyCancellable?

    init(defaults: UserDefaults = .standard) {
        let settingsStore = BrowserSettingsStore(defaults: defaults)
        let historyStore = HistoryStore(settings: settingsStore)
        let faviconStore = FaviconStore()
        let downloadManager = DownloadManager(settings: settingsStore)
        let contentBlockerManager = ContentBlockerManager(settings: settingsStore, defaults: defaults)
        let extensionLibrary = ExtensionLibrary()

        self.settingsStore = settingsStore
        self.historyStore = historyStore
        self.faviconStore = faviconStore
        let browsingContext = BrowsingContext.standard(faviconStore: faviconStore, extensions: extensionLibrary)
        self.browsingContext = browsingContext
        self.extensionLibrary = extensionLibrary
        self.profileStore = ProfileStore(
            initialTheme: ChromeTheme(rawValue: defaults.string(forKey: BrowserSettingKeys.legacyThemeColor) ?? "")
        ) { profileID in
            profileID == Profile.defaultID
                ? browsingContext
                : .profile(profileID, faviconStore: faviconStore, extensions: extensionLibrary)
        }
        self.downloadManager = downloadManager
        self.contentBlockerManager = contentBlockerManager
        self.webKitEnvironment = WebKitEnvironment(contentBlockerManager: contentBlockerManager)

        // Pins follow their profiles and profiles, whichever window or Settings
        // deleted them.
        profilePruning = profileStore.$profiles.sink { [pinStore] profiles in
            pinStore.change { $0.prune(to: profiles) }
        }
        extensionLibrary.openBrowserWindow = { [weak self] isPrivate in
            self?.externalURLRouter.openBrowserWindow(isPrivate: isPrivate)
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
        profileStore.removeOrphanedDataStores()
        Task { [extensionLibrary] in
            await extensionLibrary.loadInstalled()
        }

    }
}
