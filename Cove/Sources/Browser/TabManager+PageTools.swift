import Foundation

/// The View and File menus' page commands, and the Command Bar's, for the
/// active tab. None of them apply to a start page, or while a note covers
/// the page.
extension TabManager {
    var activePage: TabSession? {
        guard activeDocumentID == nil else { return nil }
        return activeTab.flatMap { $0.isNewTabPage ? nil : $0 }
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

    // MARK: - Print, Save, Source

    func printPage() {
        activePage?.printPage()
    }

    /// Save Page As: a web archive or the page's HTML, wherever the sheet says.
    func savePage() {
        guard let page = activePage, let window = page.webView?.window else { return }
        let name = page.pageTitle.isEmpty ? page.webView?.url?.host() ?? "Page" : page.pageTitle

        Task {
            guard let (url, format) = await SavePagePanel.run(suggestedName: name, in: window) else { return }
            let data: Data? = switch format {
            case .webArchive: try? await page.webArchive()
            case .source: await page.pageSource()?.data
            }
            let saved = data.map { (try? $0.write(to: url)) != nil } ?? false
            if !saved {
                toasts.show("Couldn't Save Page", symbol: ChromeSymbols.Navigation.loadFailed)
            }
        }
    }

    /// View Source: the page's HTML in a window of its own.
    func viewSource() {
        guard let page = activePage else { return }
        Task {
            guard let source = await page.pageSource()?.text else {
                toasts.show("No Source for This Page", symbol: ChromeSymbols.Navigation.loadFailed)
                return
            }
            SourceWindow.show(source, of: page.currentURL, over: page.webView?.window)
        }
    }

    // MARK: - Picture in Picture

    func togglePictureInPicture() {
        guard let page = activePage else { return }
        Task {
            if await !page.togglePictureInPicture() {
                toasts.show("No Video on This Page", symbol: "pip")
            }
        }
    }
}
