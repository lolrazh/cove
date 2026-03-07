import Foundation

struct NavigationRequestBuilder {
    func request(for input: String, searchEngine: SearchEngine) -> URLRequest? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let url: URL?
        if let directURL = directURL(for: trimmed) {
            url = directURL
        } else if looksLikeURL(trimmed) {
            if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
                url = URL(string: trimmed)
            } else {
                url = URL(string: "https://\(trimmed)")
            }
        } else {
            url = searchEngine.searchURL(for: trimmed)
        }

        guard let url else { return nil }
        return URLRequest(url: url)
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
