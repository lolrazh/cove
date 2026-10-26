import Foundation

/// One row in the Command Bar. Identity comes from the kind and its payload, so
/// a selection survives the list refreshing around it.
struct CommandBarResult: Identifiable, Hashable {
    enum Kind: Hashable {
        /// An open tab in this window.
        case tab(UUID)
        /// A page from history.
        case history
        /// The input taken as an address.
        case url
        /// The input taken as a search.
        case search
        /// A completion offered by the search engine.
        case suggestion
        case command(CommandBarCommand)
    }

    let kind: Kind
    /// What the row says: a page title, a query, or a command name.
    let title: String
    /// Where it leads: a URL for pages, a query for searches. Empty for commands.
    let destination: String

    var id: Self { self }

    /// A page row's address without the parts people don't read.
    var displayURL: String {
        Self.displayURL(for: destination)
    }

    static func displayURL(for url: String) -> String {
        var display = url
        for prefix in ["https://", "http://"] where display.hasPrefix(prefix) {
            display.removeFirst(prefix.count)
        }
        if display.hasPrefix("www.") { display.removeFirst(4) }
        if display.hasSuffix("/") { display.removeLast() }
        return display
    }
}

struct CommandBarSection: Identifiable {
    /// Nil for the top hit, which needs no heading.
    let title: String?
    let results: [CommandBarResult]

    var id: String { title ?? "" }
}

/// Things the Command Bar can do besides navigate. Only commands that exist
/// elsewhere in the app, under the names their menu items use.
enum CommandBarCommand: CaseIterable, Hashable {
    case copyURL
    case showTabsInSidebar
    case showTabsOnTop
    case hideTabs
    case showTabs
    case reopenClosedTab
    case showHistory
    case settings

    var title: String {
        switch self {
        case .copyURL: "Copy URL"
        case .showTabsInSidebar: "Show Tabs in Sidebar"
        case .showTabsOnTop: "Show Tabs on Top"
        case .hideTabs: "Hide Tabs"
        case .showTabs: "Show Tabs"
        case .reopenClosedTab: "Reopen Last Closed Tab"
        case .showHistory: "Show All History"
        case .settings: "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .copyURL: "link"
        case .showTabsInSidebar, .showTabsOnTop: ChromeSymbols.Tabs.sidebarLayout
        case .hideTabs: "eye.slash"
        case .showTabs: "eye"
        case .reopenClosedTab: "arrow.uturn.backward"
        case .showHistory: ChromeSymbols.Navigation.history
        case .settings: ChromeSymbols.Settings.general
        }
    }

    /// Words people might type that aren't in the title.
    var keywords: [String] {
        switch self {
        case .copyURL: ["link", "address"]
        case .showTabsInSidebar, .showTabsOnTop: ["toggle", "layout", "vertical", "horizontal"]
        case .hideTabs, .showTabs: ["toggle", "sidebar", "immersive"]
        case .reopenClosedTab: ["restore", "undo"]
        case .showHistory: ["recent", "visited"]
        case .settings: ["preferences", "options"]
        }
    }
}
