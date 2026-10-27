import Foundation
import Testing
@testable import Cove

struct PageZoomTests {
    @Test func `zooming steps through the levels`() {
        #expect(PageZoom.zoomedIn(from: 1) == 1.15)
        #expect(PageZoom.zoomedOut(from: 1) == 0.85)
    }

    @Test func `a zoom between levels moves to the nearest one in that direction`() {
        #expect(PageZoom.zoomedIn(from: 1.2) == 1.25)
        #expect(PageZoom.zoomedOut(from: 1.2) == 1.15)
    }

    @Test func `zooming stops at either end`() {
        #expect(PageZoom.zoomedIn(from: 3) == nil)
        #expect(PageZoom.zoomedOut(from: 0.5) == nil)
    }

    @MainActor
    @Test func `sites keep their zoom and forget actual size`() throws {
        let defaults = try #require(UserDefaults(suiteName: "PageZoomTests"))
        defaults.removePersistentDomain(forName: "PageZoomTests")
        let page = URL(string: "https://example.com/a")
        let samePage = URL(string: "https://example.com/b")

        SiteZoomStore(defaults: defaults).setZoom(1.25, for: page)
        let reopened = SiteZoomStore(defaults: defaults)
        #expect(reopened.zoom(for: samePage) == 1.25)
        #expect(reopened.zoom(for: URL(string: "https://other.org")) == 1)

        reopened.setZoom(1, for: page)
        #expect(defaults.dictionary(forKey: "browser.siteZoom")?.isEmpty == true)
    }
}
