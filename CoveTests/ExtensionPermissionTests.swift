import Foundation
import Testing
import WebKit
@testable import Cove

@MainActor
struct ExtensionPermissionTests {
    // MARK: - What the sheet says

    @Test func `any pattern covering every site is said as all websites`() {
        for pattern in ["<all_urls>", "*://*/*", "https://*/*"] {
            #expect(ExtensionPermissionRequest.siteLine([pattern, "*://*.example.com/*"]) == "Read and change your data on all websites")
        }
    }

    @Test func `sites are named by host, a few at a time`() {
        #expect(ExtensionPermissionRequest.siteLine([]) == nil)
        #expect(ExtensionPermissionRequest.siteLine(["*://*.github.com/*"]) == "Read and change your data on github.com")
        #expect(ExtensionPermissionRequest.siteLine(["https://b.com/*", "a.com"]) == "Read and change your data on a.com and b.com")
        #expect(
            ExtensionPermissionRequest.siteLine(["https://a.com/*", "https://b.com/*", "https://c.com/*", "http://d.com:8080/x"])
                == "Read and change your data on a.com, b.com and 2 other sites"
        )
    }

    @Test func `only permissions that reach beyond the extension are mentioned, sites first`() {
        let lines = ExtensionPermissionRequest.lines(permissions: ["storage", "tabs", "alarms", "cookies", "tabs"], sites: ["*://*/*"])
        #expect(lines == [
            "Read and change your data on all websites",
            "Read and change cookies on sites it can access",
            "See the addresses and titles of your tabs",
        ])
        #expect(ExtensionPermissionRequest.lines(permissions: ["storage"], sites: []).isEmpty)
    }

    // MARK: - What's kept

    @Test func `allowing and refusing move a permission between the lists`() {
        var record = InstalledExtension(id: UUID(), fileName: "a", name: "A")
        record.allow(permission: "tabs", true)
        record.allow(site: "*://*.example.com/*", true)
        #expect(record.granted.permissions["tabs"] != nil && record.denied.permissions.isEmpty)
        #expect(record.granted.sites["*://*.example.com/*"] != nil)

        record.allow(permission: "tabs", false)
        record.allow(site: "*://*.example.com/*", false)
        #expect(record.granted.permissions.isEmpty && record.denied.permissions["tabs"] != nil)
        #expect(record.granted.sites.isEmpty && record.denied.sites["*://*.example.com/*"] != nil)
    }

    @Test func `grants survive the trip through WebKit's types`() {
        let date = Date(timeIntervalSince1970: 2_000_000_000)
        let grants = ExtensionGrants(permissions: ["tabs": date, "storage": .distantFuture], sites: ["*://*.example.com/*": date])
        let back = ExtensionGrants(permissions: grants.webKitPermissions, sites: grants.webKitSites)
        #expect(back == grants)
    }

    @Test func `a pattern WebKit can't read is dropped rather than passed on`() {
        let grants = ExtensionGrants(sites: ["not a pattern": .distantFuture, "*://*.example.com/*": .distantFuture])
        #expect(grants.webKitSites.map(\.key.string) == ["*://*.example.com/*"])
    }
}
