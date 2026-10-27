import AppKit
import SwiftUI

/// Arc's Little Arc: a page in a small window of its own, for links from
/// other apps (when Settings says so) and for ⌥⌘N. Open in Cove moves the
/// live tab, page and history, into the browser window that was active last.
@MainActor
final class LittleCove {
    private unowned let appServices: AppServices
    /// Each open window and its tab. A window leaves when it closes or its
    /// tab moves into Cove.
    private var windows: [LittleCoveWindow] = []

    init(appServices: AppServices) {
        self.appServices = appServices
    }

    /// A new window holding the page, or the start page for none.
    func open(_ url: URL?) {
        let tab = TabSession(
            initialURL: url?.absoluteString,
            showsStartPage: url == nil,
            settings: appServices.settingsStore,
            services: appServices.tabSessionServices(in: appServices.browsingContext)
        )
        let window = LittleCoveWindow(tab: tab, appServices: appServices) { [weak self] window in
            self?.windows.removeAll { $0 === window }
        } onOpenInCove: { [weak self] tab in
            self?.appServices.externalURLRouter.moveToBrowserWindow(tab)
        }
        tab.host = TabSession.Host(
            select: { [weak window] in window?.show() },
            // A page asking for a new window goes to Cove, like a link from
            // another app would.
            openInNewTab: { [weak self] request in
                guard let url = request.url else { return }
                self?.appServices.externalURLRouter.open([url], from: .cove)
            }
        )
        windows.append(window)
        window.show()
    }
}

/// One Little Cove window: compact, cascaded from the last, with the page in
/// a card under a bar of its own.
@MainActor
private final class LittleCoveWindow: NSObject, NSWindowDelegate {
    private static let size = CGSize(width: 760, height: 600)
    private static var cascadePoint = CGPoint.zero

    private let tab: TabSession
    private let window: NSWindow
    private let onClose: (LittleCoveWindow) -> Void

    init(
        tab: TabSession,
        appServices: AppServices,
        onClose: @escaping (LittleCoveWindow) -> Void,
        onOpenInCove: @escaping (TabSession) -> Void
    ) {
        self.tab = tab
        self.onClose = onClose
        window = NSWindow(
            contentRect: CGRect(origin: .zero, size: Self.size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        super.init()

        window.isReleasedWhenClosed = false
        window.minSize = CGSize(width: 480, height: 360)
        window.delegate = self
        window.contentView = NSHostingView(rootView: LittleCoveView(tab: tab, appServices: appServices) { [unowned self] in
            // The window goes first, then the tab moves, so nothing here
            // is left holding the page.
            window.delegate = nil
            window.close()
            onClose(self)
            onOpenInCove(tab)
        })
        window.center()
        Self.cascadePoint = window.cascadeTopLeft(from: Self.cascadePoint)
    }

    func show() {
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        tab.close()
        onClose(self)
    }
}
