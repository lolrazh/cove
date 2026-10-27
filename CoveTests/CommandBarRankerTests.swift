import Foundation
import Testing
@testable import Cove

struct CommandBarRankerTests {
    private let ranker = CommandBarRanker()

    private let github = HistoryPage(url: "https://github.com/", title: "GitHub", frecency: 5)
    private let swiftRepo = HistoryPage(url: "https://github.com/swiftlang/swift", title: "swiftlang/swift", frecency: 9)
    private let swiftDocs = HistoryPage(url: "https://www.swift.org/documentation/", title: "Documentation", frecency: 2)

    private func rank(_ query: String, _ sources: CommandBarRanker.Sources) -> CommandBarRanker.Ranking {
        ranker.rank(query: query, sources: sources)
    }

    @Test func `empty input lists recent pages and every command`() {
        let ranking = rank("", .init(history: [github], commands: [.settings, .showHistory]))
        #expect(ranking.sections.map(\.title) == ["Recent", "Commands"])
        #expect(ranking.results.count == 3)
        #expect(ranking.completion == nil)
    }

    @Test func `a search query puts the search row first`() throws {
        let ranking = rank("swift concurrency", .init())
        let first = try #require(ranking.results.first)
        #expect(first.kind == .search)
        #expect(first.destination == "swift concurrency")
    }

    @Test func `an address puts the URL row first`() throws {
        let ranking = rank("example.com/path", .init())
        let first = try #require(ranking.results.first)
        #expect(first.kind == .url)
        #expect(first.destination == "https://example.com/path")
    }

    @Test func `history completes to the host and the top hit is that site`() {
        // The deeper page is more frecent, but a bare prefix completes to the host.
        let ranking = rank("gi", .init(history: [swiftRepo, github]))
        #expect(ranking.completion == "github.com")
        #expect(ranking.results.first?.destination == "https://github.com/")
        // The completed page isn't listed twice.
        let history = ranking.sections.first { $0.title == "History" }?.results ?? []
        #expect(history.map(\.destination) == [swiftRepo.url])
    }

    @Test func `a typed path completes to the full URL`() {
        let ranking = rank("github.com/sw", .init(history: [swiftRepo, github]))
        #expect(ranking.completion == "github.com/swiftlang/swift")
        #expect(ranking.results.first?.destination == swiftRepo.url)
    }

    @Test func `a host with no exact page completes to its address`() {
        let ranking = rank("sw", .init(history: [swiftRepo, swiftDocs]))
        #expect(ranking.completion == "swift.org")
        #expect(ranking.results.first?.kind == .url)
        #expect(ranking.results.first?.destination == "https://swift.org")
    }

    @Test func `a completed site that is already open switches to its tab`() {
        let tab = CommandBarRanker.OpenTab(id: UUID(), title: "GitHub", url: github.url)
        let ranking = rank("gi", .init(tabs: [tab], history: [github]))
        #expect(ranking.completion == "github.com")
        #expect(ranking.results.first?.kind == .tab(tab.id))
        #expect(ranking.sections.map(\.title) == [nil])
    }

    @Test(arguments: ["gi ", "git hub", "hub"])
    func `nothing is completed for multiple words, a trailing space, or a mid-word match`(query: String) {
        #expect(rank(query, .init(history: [github])).completion == nil)
    }

    @Test func `open tabs beat history for the same page`() {
        let tab = CommandBarRanker.OpenTab(id: UUID(), title: swiftRepo.title, url: swiftRepo.url)
        let ranking = rank("swift", .init(tabs: [tab], history: [swiftRepo, swiftDocs]))
        #expect(ranking.sections.map(\.title) == [nil, "Switch to Tab", "History"])
        let history = ranking.sections.last?.results ?? []
        #expect(history.map(\.destination) == [swiftDocs.url])
    }

    @Test func `archived tabs get their own group and aren't repeated from history`() {
        let archived = ArchivedTab(id: UUID(), url: swiftRepo.url, title: swiftRepo.title, archivedAt: .now, reason: .idle)
        let ranking = rank("swift", .init(archive: [archived], history: [swiftRepo, swiftDocs]))
        #expect(ranking.sections.map(\.title) == [nil, "Archive", "History"])
        #expect(ranking.sections[1].results.map(\.kind) == [.archived(archived.id)])
        #expect(ranking.sections[2].results.map(\.destination) == [swiftDocs.url])
    }

    @Test func `an open tab beats the archive for the same page`() {
        let tab = CommandBarRanker.OpenTab(id: UUID(), title: swiftRepo.title, url: swiftRepo.url)
        let archived = ArchivedTab(id: UUID(), url: swiftRepo.url, title: swiftRepo.title, archivedAt: .now, reason: .idle)
        let ranking = rank("swift", .init(tabs: [tab], archive: [archived]))
        #expect(ranking.sections.map(\.title) == [nil, "Switch to Tab"])
    }

