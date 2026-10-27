import Foundation

enum BrowserSettingKeys {
    static let searchEngine = "browser.searchEngine"
    static let newTabPreference = "browser.newTabPreference"
    static let homePageURL = "browser.homePageURL"
    static let showTabsInSidebar = "browser.showTabsInSidebar"
    static let hideTabs = "browser.hideTabs"
    static let sidebarWidth = "browser.sidebarWidth"
    static let contentBlockingEnabled = "browser.contentBlockingEnabled"
    static let saveBrowsingHistory = "browser.saveBrowsingHistory"
    static let showRecentSites = "browser.showRecentSites"
    static let showSearchSuggestions = "browser.showSearchSuggestions"
    static let downloadDestinationMode = "browser.downloadDestinationMode"
    static let sleepTabsAfter = "browser.sleepTabsAfter"
    static let archiveTabsAfter = "browser.archiveTabsAfter"
    static let opensLinksInLittleCove = "browser.opensLinksInLittleCove"
    static let legacyPreferredTabLayout = "browser.preferredTabLayout"
    /// The frame color from before each space had its own; the first space's.
    static let legacyThemeColor = "browser.themeColor"
}

/// How long a background tab goes unused before it sleeps.
enum TabSleepDelay: String, CaseIterable, Identifiable {
    case fiveMinutes
    case fifteenMinutes
    case thirtyMinutes
    case oneHour
    case never

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fiveMinutes: "5 Minutes"
        case .fifteenMinutes: "15 Minutes"
        case .thirtyMinutes: "30 Minutes"
        case .oneHour: "1 Hour"
        case .never: "Never"
        }
    }

    var interval: TimeInterval? {
        switch self {
        case .fiveMinutes: 5 * 60
        case .fifteenMinutes: 15 * 60
        case .thirtyMinutes: 30 * 60
        case .oneHour: 60 * 60
        case .never: nil
        }
    }
}

/// How long a Today tab goes unused before it's archived.
enum TabArchiveDelay: String, CaseIterable, Identifiable {
    case twelveHours
    case oneDay
    case oneWeek
    case oneMonth
    case never

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .twelveHours: "12 Hours"
        case .oneDay: "24 Hours"
        case .oneWeek: "7 Days"
        case .oneMonth: "30 Days"
        case .never: "Never"
        }
    }

    var interval: TimeInterval? {
        switch self {
        case .twelveHours: 12 * 3600
        case .oneDay: 24 * 3600
        case .oneWeek: 7 * 24 * 3600
        case .oneMonth: 30 * 24 * 3600
        case .never: nil
        }
    }
}

enum SearchEngine: String, CaseIterable, Identifiable {
    case google
    case duckDuckGo
    case kagi

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .google:
            return "Google"
        case .duckDuckGo:
            return "DuckDuckGo"
        case .kagi:
            return "Kagi"
        }
    }

    func searchURL(for query: String) -> URL? {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query

        switch self {
        case .google:
            return URL(string: "https://www.google.com/search?q=\(encoded)")
        case .duckDuckGo:
            return URL(string: "https://duckduckgo.com/?q=\(encoded)")
        case .kagi:
            return URL(string: "https://kagi.com/search?q=\(encoded)")
        }
    }

    /// The engine's autocomplete endpoint. All three answer in the OpenSearch
    /// form Firefox uses: `["query", ["completion", …]]`.
    func suggestionsURL(for query: String) -> URL? {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query

        switch self {
        case .google:
            return URL(string: "https://suggestqueries.google.com/complete/search?client=firefox&q=\(encoded)")
        case .duckDuckGo:
            return URL(string: "https://duckduckgo.com/ac/?type=list&q=\(encoded)")
        case .kagi:
            return URL(string: "https://kagi.com/api/autosuggest?q=\(encoded)")
        }
    }
}

enum NewTabPreference: String, CaseIterable, Identifiable {
    case commandBar
    case startPage
    case blankPage
    case homePage

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .commandBar:
            return "Command Bar"
        case .startPage:
            return "Start Page"
        case .blankPage:
            return "Blank Page"
        case .homePage:
            return "Home Page"
        }
    }
}

enum DownloadDestinationMode: String, CaseIterable, Identifiable {
    case downloadsFolder
    case askEveryTime

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .downloadsFolder:
            return "Downloads Folder"
        case .askEveryTime:
            return "Ask Every Time"
        }
    }
}
