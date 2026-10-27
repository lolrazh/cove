import Foundation
import Testing
@testable import Cove

struct SiteTests {
    @Test func `a site drops www and covers its subdomains`() throws {
        let site = try #require(Site(URL(string: "https://www.Example.com/page")))
        #expect(site.domain == "example.com")
        #expect(site.contains("example.com"))
        #expect(site.contains("www.example.com"))
        #expect(site.contains("news.example.com"))
        #expect(!site.contains("badexample.com"))
        #expect(!site.contains("example.org"))
    }

    @Test func `a subdomain doesn't cover its parent`() {
        let site = Site(domain: "news.example.com")
        #expect(!site.contains("example.com"))
        #expect(site.contains("a.news.example.com"))
    }

    @Test func `pages without a host have no site`() {
        #expect(Site(URL(string: "file:///Users/me/page.html")) == nil)
        #expect(Site(nil) == nil)
    }

    @Test func `an origin from a URL leaves out the default port`() throws {
        let origin = try #require(SitePermissions.Origin(URL(string: "https://Example.com:443/a")!))
        #expect(origin == SitePermissions.Origin(scheme: "https", host: "example.com", port: 0))
        #expect(origin == SitePermissions.Origin(scheme: "https", host: "example.com", port: nil))
        #expect(origin != SitePermissions.Origin(scheme: "http", host: "example.com", port: nil))
        #expect(SitePermissions.Origin(URL(string: "http://localhost:8080")!)?.port == 8080)
    }

    @MainActor
    @Test func `a forgotten answer asks again`() async {
        let permissions = SitePermissions()
        let origin = SitePermissions.Origin(scheme: "https", host: "example.com", port: nil)
        permissions.setAnswer(true, for: .camera, at: origin)
        #expect(permissions.answer(for: .camera, at: origin) == true)
        #expect(permissions.answer(for: .microphone, at: origin) == nil)

        permissions.setAnswer(nil, for: .camera, at: origin)
        #expect(permissions.answer(for: .camera, at: origin) == nil)
    }
}