    @Test func `a pasted address matches history despite its scheme`() {
        let ranking = rank("https://www.github.com/", .init(history: [swiftRepo]))
        let history = ranking.sections.first { $0.title == "History" }?.results ?? []
        #expect(history.map(\.destination) == [swiftRepo.url])
    }

    @Test func `commands match on any word of the title or a keyword`() {
        let sources = CommandBarRanker.Sources(commands: CommandBarCommand.allCases)
        #expect(rank("side", sources).results.contains { $0.kind == .command(.showTabsInSidebar) })
        #expect(rank("pref", sources).results.contains { $0.kind == .command(.settings) })
        #expect(!rank("xyz", sources).results.contains { if case .command = $0.kind { true } else { false } })
    }

    @Test(arguments: [
        ("site settings", CommandBarCommand.siteSettings),
        ("boost", .boostSite),
        ("Settings", .settings),
        ("sett", .settings),
        ("history", .showHistory),
    ])
    func `a command the input names is the top hit`(query: String, command: CommandBarCommand) throws {
        let ranking = rank(query, .init(history: [github], commands: CommandBarCommand.allCases))
        #expect(ranking.results.first?.kind == .command(command))
        #expect(ranking.results.dropFirst().first?.kind == .search)
        #expect(ranking.results.filter { $0.kind == .command(command) }.count == 1)
    }

    @Test func `spaces and extensions lead when named too`() {
        let work = CommandBarRanker.OtherSpace(id: UUID(), name: "Work")
        let action = CommandBarRanker.ExtensionAction(id: "dark", name: "Dark Reader")
        let sources = CommandBarRanker.Sources(spaces: [work], extensionActions: [action])
        #expect(rank("work", sources).results.first?.kind == .space(work.id))
        #expect(rank("dark re", sources).results.first?.kind == .extensionAction("dark"))
    }

    @Test(arguments: ["se", "sit set", "settings for safari", "pref"])
    func `input that only touches a command still searches first`(query: String) {
        let ranking = rank(query, .init(commands: CommandBarCommand.allCases))
        #expect(ranking.results.first?.kind == .search)
    }

    @Test func `addresses and history completions keep the top spot over commands`() {
        #expect(rank("settings.com", .init(commands: CommandBarCommand.allCases)).results.first?.kind == .url)
        let bookmarks = HistoryPage(url: "https://library.example/", title: "Library", frecency: 3)
        let ranking = rank("library", .init(history: [bookmarks], commands: CommandBarCommand.allCases))
        #expect(ranking.completion == "library.example")
        #expect(ranking.results.first?.kind == .history)
    }

    @Test func `other spaces are offered by name`() {
        let work = CommandBarRanker.OtherSpace(id: UUID(), name: "Work")
        let sources = CommandBarRanker.Sources(spaces: [work])
        #expect(rank("work", sources).results.contains { $0.kind == .space(work.id) && $0.title == "Switch to Work" })
        #expect(rank("space", sources).results.contains { $0.kind == .space(work.id) })
        #expect(!rank("home", sources).results.contains { $0.kind == .space(work.id) })
    }

    @Test func `extensions' buttons are offered by name, and all of them with nothing typed`() {
        let action = CommandBarRanker.ExtensionAction(id: "dark", name: "Dark Reader")
        let sources = CommandBarRanker.Sources(extensionActions: [action])
        #expect(rank("dark", sources).results.contains { $0.kind == .extensionAction("dark") && $0.title == "Dark Reader" })
        #expect(rank("extension", sources).results.contains { $0.kind == .extensionAction("dark") })
        #expect(!rank("light", sources).results.contains { $0.kind == .extensionAction("dark") })
        #expect(rank("", sources).results.contains { $0.kind == .extensionAction("dark") })
    }

    @Test func `suggestions repeat neither the query nor each other beyond the cap`() {
        let ranking = rank("swift", .init(suggestions: ["Swift", "swift lang", "swift ui", "swift 6", "swift book", "swiftly"]))
        let suggestions = ranking.sections.first { $0.title == "Suggestions" }?.results ?? []
        #expect(suggestions.map(\.title) == ["swift lang", "swift ui", "swift 6", "swift book"])
    }
}

struct NavigationDestinationTests {
    private let builder = NavigationRequestBuilder()

    @Test(arguments: ["example.com", "localhost:8080", "127.0.0.1", "github.com/lolrazh/cove"])
    func `hosts become https addresses`(input: String) {
        #expect(builder.destination(for: input) == .url(URL(string: "https://\(input)")!))
    }

    @Test(arguments: ["swift wkwebview docs", "cove", "what is 2+2"])
    func `words become searches`(input: String) {
        #expect(builder.destination(for: input) == .search(input))
    }

    @Test func `schemes are kept`() {
        #expect(builder.destination(for: "http://example.com") == .url(URL(string: "http://example.com")!))
        #expect(builder.destination(for: "about:blank") == .url(URL(string: "about:blank")!))
    }

    @Test func `blank input is nothing`() {
        #expect(builder.destination(for: "   ") == nil)
    }
}
