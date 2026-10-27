import Combine
import WebKit

/// Puts Boosts into pages: a style element for their CSS, and their scripts.
///
/// User scripts belong to a web view, not to a site, so each web view carries
/// only the Boosts for the page it's loading. They're swapped as each
/// main-frame navigation is decided, before the page loads, like content
/// blocking's exceptions. The alternative, every Boost in every page behind
/// a check of `location`, would hand each site every other site's code.
///
/// Everything runs in a content world of the Boosts' own, as Arc's ran as an
/// extension's content scripts. A script there shares the page's DOM, which
/// is what nearly every Boost changes, but not its JavaScript: the page can't
/// see it or interfere with it, and it can't reach the page's variables. A
/// Boost that needs those can add a `<script>` element to the page.
///
/// CSS changes reach open pages at once. A script runs when a page loads, so
/// a changed one waits for the next load.
@MainActor
final class BoostInjector {
    static let world = WKContentWorld.world(name: "Boosts")
    private static let styleID = "cove-boost"

    /// Sets the page's Boost styles, last in its head so they win ties with
    /// the page's own; an empty sheet removes them.
    private static let applyStyle = """
    (css) => {
        let style = document.getElementById("\(styleID)");
        if (!css) { style?.remove(); return; }
        if (!style) {
            style = document.createElement("style");
            style.id = "\(styleID)";
        }
        style.textContent = css;
        (document.head ?? document.documentElement).append(style);
    }
    """

    /// What a web view was last set up for.
    private final class Page {
        var url: URL?
        var boosts: [Boost] = []
        var scripts: [WKUserScript] = []
    }

    let store: BoostStore
    private let pages = NSMapTable<WKWebView, Page>.weakToStrongObjects()
    private var subscription: AnyCancellable?

    init(store: BoostStore) {
        self.store = store
        subscription = store.$boosts
            .dropFirst()
            .sink { [weak self] boosts in self?.refresh(with: boosts) }
    }

    /// Gives the web view the Boosts for the page it's about to load. Called
    /// as each main-frame navigation is decided, so the page loads with them.
    func update(_ webView: WKWebView, for url: URL?) {
        let page = pages.object(forKey: webView) ?? Page()
        pages.setObject(page, forKey: webView)
        page.url = url
        install(store.boosts.applying(to: url), for: page, in: webView)
    }

    /// The Boosts changed: every page gets them for its next load, and the
    /// pages on screen get their new styles now.
    private func refresh(with boosts: [Boost]) {
        for webView in pages.keyEnumerator().allObjects as? [WKWebView] ?? [] {
            guard let page = pages.object(forKey: webView) else { continue }
            let stylesheet = page.boosts.stylesheet
            install(boosts.applying(to: page.url), for: page, in: webView)
            if page.boosts.stylesheet != stylesheet {
                webView.callAsyncJavaScript(
                    "(\(Self.applyStyle))(css)",
                    arguments: ["css": page.boosts.stylesheet],
                    in: nil,
                    in: Self.world
                )
            }
        }
    }

    /// Swaps the web view's Boost scripts for the new Boosts'. A controller
    /// can only drop all its scripts at once, so the others go back in.
    private func install(_ boosts: [Boost], for page: Page, in webView: WKWebView) {
        guard boosts != page.boosts else { return }
        let controller = webView.configuration.userContentController
        let others = controller.userScripts.filter { script in !page.scripts.contains { $0 === script } }
        page.boosts = boosts
        page.scripts = Self.scripts(for: boosts)
        controller.removeAllUserScripts()
        (others + page.scripts).forEach(controller.addUserScript)
    }

    private static func scripts(for boosts: [Boost]) -> [WKUserScript] {
        var scripts: [WKUserScript] = []
        let stylesheet = boosts.stylesheet
        if !stylesheet.isEmpty {
            // Again once the head is parsed, to come after the page's styles.
            let css = literal(stylesheet)
            scripts.append(userScript("""
            (() => {
                const apply = \(applyStyle);
                apply(\(css));
                document.addEventListener("DOMContentLoaded", () => apply(\(css)), { once: true });
            })();
            """, at: .atDocumentStart))
        }
        for boost in boosts where boost.hasScript {
            // A function of its own, so two Boosts' declarations don't clash.
            scripts.append(userScript("(async () => {\n\(boost.script)\n})();", at: .atDocumentEnd))
        }
        return scripts
    }

    private static func userScript(_ source: String, at time: WKUserScriptInjectionTime) -> WKUserScript {
        WKUserScript(source: source, injectionTime: time, forMainFrameOnly: true, in: world)
    }

    /// The string as a JavaScript literal: JSON is a subset of JavaScript.
    private static func literal(_ string: String) -> String {
        (try? JSONEncoder().encode(string)).flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
    }
}
