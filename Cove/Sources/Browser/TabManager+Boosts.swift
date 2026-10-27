import Foundation

/// Boosts for the active tab's site, from site controls and the Command Bar.
/// A private window applies Boosts but doesn't make or change them: like
/// pins, a Boost would write down the name of a site visited privately.
extension TabManager {
    var canBoost: Bool {
        !isPrivate && activePage?.siteURL != nil
    }

    func editBoost() {
        guard canBoost, let page = activePage, let site = Site(page.siteURL) else { return }
        isShowingSiteControls = false
        boostEditor?.stopZapping()
        boostEditor = BoostEditor(page: page, site: site)
    }

    func closeBoostEditor() {
        boostEditor?.stopZapping()
        boostEditor = nil
    }
}
