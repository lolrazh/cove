import SwiftUI
import Combine

/// The Command Bar's state for one window: whether it's up, what's typed, and
/// the ranked rows. Owned by the window's `TabManager`, which it drives.
@MainActor
final class CommandBarModel: ObservableObject {
    enum Mode {
        /// ⌘T: Return opens the result in a new tab.
        case newTab
        /// ⌘L and the URL pill: Return navigates the current tab.
        case editURL
    }

    @Published private(set) var isPresented = false
    @Published private(set) var mode: Mode = .newTab
    @Published var query = "" {
        didSet { refresh() }
    }
    @Published private(set) var sections: [CommandBarSection] = []
    @Published private(set) var completion: String?
    @Published var selection: CommandBarResult?

    private unowned let tabManager: TabManager
    private let settings: BrowserSettingsStore
    private let historyStore: HistoryStore
    private let faviconStore: FaviconStore
    private let recentlyClosed: RecentlyClosedTabs
    private let ranker = CommandBarRanker()
    private let suggestions = SearchSuggestions()
    private var suggestionTask: Task<Void, Never>?
    /// The last answer from the engine, kept while the input grows from the
    /// query it answered so rows don't vanish between keystrokes.
    private var fetchedSuggestions: (query: String, items: [String])?

    init(
        tabManager: TabManager,
        settings: BrowserSettingsStore,
        historyStore: HistoryStore,
        faviconStore: FaviconStore,
        recentlyClosed: RecentlyClosedTabs
    ) {
        self.tabManager = tabManager
        self.settings = settings
        self.historyStore = historyStore
        self.faviconStore = faviconStore
        self.recentlyClosed = recentlyClosed
    }

    var searchEngine: SearchEngine { settings.searchEngine }

    var results: [CommandBarResult] { sections.flatMap(\.results) }

    // MARK: - Presenting

    func present(_ mode: Mode) {
        self.mode = mode
        isPresented = true
        query = mode == .editURL ? tabManager.activeTab?.currentURL ?? "" : ""
    }

    func dismiss() {
        guard isPresented else { return }
        isPresented = false
        suggestionTask?.cancel()
        fetchedSuggestions = nil
        sections = []
        completion = nil
        selection = nil
    }

    // MARK: - Choosing

    func moveSelection(by offset: Int) {
        let results = results
        guard !results.isEmpty else { return }
        let current = selection.flatMap(results.firstIndex) ?? 0
        selection = results[min(max(current + offset, 0), results.count - 1)]
    }

    func openSelection(inNewTab: Bool) {
        guard let selection else { return }
        open(selection, inNewTab: inNewTab)
    }

    func open(_ result: CommandBarResult, inNewTab: Bool) {
        switch result.kind {
        case .tab(let id):
            tabManager.selectTab(id)
        case .history, .url:
            load(result.destination, inNewTab: inNewTab)
        case .search, .suggestion:
            if let url = searchEngine.searchURL(for: result.destination) {
                load(url.absoluteString, inNewTab: inNewTab)
            }
        case .command(let command):
            perform(command)
        }
        dismiss()
    }

    /// Favicons for page rows: a tab's own, or the cached one for its site.
    func icon(for result: CommandBarResult) -> NSImage? {
        if case .tab(let id) = result.kind, let tab = tabManager.tabs.first(where: { $0.id == id }) {
            return tab.favicon
        }
        return faviconStore.image(forPage: result.destination)
    }

    // MARK: - Acting

    /// A new tab unless the input was meant for the current one, or the current
    /// tab is an empty start page with nothing to lose.
    private func load(_ input: String, inNewTab: Bool) {
        let activeTab = tabManager.activeTab
        let reuseActive = activeTab.map { $0.isNewTabPage && $0.currentURL.isEmpty } ?? false
        if let activeTab, !inNewTab, mode == .editURL || reuseActive {
            activeTab.navigate(input)
        } else {
            tabManager.addTab(url: input)
        }
    }

    private func perform(_ command: CommandBarCommand) {
        switch command {
        case .copyURL:
            guard let url = tabManager.activeTab?.currentURL else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(url, forType: .string)
        case .showTabsInSidebar:
            withAnimation(ChromeMotion.shell) { tabManager.setLayout(.sidebar) }
        case .showTabsOnTop:
            withAnimation(ChromeMotion.shell) { tabManager.setLayout(.horizontal) }
        case .hideTabs:
            withAnimation(ChromeMotion.shell) { tabManager.setHideTabs(true) }
        case .showTabs:
            withAnimation(ChromeMotion.shell) { tabManager.setHideTabs(false) }
        case .reopenClosedTab:
            tabManager.reopenClosedTab()
        case .newWindow, .showHistory, .settings:
            // Opening a SwiftUI scene needs the view's environment; the view
            // handles these before calling `open`.
            break
        }
    }

    /// Commands that make sense right now, under the name for the state
    /// they would move to.
    private var availableCommands: [CommandBarCommand] {
        CommandBarCommand.allCases.filter { command in
            switch command {
            case .copyURL: !(tabManager.activeTab?.currentURL.isEmpty ?? true)
            case .showTabsInSidebar: tabManager.tabLayout == .horizontal
            case .showTabsOnTop: tabManager.tabLayout == .sidebar
            case .hideTabs: !tabManager.hideTabs
            case .showTabs: tabManager.hideTabs
            case .reopenClosedTab: !recentlyClosed.entries.isEmpty
            case .newWindow, .showHistory, .settings: true
            }
        }
    }

    // MARK: - Ranking

    private func refresh() {
        guard isPresented else { return }
        let trimmed = query.trimmingCharacters(in: .whitespaces)

        let tabs = tabManager.tabs
            .filter { $0.id != tabManager.activeTabID && !$0.currentURL.isEmpty }
            .map { CommandBarRanker.OpenTab(id: $0.id, title: $0.pageTitle, url: $0.currentURL) }
        let history = trimmed.isEmpty
            ? historyStore.recentlyVisited.map { HistoryPage(url: $0.url, title: $0.title, frecency: 0) }
            : historyStore.pages(matching: trimmed)

        let ranking = ranker.rank(
            query: query,
            sources: CommandBarRanker.Sources(
                tabs: tabs,
                history: history,
                suggestions: currentSuggestions(for: trimmed),
                commands: availableCommands
            )
        )
        sections = ranking.sections
        completion = ranking.completion
        if let selection, ranking.results.contains(selection) {
            self.selection = selection
        } else {
            selection = ranking.results.first
        }
        fetchSuggestionsIfNeeded(for: trimmed)
    }

    private func currentSuggestions(for query: String) -> [String] {
        guard let fetched = fetchedSuggestions, query.hasPrefix(fetched.query) else { return [] }
        return fetched.items
    }

    /// Asks the engine after a short pause in typing, and only for input that
    /// would be searched, not for addresses.
    private func fetchSuggestionsIfNeeded(for query: String) {
        suggestionTask?.cancel()
        guard settings.showSearchSuggestions,
              !query.isEmpty,
              fetchedSuggestions?.query != query,
              case .search = NavigationRequestBuilder().destination(for: query) else { return }

        let engine = searchEngine
        suggestionTask = Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            let items = await suggestions.fetch(query, from: engine)
            guard !Task.isCancelled else { return }
            fetchedSuggestions = (query, items)
            refresh()
        }
    }
}
