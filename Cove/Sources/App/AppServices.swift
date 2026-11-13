import Combine
import Foundation

@MainActor
final class AppServices {
    let settingsStore: BrowserSettingsStore
    let contentBlockerManager: ContentBlockerManager
    let webKitEnvironment: WebKitEnvironment
    private(set) lazy var externalURLRouter = ExternalURLRouter(settings: settingsStore, littleCove: littleCove)
    private(set) lazy var littleCove = LittleCove(appServices: self)
    let defaultData: ProfileData
    let browsingContext: BrowsingContext
    let profileStore: ProfileStore
    let pinStore = PinStore()
    let sessionStore = SessionStore()
    let extensionLibrary: ExtensionLibrary

    private var didPrepareLaunch = false
    private var profilePruning: AnyCancellable?

    init(defaults: UserDefaults = .standard) {
        let settings = BrowserSettingsStore(defaults: defaults)
        let data = ProfileData(id: Profile.defaultID, settings: settings)
        let blocker = data.blocker
        let extensions = ExtensionLibrary(directory: ProfileMigration.isTesting ? nil : ExtensionLibrary.defaultDirectory)
        let context = BrowsingContext.standard(faviconStore: data.favicons, extensions: extensions, profileData: data)
        self.settingsStore = settings
        self.defaultData = data
        self.browsingContext = context
        self.extensionLibrary = extensions
        self.profileStore = ProfileStore { id in
            if id == Profile.defaultID { return context }
            let data = ProfileData(id: id, settings: settings)
            return .profile(id, faviconStore: data.favicons, extensions: extensions, profileData: data)
        }
        self.contentBlockerManager = blocker
        self.webKitEnvironment = data.environment
        profilePruning = profileStore.$profiles.sink { [pinStore] profiles in
            pinStore.change { $0.prune(to: profiles) }
        }
        extensions.openBrowserWindow = { [weak self] isPrivate in
            self?.externalURLRouter.openBrowserWindow(isPrivate: isPrivate)
        }
    }

    func context(for id: UUID) -> BrowsingContext {
        guard let profile = profileStore.profiles.profile(id) else { return browsingContext }
        return profileStore.context(for: profile)
    }

    var currentContext: BrowsingContext {
        externalURLRouter.activeTabManager?.services.context ?? browsingContext
    }

    func tabSessionServices(in context: BrowsingContext) -> TabSessionServices {
        let data = context.profileData ?? defaultData
        return TabSessionServices(historyStore: data.history, faviconStore: context.faviconStore,
            downloadManager: context.downloads, webKitEnvironment: data.environment,
            contentBlocker: data.blocker, context: context, siteZoom: data.zoom, boosts: data.boosts)
    }

    func prepareForLaunch() {
        guard !didPrepareLaunch else { return }
        didPrepareLaunch = true
        if !ProfileMigration.isTesting { profileStore.removeOrphanedDataStores() }
        Task { [extensionLibrary] in await extensionLibrary.loadInstalled() }
    }
}
