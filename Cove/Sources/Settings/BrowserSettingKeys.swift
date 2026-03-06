import Foundation

enum BrowserSettingKeys {
    static let searchEngine = "browser.searchEngine"
    static let newTabPreference = "browser.newTabPreference"
    static let homePageURL = "browser.homePageURL"
    static let preferredTabLayout = "browser.preferredTabLayout"
    static let autoHideSidebar = "browser.autoHideSidebar"
    static let contentBlockingEnabled = "browser.contentBlockingEnabled"
    static let saveBrowsingHistory = "browser.saveBrowsingHistory"
    static let showRecentSites = "browser.showRecentSites"
    static let downloadDestinationMode = "browser.downloadDestinationMode"
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
}

enum NewTabPreference: String, CaseIterable, Identifiable {
    case startPage
    case blankPage
    case homePage

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .startPage:
            return "Start Page"
        case .blankPage:
            return "Blank Page"
        case .homePage:
            return "Home Page"
        }
    }
}

enum PreferredTabLayout: String, CaseIterable, Identifiable {
    case horizontal
    case sidebar

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .horizontal:
            return "Top Tabs"
        case .sidebar:
            return "Sidebar Tabs"
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
