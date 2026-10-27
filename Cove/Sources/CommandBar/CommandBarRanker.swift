import Foundation

/// Turns typed input and the available sources into the grouped, ordered rows
/// the Command Bar shows. Pure: no UI, no stores, so it can be tested directly.
struct CommandBarRanker {
    struct OpenTab {
        let id: UUID
        let title: String
        let url: String
    }

    /// Another space, offered as "Switch to" its name.
    struct OtherSpace {
        let id: UUID
        let name: String
    }

    struct Sources {
        var tabs: [OpenTab] = []
        var spaces: [OtherSpace] = []
        var archive: [ArchivedTab] = []
        var history: [HistoryPage] = []
        var suggestions: [String] = []
        var commands: [CommandBarCommand] = []
    }

    struct Ranking {
        let sections: [CommandBarSection]
        /// The field's inline completion: the input extended to the host or
        /// URL of the best history match, or nil when nothing should be filled in.
        let completion: String?

        var results: [CommandBarResult] { sections.flatMap(\.results) }
    }

    private enum Limit {
        static let tabs = 3
        static let archive = 3
        static let history = 5
        static let recent = 6
        static let suggestions = 4
        static let commands = 3
    }

    private let requestBuilder = NavigationRequestBuilder()

    func rank(query: String, sources: Sources) -> Ranking {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return rankEmpty(sources) }

        let match = QueryMatch(trimmed)
        let completion = completion(for: query, match: match, sources: sources)
        let topHits = [completion?.result, primaryResult(for: trimmed)].compactMap { $0 }
        // A page is listed once: as a top hit, an open tab, an archived tab or
        // a page from history, in that order of preference.
        let shown = Set(topHits.map(\.destination))
        let openURLs = shown.union(sources.tabs.map(\.url))

        let tabs = sources.tabs
            .filter { !shown.contains($0.url) }
            .compactMap { tab in match.quality(title: tab.title, url: tab.url).map { ($0, tab) } }
            .sorted { $0.0 > $1.0 }
            .prefix(Limit.tabs)
            .map { CommandBarResult(kind: .tab($1.id), title: $1.title, destination: $1.url) }

        let archived = sources.archive
            .filter { !openURLs.contains($0.url) }
            .compactMap { tab in match.quality(title: tab.title, url: tab.url).map { ($0, tab) } }
            .sorted { ($0.0, $0.1.archivedAt) > ($1.0, $1.1.archivedAt) }
            .prefix(Limit.archive)
            .map { Self.archivedResult($1) }
        let listedURLs = openURLs.union(archived.map(\.destination))

        let history = sources.history
            .filter { !listedURLs.contains($0.url) }
            .compactMap { page in match.quality(title: page.title, url: page.url).map { ($0, page) } }
            .sorted { ($0.0, $0.1.frecency) > ($1.0, $1.1.frecency) }
            .prefix(Limit.history)
            .map { Self.historyResult($1) }

        let suggestions = sources.suggestions
            .filter { $0.caseInsensitiveCompare(trimmed) != .orderedSame }
            .prefix(Limit.suggestions)
            .map { CommandBarResult(kind: .suggestion, title: $0, destination: $0) }

        let commands = sources.spaces.map(Self.spaceResult).filter { match.matches(title: $0.title, keywords: ["space"]) }
            + sources.commands
            .filter { match.matches(title: $0.title, keywords: $0.keywords) }
            .prefix(Limit.commands)
            .map(Self.commandResult)

