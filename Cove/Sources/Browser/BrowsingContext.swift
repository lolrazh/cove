import WebKit

/// What a window's tabs browse with: where sites keep their cookies, storage,
/// cache and favicons, what they've been allowed to use, and whether their
/// pages leave a trace. Each profile has one, shared by its spaces' tabs in
/// every window; each private window gets its own, which goes when the window
/// closes.
@MainActor
final class BrowsingContext {
    let dataStore: WKWebsiteDataStore
    /// Private browsing records nothing: no history, no saved session, no
    /// archive, and its tabs never come back.
    let isPrivate: Bool
    let faviconStore: FaviconStore
    let sitePermissions = SitePermissions()

    private init(dataStore: WKWebsiteDataStore, faviconStore: FaviconStore, isPrivate: Bool) {
        self.dataStore = dataStore
        self.faviconStore = faviconStore
        self.isPrivate = isPrivate
    }

    /// The default profile's: WebKit's default data store.
    static func standard(faviconStore: FaviconStore) -> BrowsingContext {
        BrowsingContext(dataStore: .default(), faviconStore: faviconStore, isPrivate: false)
    }

    /// Another profile's: a persistent data store of its own, found again by
    /// the profile's ID on every launch. Favicons are shared; they say which
    /// sites were visited, not who was signed in.
    static func profile(_ id: UUID, faviconStore: FaviconStore) -> BrowsingContext {
        BrowsingContext(dataStore: WKWebsiteDataStore(forIdentifier: id), faviconStore: faviconStore, isPrivate: false)
    }

    /// A context whose site data lives in memory only. It reads favicons the
    /// base context already has, but keeps the ones it fetches to itself.
    static func makePrivate(over base: BrowsingContext) -> BrowsingContext {
        BrowsingContext(
            dataStore: .nonPersistent(),
            faviconStore: FaviconStore(readingThrough: base.faviconStore),
            isPrivate: true
        )
    }
}
