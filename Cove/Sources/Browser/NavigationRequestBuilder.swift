import Foundation

/// What typed input resolves to: a page to load, or a query for the search engine.
enum NavigationDestination: Equatable {
    case url(URL)
    case search(String)
}

struct NavigationRequestBuilder {
    func request(for input: String, searchEngine: SearchEngine) -> URLRequest? {
        let url: URL? = switch destination(for: input) {
        case .url(let url): url
        case .search(let query): searchEngine.searchURL(for: query)
        case nil: nil
        }
        return url.map { URLRequest(url: $0) }
    }

    /// Classifies input the way the address bar does, without choosing an
    /// engine, so the Command Bar can show the same decision before Return.
    func destination(for input: String) -> NavigationDestination? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let directURL = directURL(for: trimmed) {
            return .url(directURL)
        }
        if looksLikeURL(trimmed) {
            let withScheme = trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://")
                ? trimmed
                : "https://\(trimmed)"
            if let url = URL(string: withScheme) {
                return .url(url)
            }
        }
        return .search(trimmed)
    }

    private func directURL(for input: String) -> URL? {
        guard !input.contains(" ") else { return nil }

        let hasDirectScheme = input.contains("://")
            || input.hasPrefix("about:")
            || input.hasPrefix("file:")
            || input.hasPrefix("data:")

        guard hasDirectScheme else { return nil }
        return URL(string: input)
    }

    private func looksLikeURL(_ input: String) -> Bool {
        if input.hasPrefix("http://") || input.hasPrefix("https://") { return true }
        if input.contains(" ") { return false }

        let host = input.split(separator: "/").first.map(String.init) ?? input
        let hostWithoutPort = host.split(separator: ":").first.map(String.init) ?? host

        if hostWithoutPort == "localhost" { return true }

        let parts = hostWithoutPort.split(separator: ".")
        if parts.count == 4 && parts.allSatisfy({ $0.allSatisfy(\.isNumber) }) { return true }
        if input.hasPrefix("[") { return true }

        if parts.count >= 2, let tld = parts.last, tld.count >= 2, tld.allSatisfy(\.isLetter) {
            return true
        }

        return false
    }
}
