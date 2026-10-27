import AppKit
import Combine
import WebKit

/// A browser window as extensions see it: the tabs of the space it shows,
/// Favorites, Pinned and Today, with its active tab. It follows its
/// `TabManager` and tells the space's `ExtensionHost` about tabs opening,
/// closing and being selected, and about the window moving to another
/// profile's space. Owned by the `TabManager`; the toolbar watches it for
/// the active tab, whose actions it shows.
@MainActor
final class ExtensionWindow: NSObject, ObservableObject {
    private(set) weak var tabManager: TabManager?
    private(set) weak var window: NSWindow?
    /// The host the window reports to: its space's profile's.
    private(set) weak var host: ExtensionHost?
    /// The tabs extensions know of, by tab ID.
    private var tabs: [UUID: ExtensionTab] = [:]
    /// The active tab, once reported.
    @Published private(set) var activeTab: ExtensionTab?
    /// Each extension's buttons in this window (the sidebar's, the
    /// navigation bar's), by extension, for its popup to point at, with the
    /// menu holding those that don't fit and the site controls' glyph.
    private var anchors: [String: [Weak<NSView>]] = [:]
    /// The popup on screen, which closes when another tab is selected.
    private weak var popover: NSPopover?
    private var cancellables: Set<AnyCancellable> = []

    static let menuAnchorID = "menu"
    static let siteControlsAnchorID = "site-controls"

    /// Starts following a window's tabs.
    func track(_ tabManager: TabManager) {
        self.tabManager = tabManager
        Publishers.CombineLatest4(tabManager.$today, tabManager.$favorites, tabManager.$pinned, tabManager.$activeTabID)
            .map { _ in }
            // `@Published` announces changes before making them.
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.sync() }
            .store(in: &cancellables)
    }

    /// The window came on screen. Focus is reported from here on.
    func attach(_ window: NSWindow) {
        guard self.window !== window else { return }
        self.window = window
        NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification, object: window)
            .sink { [weak self] _ in
                guard let self else { return }
                host?.didFocus(self)
            }
            .store(in: &cancellables)
        tabManager?.extensionHost.library.windowDidAppear(self)
    }

    /// The window closed: its tabs close with it.
    func close() {
        guard let host else { return }
        for tab in tabs.values {
            host.controller.didCloseTab(tab, windowIsClosing: true)
        }
        tabs = [:]
        activeTab = nil
        host.remove(self)
        self.host = nil
    }

    // MARK: - Following the tab manager

    /// Reports what changed since the last look: the profile, tabs opened
    /// and closed, and the active tab.
    private func sync() {
        guard let tabManager else { return }
        let newHost = tabManager.extensionHost
        if newHost !== host {
            close()
            host = newHost
            newHost.add(self)
        }
        guard let host else { return }

        let shown = tabManager.allTabs
        let shownIDs = Set(shown.map(\.id))
        for (id, tab) in tabs where !shownIDs.contains(id) {
            tabs[id] = nil
            host.controller.didCloseTab(tab, windowIsClosing: false)
        }
        shown.forEach { extensionTab(for: $0) }

        let active = tabManager.activeTab.map { extensionTab(for: $0) }
        if let active, active !== activeTab {
            host.controller.didActivateTab(active, previousActiveTab: activeTab)
        }
        if active !== activeTab {
            activeTab = active
            popover?.performClose(nil)
        }
    }

    /// The tab's stand-in for extensions, made and announced the first time
    /// it's asked for.
    @discardableResult
    func extensionTab(for session: TabSession) -> ExtensionTab {
        if let tab = tabs[session.id] { return tab }
        let tab = ExtensionTab(session: session, window: self)
        tabs[session.id] = tab
        host?.controller.didOpenTab(tab)
        return tab
    }

    // MARK: - Acting for extensions

    /// Opens a tab for an extension: a page, or the start page, beside a tab
    /// or at the top of Today.
    func openTab(url: URL?, nextTo parent: ExtensionTab?, selected: Bool) -> ExtensionTab? {
        guard let tabManager, let session = tabManager.openTab(url: url, nextTo: parent?.session.id, selected: selected) else { return nil }
        return extensionTab(for: session)
    }

    /// The pages of a window an extension opened: the first in place of its
    /// start page, the rest beside it.
    func open(_ urls: [URL]) {
        urls.forEach { tabManager?.openExternalURL($0) }
    }

    // MARK: - Popups

    /// Whether a button is where it can be seen: in this window, inside its
    /// bounds. The sidebar's header stays in the window while the sidebar
    /// is hidden, off its edge, as does the navigation bar with tabs in
    /// the sidebar.
    private func isOnScreen(_ view: NSView) -> Bool {
        guard let window, view.window === window, !view.isHiddenOrHasHiddenAncestor else { return false }
        return NSRect(origin: .zero, size: window.frame.size).contains(view.convert(view.bounds, to: nil))
    }

    func addAnchor(_ view: NSView, for id: String) {
        anchors[id, default: []].removeAll { $0.value == nil }
        anchors[id, default: []].append(Weak(view))
    }

    /// Shows an extension's popup from its button, or the menu it's in, or
    /// the site controls' glyph, or, with none on screen (as with the
    /// sidebar hidden), from the top of the window.
    func present(_ popover: NSPopover, for context: WKWebExtensionContext) {
        let anchor = [context.uniqueIdentifier, Self.menuAnchorID, Self.siteControlsAnchorID]
            .lazy
            .flatMap { self.anchors[$0] ?? [] }
            .compactMap(\.value)
            .first(where: isOnScreen)
        self.popover = popover
        if let anchor {
            popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: anchor.isFlipped ? .maxY : .minY)
        } else if let content = window?.contentView {
            let top = NSRect(x: content.bounds.midX, y: content.isFlipped ? 0 : content.bounds.maxY - 1, width: 1, height: 1)
            popover.show(relativeTo: top, of: content, preferredEdge: content.isFlipped ? .maxY : .minY)
        }
    }
}

