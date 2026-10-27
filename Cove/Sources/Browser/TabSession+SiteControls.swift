import Foundation
import WebKit

/// What site controls show and change for the tab's page.
extension TabSession {
    /// The page's address if it's a website, the only kind of page site
    /// controls are for.
    var siteURL: URL? {
        guard !isNewTabPage, let url = URL(string: currentURL), ["http", "https"].contains(url.scheme) else {
            return nil
        }
        return url
    }

    var connectionSecurity: ConnectionSecurity {
        ConnectionSecurity(
            url: webView?.url,
            trust: webView?.serverTrust,
            hasOnlySecureContent: webView?.hasOnlySecureContent ?? false
        )
    }

    var sitePermissions: SitePermissions {
        services.sitePermissions
    }

    /// Whether ads and trackers are blocked here: on in Settings, and not
    /// turned off for this site.
    var blocksContent: Bool {
        services.contentBlocker.isEnabled && services.contentBlocker.blocks(on: siteURL)
    }

    var canChangeContentBlocking: Bool {
        services.contentBlocker.isEnabled
    }

    /// Turns blocking on or off for the site, and reloads so the page shows
    /// the difference.
    func setBlocksContent(_ blocks: Bool) {
        services.contentBlocker.setBlocks(blocks, on: siteURL)
        reload()
    }

    /// Removes the site's cookies, storage and cache, then reloads. WebKit
    /// keeps them by registrable domain, so a page on a subdomain clears its
    /// whole site.
    func clearSiteData() async {
        guard let host = siteURL?.host() else { return }
        let store = wake().configuration.websiteDataStore
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        let records = await store.dataRecords(ofTypes: types)
        await store.removeData(ofTypes: types, for: records.filter { Site(domain: $0.displayName).contains(host) })
        reload()
    }
}
