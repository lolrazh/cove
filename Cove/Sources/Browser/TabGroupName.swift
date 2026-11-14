import Foundation

/// A local label, with no page text or browsing data sent to a naming service.
/// Manual names live on the group and take precedence over this fallback.
enum TabGroupName {
    static func title(for pages: [(title: String, url: String)]) -> String {
        let titles = pages.map { clean($0.title) }.filter { !$0.isEmpty && $0 != "New Tab" }
        if let first = titles.first {
            let words = first.split(separator: " ").map(String.init)
            let shared = titles.dropFirst().reduce(words) { prefix, title in
                let other = title.split(separator: " ").map(String.init)
                return Array(zip(prefix, other).prefix { $0.caseInsensitiveCompare($1) == .orderedSame }.map(\.0))
            }
            let name = shared.count >= 2 ? shared.joined(separator: " ") : first
            return shortened(name)
        }
        if let host = pages.compactMap({ URL(string: $0.url)?.host }).first {
            return shortened(host.hasPrefix("www.") ? String(host.dropFirst(4)) : host)
        }
        return "Tab Group"
    }

    private static func clean(_ title: String) -> String {
        // Remove notification counts and common site suffixes, keeping the page topic.
        var name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.hasPrefix("("), let close = name.firstIndex(of: ")"),
           Int(name[name.index(after: name.startIndex)..<close]) != nil {
            name = String(name[name.index(after: close)...]).trimmingCharacters(in: .whitespaces)
        }
        for separator in [" | ", " — ", " – ", " - ", " · "] {
            if let range = name.range(of: separator) {
                name = String(name[..<range.lowerBound])
            }
        }
        return name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func shortened(_ title: String) -> String {
        guard title.count > 48 else { return title }
        let prefix = String(title.prefix(48))
        if let space = prefix.lastIndex(of: " "), prefix.distance(from: prefix.startIndex, to: space) >= 24 {
            return String(prefix[..<space]) + "…"
        }
        return prefix + "…"
    }
}
