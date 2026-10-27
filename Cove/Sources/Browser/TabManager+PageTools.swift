import Foundation

/// The View and File menus' page commands, and the Command Bar's, for the
/// active tab. None of them apply to a start page.
extension TabManager {
    var activePage: TabSession? {
        activeTab.flatMap { $0.isNewTabPage ? nil : $0 }
    }

    // MARK: - Find

    func findInPage() {
        activePage?.findInPage.present()
    }

    func findNext() {
        activePage?.findInPage.findNext()
    }

    func findPrevious() {
        activePage?.findInPage.findPrevious()
    }

    // MARK: - Zoom

    func zoomIn() {
        guard let page = activePage, let zoom = PageZoom.zoomedIn(from: page.pageZoom) else { return }
        setZoom(zoom, of: page, symbol: "plus.magnifyingglass")
    }

    func zoomOut() {
        guard let page = activePage, let zoom = PageZoom.zoomedOut(from: page.pageZoom) else { return }
        setZoom(zoom, of: page, symbol: "minus.magnifyingglass")
    }

    func resetZoom() {
        guard let page = activePage else { return }
        setZoom(1, of: page, symbol: "1.magnifyingglass")
    }

    private func setZoom(_ zoom: Double, of page: TabSession, symbol: String) {
        page.pageZoom = zoom
        toasts.show("Zoom \(zoom.formatted(.percent))", symbol: symbol)
    }
}
