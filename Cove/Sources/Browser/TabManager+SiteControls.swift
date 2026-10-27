import Foundation

/// Site controls for the active tab, from the glyph at the front of the URL
/// pill or address field, and from the Command Bar.
extension TabManager {
    func showSiteControls() {
        guard activePage?.siteURL != nil else { return }
        isShowingSiteControls = true
    }

    func clearSiteData() {
        guard let page = activePage, let site = Site(page.siteURL) else { return }
        Task {
            await page.clearSiteData()
            toasts.show("Cleared Data for \(site.domain)", symbol: "trash")
        }
    }
}
