import SwiftUI
import WebKit

struct WebViewRepresentable: NSViewRepresentable {
    let webView: WKWebView
    let onAppear: (NSWindow?) -> Void

    func makeNSView(context: Context) -> WebPageContainer {
        let container = WebPageContainer()
        container.show(webView, onAppear: onAppear)
        return container
    }

    func updateNSView(_ container: WebPageContainer, context: Context) {
        container.show(webView, onAppear: onAppear)
    }

    static func dismantleNSView(_ container: WebPageContainer, coordinator: ()) {
        container.reset()
    }
}

/// One live page. Selection changes the child view synchronously; network
/// loading and decorative animation never delay ownership or block input.
final class WebPageContainer: NSView {
    private(set) weak var page: WKWebView?
    private var requestedPage: WKWebView?
    private var onAppear: ((NSWindow?) -> Void)?
    private weak var notifiedPage: WKWebView?
    private weak var notifiedWindow: NSWindow?
    private var appearanceRevision = 0

    func show(_ incoming: WKWebView, onAppear: @escaping (NSWindow?) -> Void) {
        requestedPage = incoming
        self.onAppear = onAppear
        installIfReady()
    }

    override func layout() {
        super.layout()
        installIfReady()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { notifiedWindow = nil }
        installIfReady()
    }

    func installIfReady() {
        guard bounds.width > 0, bounds.height > 0, let incoming = requestedPage else { return }
        if incoming.frame != bounds { incoming.frame = bounds }
        if page !== incoming || incoming.superview !== self {
            incoming.autoresizingMask = [.width, .height]
            addSubview(incoming, positioned: .above, relativeTo: nil)
            subviews.filter { $0 !== incoming }.forEach { $0.removeFromSuperview() }
            page = incoming
            notifiedPage = nil
        }
        notifyIfReady()
    }

    func reset() {
        appearanceRevision += 1
        requestedPage = nil
        onAppear = nil
        page = nil
        notifiedPage = nil
        notifiedWindow = nil
        // A split or another host may already own the old page. Remove only
        // this host's children, never a page that has moved elsewhere.
        subviews.forEach { $0.removeFromSuperview() }
    }

    private func notifyIfReady() {
        guard let page, page.superview === self, let window,
              notifiedPage !== page || notifiedWindow !== window else { return }
        notifiedPage = page
        notifiedWindow = window
        appearanceRevision += 1
        let revision = appearanceRevision
        // Focus must wait until SwiftUI has finished updating the view tree.
        DispatchQueue.main.async { [weak self, weak page, weak window] in
            guard let self, let page, let window, appearanceRevision == revision,
                  self.window === window, requestedPage === page, page.superview === self else { return }
            if window.isKeyWindow { window.makeFirstResponder(page) }
            onAppear?(window)
        }
    }
}
