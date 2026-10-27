import Foundation

/// A website as per-site settings see it: a host without "www.", standing for
/// every host under it, so example.com includes news.example.com.
struct Site: Hashable {
    let domain: String

    init(domain: String) {
        let domain = domain.lowercased()
        self.domain = domain.hasPrefix("www.") ? String(domain.dropFirst(4)) : domain
    }

    /// The page's site, or nil for a page without a host, like a file.
    init?(_ url: URL?) {
        guard let host = url?.host(), !host.isEmpty else { return nil }
        self.init(domain: host)
    }

    func contains(_ host: String) -> Bool {
        let host = Site(domain: host).domain
        return host == domain || host.hasSuffix("." + domain)
    }
}
