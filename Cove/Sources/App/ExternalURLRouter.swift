import SwiftUI

/// The one path for pages opened from outside a browser window: links from
/// other apps, pages opened from History, and Little Cove's pages moving into
/// Cove. They go to the browser window that was active last, each in a new
/// tab, and that window comes forward; links from other apps may open in
/// Little Cove instead.
@MainActor
final class ExternalURLRouter {
    /// Where a page comes from. Only links from other apps can go to Little
    /// Cove; a page asked for inside Cove goes to a browser window.
    enum Source {
        case otherApp
        case cove
    }

    private struct BrowserWindow {
        weak var tabManager: TabManager?
        weak var window: NSWindow?
    }

    private let settings: BrowserSettingsStore
    private let littleCove: LittleCove
    /// Most recently active last. Closed windows drop out on their own.
    private var browserWindows: [BrowserWindow] = []
    /// Pages that arrive before any window is ready, as when a link launches
    /// Cove, or when Little Cove moves a page with every window closed.
    private var pending: [(TabManager) -> Void] = []
    /// Opens a browser window when none is left, from a browser window's
    /// environment: only views can open scenes.
    private var openBrowserWindow: OpenWindowAction?

    init(settings: BrowserSettingsStore, littleCove: LittleCove) {
        self.settings = settings
        self.littleCove = littleCove
    }

    /// Called whenever a browser window becomes active.
    func activate(_ tabManager: TabManager, in window: NSWindow, openWindow: OpenWindowAction) {
        browserWindows.removeAll { $0.tabManager == nil || $0.tabManager === tabManager }
        browserWindows.append(BrowserWindow(tabManager: tabManager, window: window))
        openBrowserWindow = openWindow
        let pending = pending
        self.pending.removeAll()
        pending.forEach { $0(tabManager) }
    }

    /// The decision point for every page from outside a window: Little Cove
    /// or a tab. Air Traffic Control's rules, choosing a space, slot in here.
    func open(_ urls: [URL], from source: Source) {
        for url in urls where Self.canOpen(url) {
            if source == .otherApp && settings.opensLinksInLittleCove {
                littleCove.open(url)
            } else {
                inBrowserWindow { $0.openExternalURL(url) }
            }
        }
    }

    /// ⌥⌘N: an empty Little Cove, from anywhere in the app.
    func openLittleCove() {
        littleCove.open(nil)
    }

    /// A new browser window, private or not, as an extension's
    /// `windows.create` asks; from the last active window's environment.
    func openBrowserWindow(isPrivate: Bool) {
        openBrowserWindow?(id: isPrivate ? BrowserView.privateWindowID : BrowserView.windowID)
    }

    /// Open in Cove: Little Cove's tab, page and all, into Today.
    func moveToBrowserWindow(_ tab: TabSession) {
        inBrowserWindow { $0.adoptTab(tab) }
    }

    private func inBrowserWindow(_ action: @escaping (TabManager) -> Void) {
        guard let target = browserWindows.last(where: { $0.tabManager != nil }),
              let tabManager = target.tabManager else {
            if pending.isEmpty { openBrowserWindow?(id: BrowserView.windowID) }
            pending.append(action)
            return
        }
        action(tabManager)
        target.window?.makeKeyAndOrderFront(nil)
    }

    static func canOpen(_ url: URL) -> Bool {
        let scheme = url.scheme?.lowercased()
        return scheme == "http" || scheme == "https" || scheme == "file"
    }
}
