import Foundation
import Testing
@testable import Cove

@MainActor
struct BoostTests {
    private let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CoveTests-\(UUID().uuidString)/boosts.json")

    private func boost(_ domain: String, _ change: (inout Boost) -> Void = { _ in }) -> Boost {
        var boost = Boost(site: Site(domain: domain))
        boost.css = "body { color: red; }"
        change(&boost)
        return boost
    }

    // MARK: - Matching

    @Test func `a Boost covers its site and, unless told otherwise, its subdomains`() {
        let wide = boost("www.example.com")
        #expect(wide.domain == "example.com")
        #expect(wide.applies(to: URL(string: "https://example.com/a")))
        #expect(wide.applies(to: URL(string: "https://www.example.com")))
        #expect(wide.applies(to: URL(string: "https://news.example.com")))
        #expect(!wide.applies(to: URL(string: "https://example.org")))
        #expect(!wide.applies(to: URL(string: "https://notexample.com")))

        let narrow = boost("example.com") { $0.includesSubdomains = false }
        #expect(narrow.applies(to: URL(string: "https://www.example.com")))
        #expect(!narrow.applies(to: URL(string: "https://news.example.com")))
    }

    @Test func `a Boost that's off, or a page without a host, changes nothing`() {
        let off = boost("example.com") { $0.isEnabled = false }
        #expect(off.covers("example.com"))
        #expect(!off.applies(to: URL(string: "https://example.com")))
        #expect(!boost("example.com").applies(to: URL(string: "file:///tmp/a.html")))
    }

    @Test func `a page gets every Boost that covers it, a parent site's first`() {
        let boosts = [boost("news.example.com"), boost("example.com"), boost("example.org")]
        let applied = boosts.applying(to: URL(string: "https://news.example.com"))
        #expect(applied.map(\.domain) == ["example.com", "news.example.com"])
    }

    // MARK: - Styles

    @Test func `the stylesheet puts the simple controls before the user's CSS`() {
        let boost = boost("example.com") {
            $0.tint = "#FF0000"
            $0.font = .serif
            $0.hiddenElements = ["#ad", "div.promo > a"]
        }
        let lines = boost.stylesheet.components(separatedBy: "\n")
        #expect(lines.contains { $0.contains("background: #FF0000") })
        #expect(lines.firstIndex { $0.contains("background: #FF0000") }! < lines.firstIndex { $0.contains("font-family") }!)
        #expect(lines.contains { $0.contains("font-family: ui-serif") })
        #expect(lines.contains("#ad { display: none !important; }"))
        #expect(lines.contains("div.promo > a { display: none !important; }"))
        #expect(lines.last == "body { color: red; }")
    }

    @Test func `a Boost with nothing in it is empty`() {
        #expect(Boost(site: Site(domain: "example.com")).isEmpty)
        #expect(boost("example.com") { $0.css = "  \n" }.isEmpty)
        #expect(!boost("example.com") { $0.css = ""; $0.hiddenElements = ["#ad"] }.isEmpty)
        #expect(Boost(site: Site(domain: "example.com")).stylesheet.isEmpty)
    }

    // MARK: - Store

    @Test func `Boosts come back from the file`() {
        let saved = boost("example.com") {
            $0.tint = "#0A84FF"
            $0.font = .rounded
            $0.script = "console.log(1)"
        }
        BoostStore(fileURL: fileURL).save(saved)
        #expect(BoostStore(fileURL: fileURL).boosts == [saved])
    }

    @Test func `saving replaces a Boost in place, and an emptied one is removed`() {
        let store = BoostStore(fileURL: fileURL)
        var first = boost("example.com")
        store.save(first)
        store.save(boost("example.org"))

        first.css = "p { margin: 0; }"
        store.save(first)
        #expect(store.boosts.map(\.css) == ["p { margin: 0; }", "body { color: red; }"])

        first.css = ""
        store.save(first)
        #expect(store.boosts.map(\.domain) == ["example.org"])
        #expect(BoostStore(fileURL: fileURL).boosts.map(\.domain) == ["example.org"])
    }

    @Test func `the editor opens the site's own Boost, else the nearest covering one`() {
        let store = BoostStore(fileURL: nil)
        store.save(boost("example.com"))
        store.save(boost("news.example.com") { $0.isEnabled = false })

        #expect(store.boost(for: Site(domain: "news.example.com"))?.domain == "news.example.com")
        #expect(store.boost(for: Site(domain: "shop.example.com"))?.domain == "example.com")
        #expect(store.boost(for: Site(domain: "example.org")) == nil)
    }
}
