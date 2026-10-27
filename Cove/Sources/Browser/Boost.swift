import Foundation

/// Arc's Boosts: the user's own touches for a site. Simple ones (a color
/// tint, a font, elements hidden) and, under them, CSS and JavaScript of
/// their own. Boosts are global, like Arc's: every window applies them.
struct Boost: Codable, Identifiable, Hashable {
    /// A few of the fonts every Mac has, for pages that read better in them.
    enum Font: String, Codable, CaseIterable {
        case system, rounded, serif, avenir, monospaced

        var name: String {
            switch self {
            case .system: "System"
            case .rounded: "Rounded"
            case .serif: "New York"
            case .avenir: "Avenir Next"
            case .monospaced: "Monospaced"
            }
        }

        var family: String {
            switch self {
            case .system: "system-ui, -apple-system"
            case .rounded: "ui-rounded, system-ui"
            case .serif: "ui-serif, \"New York\", Georgia, serif"
            case .avenir: "\"Avenir Next\", Avenir, system-ui"
            case .monospaced: "ui-monospace, \"SF Mono\", Menlo, monospace"
            }
        }
    }

    var id = UUID()
    /// The site, as `Site` writes it: a host without "www.".
    var domain: String
    var includesSubdomains = true
    var isEnabled = true
    /// A tint laid over the page, as "#RRGGBB".
    var tint: String?
    var font: Font?
    /// Selectors for elements to hide, as zapping adds them.
    var hiddenElements: [String] = []
    var css = ""
    var script = ""

    init(site: Site) {
        domain = site.domain
    }

    /// Whether the Boost is for the host's site, on or off.
    func covers(_ host: String) -> Bool {
        let site = Site(domain: domain)
        return includesSubdomains ? site.contains(host) : Site(domain: host) == site
    }

    /// Whether the Boost changes the page at the URL.
    func applies(to url: URL?) -> Bool {
        guard isEnabled, let host = url?.host(), !host.isEmpty else { return false }
        return covers(host)
    }

    /// A Boost that changes nothing, which isn't worth keeping.
    var isEmpty: Bool {
        tint == nil && font == nil && hiddenElements.isEmpty
            && css.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasScript: Bool {
        !script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The Boost's styles: the simple controls first, then the user's CSS, so
    /// their own rules have the last word.
    var stylesheet: String {
        var rules: [String] = []
        if let tint {
            // A wash over everything, colored by the tint but keeping the
            // page's light and dark. It lets clicks through.
            rules.append("""
            html::after { content: ""; position: fixed; inset: 0; z-index: 2147483647; \
            pointer-events: none; background: \(tint); mix-blend-mode: color; opacity: 0.6; }
            """)
        }
        if let font {
            // Icon fonts and code keep theirs.
            rules.append("""
            body, body :not(pre, code, kbd, samp, i, svg *, [class*="icon" i], [class*="symbol" i]) \
            { font-family: \(font.family) !important; }
            """)
        }
        // One rule each: a selector the browser can't parse would void a
        // whole list.
        rules += hiddenElements.map { "\($0) { display: none !important; }" }
        if !css.isEmpty { rules.append(css) }
        return rules.joined(separator: "\n")
    }
}

extension [Boost] {
    /// The Boosts that change the page at the URL, a parent site's first.
    func applying(to url: URL?) -> [Boost] {
        filter { $0.applies(to: url) }.sorted { $0.domain.count < $1.domain.count }
    }

    /// The styles of several Boosts for one page, a parent site's before a
    /// subdomain's, which is more specific.
    var stylesheet: String {
        map(\.stylesheet).filter { !$0.isEmpty }.joined(separator: "\n")
    }
}
