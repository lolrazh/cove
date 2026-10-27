import AppKit
import WebKit

/// A live web clipping: the captured region of a page, showing the page as
/// it is now. A small web view loads the page at the width its viewport had
/// when captured, zoomed so that region fills the item, and scrolled to it;
/// the item crops the rest. The capture's snapshot shows until the page has
/// loaded, and stays if it can't.
///
/// It's only as faithful as the page is stable. A page laid out differently
/// at another height, or for a signed-out visitor, or that moves content
/// after it loads (feeds, ads, lazy images), shows something else in the
/// region. Pages that scroll inside an element rather than the document
/// can't be scrolled to the region. It browses with the space's profile, so
/// signed-in pages stay signed in, but without extensions: a clipping is a
/// view of a page, not a tab. It doesn't take clicks; the canvas does.
final class EaselClipView: NSView {
    private let source: CaptureSource
    private let snapshot = NSImageView()
    private let webView: WKWebView
    private var navigation: Navigation?

    init(source: CaptureSource, snapshot image: NSImage?, dataStore: WKWebsiteDataStore) {
        self.source = source
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = dataStore
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = true

        snapshot.image = image
        snapshot.imageScaling = .scaleAxesIndependently
        addSubview(snapshot)
        webView.isHidden = true
        addSubview(webView)
        let navigation = Navigation { [weak self] in self?.reveal() }
        webView.navigationDelegate = navigation
        self.navigation = navigation
        refresh()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Loads the page again.
    func refresh() {
        webView.load(URLRequest(url: source.url))
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override var isFlipped: Bool { true }

    /// The page at its captured width, zoomed so the region fills the item,
    /// shifted left past the region's left edge.
    override func layout() {
        super.layout()
        snapshot.frame = bounds
        let scale = bounds.width / max(source.rect.width, 1)
        webView.pageZoom = scale
        webView.frame = CGRect(
            x: -source.rect.minX * scale,
            y: 0,
            width: source.viewportWidth * scale,
            height: bounds.height
        )
    }

    /// Scrolls to the region once the page is in, and again a moment later
    /// for pages that lay themselves out late.
    private func reveal() {
        let scroll = "scrollTo(0, \(source.rect.minY))"
        webView.evaluateJavaScript(scroll)
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(800))
            guard let self else { return }
            _ = try? await webView.evaluateJavaScript(scroll)
            webView.isHidden = false
        }
    }

    private final class Navigation: NSObject, WKNavigationDelegate {
        private let didFinish: @MainActor () -> Void

        init(didFinish: @escaping @MainActor () -> Void) {
            self.didFinish = didFinish
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            MainActor.assumeIsolated { didFinish() }
        }
    }
}
