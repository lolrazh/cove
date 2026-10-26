import Foundation

/// Completions from the selected search engine. Best effort: offline, slow or
/// odd answers just mean no suggestions.
nonisolated struct SearchSuggestions {
    private let timeout: TimeInterval = 2

    func fetch(_ query: String, from engine: SearchEngine) async -> [String] {
        guard let url = engine.suggestionsURL(for: query) else { return [] }
        let request = URLRequest(url: url, timeoutInterval: timeout)

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let payload = try? JSONSerialization.jsonObject(with: data) as? [Any],
              payload.count >= 2,
              let completions = payload[1] as? [String] else {
            return []
        }
        return completions
    }
}
