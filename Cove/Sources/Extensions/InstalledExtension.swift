import Foundation
import WebKit

/// An extension the user added, as kept between launches. Its files live in
/// the library's folder; what it is and what it asks for come from its
/// manifest when it loads. What the user allowed or refused is kept here,
/// for every profile alike.
struct InstalledExtension: Codable, Identifiable, Hashable {
    let id: UUID
    /// Its files in the library's folder: a folder, or a zip archive.
    let fileName: String
    /// Its name when it was added, for when it can't be loaded.
    var name: String
    var isEnabled = true
    /// Whether it runs in private windows too. Off until the user says so,
    /// as in Safari and Chrome.
    var allowsPrivateBrowsing = false
    var granted = ExtensionGrants()
    var denied = ExtensionGrants()
}

/// Permissions and sites, each with the date it lapses: the same shape as
/// `WKWebExtensionContext`'s granted and denied lists, by name and pattern.
struct ExtensionGrants: Codable, Hashable {
    var permissions: [String: Date] = [:]
    /// Match patterns like `*://*.example.com/*`.
    var sites: [String: Date] = [:]
}

extension InstalledExtension {
    /// Allows or refuses a permission, as Settings' switches do. Either way
    /// it isn't asked about again.
    mutating func allow(permission: String, _ isAllowed: Bool) {
        granted.permissions[permission] = isAllowed ? .distantFuture : nil
        denied.permissions[permission] = isAllowed ? nil : .distantFuture
    }

    /// Allows or refuses a site, by match pattern.
    mutating func allow(site pattern: String, _ isAllowed: Bool) {
        granted.sites[pattern] = isAllowed ? .distantFuture : nil
        denied.sites[pattern] = isAllowed ? nil : .distantFuture
    }
}

// MARK: - WebKit's terms

@MainActor
extension ExtensionGrants {
    init(permissions: [WKWebExtension.Permission: Date], sites: [WKWebExtension.MatchPattern: Date]) {
        self.permissions = Dictionary(permissions.map { ($0.key.rawValue, $0.value) }, uniquingKeysWith: max)
        self.sites = Dictionary(sites.map { ($0.key.string, $0.value) }, uniquingKeysWith: max)
    }

    /// Everything an extension asks for when it's added: its permissions,
    /// and the sites its manifest names, content scripts' included.
    init(requestedBy webExtension: WKWebExtension) {
        self.init(
            permissions: Dictionary(uniqueKeysWithValues: webExtension.requestedPermissions.map { ($0, .distantFuture) }),
            sites: Dictionary(uniqueKeysWithValues: webExtension.allRequestedMatchPatterns.map { ($0, .distantFuture) })
        )
    }

    var webKitPermissions: [WKWebExtension.Permission: Date] {
        Dictionary(permissions.map { (WKWebExtension.Permission(rawValue: $0.key), $0.value) }, uniquingKeysWith: max)
    }

    /// Patterns WebKit no longer reads are left out.
    var webKitSites: [WKWebExtension.MatchPattern: Date] {
        Dictionary(sites.compactMap { pattern, date in (try? WKWebExtension.MatchPattern(string: pattern)).map { ($0, date) } }, uniquingKeysWith: max)
    }
}
