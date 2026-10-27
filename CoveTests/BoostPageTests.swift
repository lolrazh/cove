import Foundation
import Testing
import WebKit
@testable import Cove

/// Boosts in a real web view: styles reach the page, follow changes live, and
/// zapping's selectors find the element they were made for.
@MainActor
struct BoostPageTests {
    private let url = URL(string: "https://example.com/")!

    /// Waits for a web view's page to finish loading.
    private final class Loader: NSObject, WKNavigationDelegate {
        private var waiter: CheckedContinuation<Void, Never>?

        func load(_ html: String, at url: URL, in webView: WKWebView) async {
            webView.navigationDelegate = self
            await withCheckedContinuation { waiter in
                self.waiter = waiter
                webView.loadHTMLString(html, baseURL: url)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            waiter?.resume()
            waiter = nil
        }
    }

    private func evaluate(_ script: String, in webView: WKWebView) async throws -> String? {
        try await webView.callAsyncJavaScript(script, contentWorld: .page) as? String
    }

    @Test func `a Boost styles its site's pages and follows changes without a reload`() async throws {
        let store = BoostStore(fileURL: nil)
        let injector = BoostInjector(store: store)
        var boost = Boost(site: Site(url)!)
        boost.hiddenElements = ["#ad"]
        store.save(boost)

        let webView = WKWebView()
        let loader = Loader()
        injector.update(webView, for: url)
        await loader.load("<p id=ad>Ad</p><p id=text>Text</p>", at: url, in: webView)
        let display = "return getComputedStyle(document.getElementById('ad')).display"
        #expect(try await evaluate(display, in: webView) == "none")

        boost.hiddenElements = []
        boost.css = "#text { color: rgb(1, 2, 3); }"
        store.save(boost)
        try await Task.sleep(for: .milliseconds(100))
        #expect(try await evaluate(display, in: webView) == "block")
        #expect(try await evaluate("return getComputedStyle(document.getElementById('text')).color", in: webView) == "rgb(1, 2, 3)")
    }

    @Test func `another site's page goes without the Boost`() async throws {
        let store = BoostStore(fileURL: nil)
        var boost = Boost(site: Site(url)!)
        boost.css = "p { display: none; }"
        store.save(boost)

        let other = URL(string: "https://example.org/")!
        let webView = WKWebView()
        BoostInjector(store: store).update(webView, for: other)
        await Loader().load("<p id=text>Text</p>", at: other, in: webView)
        #expect(try await evaluate("return getComputedStyle(document.getElementById('text')).display", in: webView) == "block")
    }

    @Test func `zapping picks a selector that finds the element alone`() async throws {
        let webView = WKWebView()
        await Loader().load("""
        <div id="main">
          <ul class="list"><li>One</li><li class="item">Two</li><li class="item">Three</li></ul>
        </div>
        <section><p data-testid="promo">Promo</p></section>
        <aside id="sidebar-82731"><span class="x123456">Generated</span></aside>
        <button id="close">Close</button>
        """, at: url, in: webView)

        let cases = [
            "document.getElementById('close')": "#close",
            "document.querySelectorAll('.item')[1]": "li.item:nth-of-type(3)",
            "document.querySelector('[data-testid=promo]')": "p[data-testid=\"promo\"]",
            "document.querySelector('aside span')": "body > aside > span",
        ]
        for (element, expected) in cases {
            let selector = try await evaluate("return (\(BoostZap.selectorFunction))(\(element))", in: webView)
            #expect(selector == expected)
            let matches = try await evaluate("return String(document.querySelectorAll(\(Self.literal(selector ?? ""))).length)", in: webView)
            #expect(matches == "1")
        }
    }

    private static func literal(_ string: String) -> String {
        String(data: try! JSONEncoder().encode(string), encoding: .utf8)!
    }
}
