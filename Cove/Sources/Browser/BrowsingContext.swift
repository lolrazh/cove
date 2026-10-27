import WebKit

/// What a window's tabs browse with: where sites keep their cookies, storage,
/// cache and favicons, what they've been allowed to use, and whether their
/// pages leave a trace, and which extensions run. Each profile has one,
/// shared by its spaces' tabs in every window; each private window gets its
/// own, which goes when the window closes.
@MainActor
final class BrowsingContext {
    let dataStore: WKWebsiteDataStore
    /// Private browsing records nothing: no history, no saved session, no
    /// archive, and its tabs never come back.
    let isPrivate: Bool
    let faviconStore: FaviconStore
    let sitePermissions = SitePermissions()
    let extensions: ExtensionHost

    private init(dataStore: WKWebsiteDataStore, faviconStore: FaviconStore, extensions: ExtensionHost, isPrivate: Bool) {
        self.dataStore = dataStore
        self.faviconStore = faviconStore
        self.extensions = extensions
        self.isPrivate = isPrivate
    }

    /// The default profile's: WebKit's default data store.
    static func standard(faviconStore: FaviconStore, extensions library: ExtensionLibrary) -> BrowsingContext {
        let dataStore = WKWebsiteDataStore.default()
        return BrowsingContext(
            dataStore: dataStore,
            faviconStore: faviconStore,
            extensions: ExtensionHost(storageID: nil, dataStore: dataStore, library: library),
            isPrivate: false
        )
    }

    /// Another profile's: a persistent data store of its own, found again by
    /// the profile's ID on every launch, and extension storage the same way.
    /// Favicons are shared; they say which sites were visited, not who was
    /// signed in.
    static func profile(_ id: UUID, faviconStore: FaviconStore, extensions library: ExtensionLibrary) -> BrowsingContext {
        let dataStore = WKWebsiteDataStore(forIdentifier: id)
        return BrowsingContext(
            dataStore: dataStore,
            faviconStore: faviconStore,
            extensions: ExtensionHost(storageID: id, dataStore: dataStore, library: library),
            isPrivate: false
        )
    }

    /// A context whose site data lives in memory only. It reads favicons the
    /// base context already has, but keeps the ones it fetches to itself. It
    /// runs the base's extensions, those allowed in private windows.
    static func makePrivate(over base: BrowsingContext) -> BrowsingContext {
        BrowsingContext(
            dataStore: .nonPersistent(),
            faviconStore: FaviconStore(readingThrough: base.faviconStore),
            extensions: base.extensions,
            isPrivate: true
        )
    }
}
