import WebKit

/// What a window browses with: where sites keep their cookies, storage and
/// cache, what they've been allowed to use, and whether its pages leave a
/// trace. Normal windows share one; each private window gets its own, which
/// goes when the window closes. A profile will be one of these too.
@MainActor
final class BrowsingContext {
    let dataStore: WKWebsiteDataStore
    /// Private browsing records nothing: no history, no saved session, no
    /// archive, and its tabs never come back.
    let isPrivate: Bool
    let sitePermissions = SitePermissions()

    private init(dataStore: WKWebsiteDataStore, isPrivate: Bool) {
        self.dataStore = dataStore
        self.isPrivate = isPrivate
    }

    static func standard() -> BrowsingContext {
        BrowsingContext(dataStore: .default(), isPrivate: false)
    }

    /// A context whose site data lives in memory only.
    static func makePrivate() -> BrowsingContext {
        BrowsingContext(dataStore: .nonPersistent(), isPrivate: true)
    }
}
