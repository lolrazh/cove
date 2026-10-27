import Foundation

/// Arc's Peek: a link from a pinned tab or favorite to another site, or any
/// link clicked with Shift, opens in a card over the page. Close it and the
/// page underneath is as it was; expand it and the same tab, page and all,
/// moves into Today beside the tab it came from.
extension TabManager {
    struct Peek {
        let tab: TabSession
        /// The tab the link was clicked in.
        let openerID: UUID
    }

    func openPeek(_ request: URLRequest, from openerID: UUID) {
        closePeek()
        let tab = TabSession(
            initialRequest: request,
            showsStartPage: false,
            settings: settings,
            services: services,
            // Already on screen; pages it opens go beside its opener.
            host: TabSession.Host(
                select: {},
                openInNewTab: { [weak self] request in self?.addTab(request: request, nextTo: openerID) }
            )
        )
        peek = Peek(tab: tab, openerID: openerID)
    }

    func closePeek() {
        guard let peek else { return }
        self.peek = nil
        peek.tab.close()
    }

    func expandPeek() {
        guard let peek else { return }
        self.peek = nil
        adoptTab(peek.tab, nextTo: peek.openerID)
    }
}