        let sections = [
            CommandBarSection(title: nil, results: topHits),
            CommandBarSection(title: "Switch to Tab", results: tabs),
            CommandBarSection(title: "Archive", results: archived),
            CommandBarSection(title: "History", results: history),
            CommandBarSection(title: "Commands", results: commands),
            CommandBarSection(title: "Suggestions", results: suggestions),
        ]
        return Ranking(sections: sections.filter { !$0.results.isEmpty }, completion: completion?.text)
    }

    /// With nothing typed: recent pages to jump back to, and every command.
    private func rankEmpty(_ sources: Sources) -> Ranking {
        let recent = sources.history.prefix(Limit.recent).map(Self.historyResult)
        let commands = sources.commands.map(Self.commandResult) + sources.spaces.map(Self.spaceResult)
        let sections = [
            CommandBarSection(title: "Recent", results: Array(recent)),
            CommandBarSection(title: "Commands", results: commands),
        ]
        return Ranking(sections: sections.filter { !$0.results.isEmpty }, completion: nil)
    }

    /// What Return does with the raw input: open it as an address, or search for it.
    private func primaryResult(for input: String) -> CommandBarResult {
        switch requestBuilder.destination(for: input) {
        case .url(let url):
            let destination = url.absoluteString
            return CommandBarResult(kind: .url, title: CommandBarResult.displayURL(for: destination), destination: destination)
        case .search, nil:
            return CommandBarResult(kind: .search, title: input, destination: input)
        }
    }

    // MARK: - Completion

    private struct Completion {
        let text: String
        /// What Return opens: the page the completed text names, so the field
        /// and the top hit always agree.
        let result: CommandBarResult
    }

    /// Safari-style: a single word that starts a visited site's address fills in
    /// the rest of the host, or the rest of the URL once a path has been typed.
    /// The pages come in frecency order, so the first fit decides.
    private func completion(for query: String, match: QueryMatch, sources: Sources) -> Completion? {
        guard match.tokens.count == 1, !query.hasSuffix(" ") else { return nil }
        let typed = CommandBarResult.displayURL(for: query.lowercased())
        guard !typed.isEmpty else { return nil }

        for page in sources.history {
            let display = CommandBarResult.displayURL(for: page.url)
            guard display.lowercased().hasPrefix(typed) else { continue }

            var target = display
            if !typed.contains("/"), let slash = display.firstIndex(of: "/") {
                target = String(display[..<slash])
            }
            guard target.count > typed.count else { return nil }
            let text = query + target.dropFirst(typed.count)

            // The page the completed text names: an open tab beats a visited
            // page, which beats a bare address.
            func names(_ url: String) -> Bool {
                CommandBarResult.displayURL(for: url).caseInsensitiveCompare(target) == .orderedSame
            }
            let result: CommandBarResult
            if let tab = sources.tabs.first(where: { names($0.url) }) {
                result = CommandBarResult(kind: .tab(tab.id), title: tab.title, destination: tab.url)
            } else if let page = sources.history.first(where: { names($0.url) }) {
                result = Self.historyResult(page)
            } else if case .url(let url) = requestBuilder.destination(for: text) {
                result = CommandBarResult(kind: .url, title: target, destination: url.absoluteString)
            } else {
                return nil
            }
            return Completion(text: text, result: result)
        }
        return nil
    }

    // MARK: - Rows

    private static func historyResult(_ page: HistoryPage) -> CommandBarResult {
        CommandBarResult(kind: .history, title: pageTitle(page.title, url: page.url), destination: page.url)
    }

    private static func archivedResult(_ tab: ArchivedTab) -> CommandBarResult {
        CommandBarResult(kind: .archived(tab.id), title: pageTitle(tab.title, url: tab.url), destination: tab.url)
    }

    /// A page without a title goes by its address.
    private static func pageTitle(_ title: String, url: String) -> String {
        title.isEmpty ? CommandBarResult.displayURL(for: url) : title
    }

    private static func commandResult(_ command: CommandBarCommand) -> CommandBarResult {
        CommandBarResult(kind: .command(command), title: command.title, destination: "")
    }

    private static func spaceResult(_ space: OtherSpace) -> CommandBarResult {
        CommandBarResult(kind: .space(space.id), title: "Switch to \(space.name)", destination: "")
    }
}

/// The typed words, and how well a page or command answers them. The Library
/// filters its archive the same way.
struct QueryMatch {
    let text: String
    let tokens: [String]

    /// Words are compared the way addresses are shown, so a pasted
    /// "https://www.github.com/" still finds GitHub.
    init(_ query: String) {
        text = CommandBarResult.displayURL(for: query.lowercased())
        tokens = text.split(whereSeparator: \.isWhitespace)
            .map { CommandBarResult.displayURL(for: String($0)) }
            .filter { !$0.isEmpty }
    }

    /// Nil when some word is missing. Otherwise higher is better: the address
    /// starting with the input beats a title word starting with it, which beats
    /// the words merely appearing somewhere.
    func quality(title: String, url: String) -> Int? {
        let title = title.lowercased()
        let address = CommandBarResult.displayURL(for: url).lowercased()
        guard let first = tokens.first,
              tokens.allSatisfy({ title.contains($0) || address.contains($0) }) else { return nil }

        if address.hasPrefix(text) { return 3 }
        if Self.words(of: title).contains(where: { $0.hasPrefix(first) }) { return 2 }
        return 1
    }

    /// Every typed word must start a word of a command's title or keywords.
    func matches(title: String, keywords: [String]) -> Bool {
        let words = Self.words(of: title.lowercased()) + keywords
        return tokens.allSatisfy { token in words.contains { $0.hasPrefix(token) } }
    }

    private static func words(of text: String) -> [String] {
        text.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }
}
