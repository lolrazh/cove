import AppKit

/// The one path for pages opened from outside a browser window: links from
/// other apps, and pages opened from History. They go to the browser window
/// that was active last, each in a new tab, and that window comes forward.
@MainActor
final class ExternalURLRouter {
    private struct BrowserWindow {
        weak var tabManager: TabManager?
        weak var window: NSWindow?
    }

    /// Most recently active last. Closed windows drop out on their own.
    private var browserWindows: [BrowserWindow] = []
    /// Links that arrive before any window is ready, as when a link launches Cove.
    private var pendingURLs: [URL] = []

    /// Called whenever a browser window becomes active.
    func activate(_ tabManager: TabManager, in window: NSWindow) {
        browserWindows.removeAll { $0.tabManager == nil || $0.tabManager === tabManager }
        browserWindows.append(BrowserWindow(tabManager: tabManager, window: window))
        open(pendingURLs)
        pendingURLs.removeAll()
    }

    func open(_ urls: [URL]) {
        let urls = urls.filter(Self.canOpen)
        guard !urls.isEmpty else { return }

        guard let target = browserWindows.last(where: { $0.tabManager != nil }),
              let tabManager = target.tabManager else {
            pendingURLs.append(contentsOf: urls)
            return
        }

        urls.forEach(tabManager.openExternalURL)
        target.window?.makeKeyAndOrderFront(nil)
    }

    static func canOpen(_ url: URL) -> Bool {
        let scheme = url.scheme?.lowercased()
        return scheme == "http" || scheme == "https" || scheme == "file"
    }
}