// MARK: - WKWebExtensionWindow

extension ExtensionWindow: WKWebExtensionWindow {
    func tabs(for context: WKWebExtensionContext) -> [any WKWebExtensionTab] {
        (tabManager?.tabsInDisplayOrder ?? []).compactMap { tabs[$0.id] }
    }

    func activeTab(for context: WKWebExtensionContext) -> (any WKWebExtensionTab)? {
        activeTab
    }

    func isPrivate(for context: WKWebExtensionContext) -> Bool {
        tabManager?.isPrivate ?? false
    }

    func windowState(for context: WKWebExtensionContext) -> WKWebExtension.WindowState {
        guard let window else { return .normal }
        if window.isMiniaturized { return .minimized }
        if window.styleMask.contains(.fullScreen) { return .fullscreen }
        if window.isZoomed { return .maximized }
        return .normal
    }

    func setWindowState(_ state: WKWebExtension.WindowState, for context: WKWebExtensionContext) async throws {
        guard let window else { return }
        if window.isMiniaturized, state != .minimized { window.deminiaturize(nil) }
        if window.styleMask.contains(.fullScreen) != (state == .fullscreen) { window.toggleFullScreen(nil) }
        switch state {
        case .minimized: window.miniaturize(nil)
        case .maximized where !window.isZoomed, .normal where window.isZoomed: window.zoom(nil)
        default: break
        }
    }

    func screenFrame(for context: WKWebExtensionContext) -> CGRect {
        window?.screen?.frame ?? .null
    }

    func frame(for context: WKWebExtensionContext) -> CGRect {
        window?.frame ?? .null
    }

    func setFrame(_ frame: CGRect, for context: WKWebExtensionContext) async throws {
        window?.setFrame(frame, display: true, animate: true)
    }

    func focus(for context: WKWebExtensionContext) async throws {
        window?.makeKeyAndOrderFront(nil)
    }

    func close(for context: WKWebExtensionContext) async throws {
        window?.performClose(nil)
    }
}

/// An object held without keeping it alive.
struct Weak<Value: AnyObject> {
    weak var value: Value?

    init(_ value: Value) {
        self.value = value
    }
}
