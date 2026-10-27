import Foundation

/// The Boost site controls show for the tab's page.
extension TabSession {
    var boostStore: BoostStore {
        services.boosts.store
    }

    /// The Boost for the page's site, or the one covering it, on or off.
    var boost: Boost? {
        Site(siteURL).flatMap(boostStore.boost(for:))
    }

    /// Turns the site's Boost on or off. Styles follow at once; a script
    /// needs the page loaded again.
    func setBoostEnabled(_ isEnabled: Bool) {
        guard var boost else { return }
        boost.isEnabled = isEnabled
        boostStore.save(boost)
        if boost.hasScript { reload() }
    }
}
