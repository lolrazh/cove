import Foundation
import Combine

enum NewTabDestination {
    case startPage
    case url(String)
}

@MainActor
final class BrowserSettingsStore: ObservableObject {
    static let shared = BrowserSettingsStore()

    @Published private(set) var searchEngine: SearchEngine
    @Published private(set) var newTabPreference: NewTabPreference
    @Published private(set) var homePageURL: String
    @Published private(set) var showsTabsInSidebar: Bool
    @Published private(set) var hideTabs: Bool
    @Published private(set) var contentBlockingEnabled: Bool
    @Published private(set) var saveBrowsingHistory: Bool
    @Published private(set) var showRecentSites: Bool
    @Published private(set) var downloadDestinationMode: DownloadDestinationMode

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        defaults.register(defaults: [
            BrowserSettingKeys.searchEngine: SearchEngine.google.rawValue,
            BrowserSettingKeys.newTabPreference: NewTabPreference.startPage.rawValue,
            BrowserSettingKeys.homePageURL: "https://www.google.com",
            BrowserSettingKeys.showTabsInSidebar: false,
            BrowserSettingKeys.hideTabs: false,
            BrowserSettingKeys.contentBlockingEnabled: true,
            BrowserSettingKeys.saveBrowsingHistory: true,
            BrowserSettingKeys.showRecentSites: true,
            BrowserSettingKeys.downloadDestinationMode: DownloadDestinationMode.downloadsFolder.rawValue,
        ])

        self.searchEngine = SearchEngine(rawValue: defaults.string(forKey: BrowserSettingKeys.searchEngine) ?? "") ?? .google
        self.newTabPreference = NewTabPreference(rawValue: defaults.string(forKey: BrowserSettingKeys.newTabPreference) ?? "") ?? .startPage
        self.homePageURL = defaults.string(forKey: BrowserSettingKeys.homePageURL) ?? "https://www.google.com"
        self.showsTabsInSidebar = Self.resolveShowsTabsInSidebar(defaults)
        self.hideTabs = defaults.bool(forKey: BrowserSettingKeys.hideTabs)
        self.contentBlockingEnabled = defaults.bool(forKey: BrowserSettingKeys.contentBlockingEnabled)
        self.saveBrowsingHistory = defaults.bool(forKey: BrowserSettingKeys.saveBrowsingHistory)
        self.showRecentSites = defaults.bool(forKey: BrowserSettingKeys.showRecentSites)
        self.downloadDestinationMode = DownloadDestinationMode(rawValue: defaults.string(forKey: BrowserSettingKeys.downloadDestinationMode) ?? "") ?? .downloadsFolder
    }

    var shouldShowRecentSites: Bool {
        saveBrowsingHistory && showRecentSites
    }

    var normalizedHomePageURL: String? {
        let trimmed = homePageURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let directURL = URL(string: trimmed), directURL.scheme != nil {
            return directURL.absoluteString
        }

        return URL(string: "https://\(trimmed)")?.absoluteString
    }

    func destinationForNewTab() -> NewTabDestination {
        switch newTabPreference {
        case .startPage:
            return .startPage
        case .blankPage:
            return .url("about:blank")
        case .homePage:
            if let homePage = normalizedHomePageURL {
                return .url(homePage)
            }
            return .startPage
        }
    }

    func setShowsTabsInSidebar(_ showsTabsInSidebar: Bool) {
        guard self.showsTabsInSidebar != showsTabsInSidebar else { return }
        self.showsTabsInSidebar = showsTabsInSidebar
        defaults.set(showsTabsInSidebar, forKey: BrowserSettingKeys.showTabsInSidebar)
    }

    func setHideTabs(_ hideTabs: Bool) {
        guard self.hideTabs != hideTabs else { return }
        self.hideTabs = hideTabs
        defaults.set(hideTabs, forKey: BrowserSettingKeys.hideTabs)
    }

    func setSearchEngine(_ searchEngine: SearchEngine) {
        guard self.searchEngine != searchEngine else { return }
        self.searchEngine = searchEngine
        defaults.set(searchEngine.rawValue, forKey: BrowserSettingKeys.searchEngine)
    }

    func setNewTabPreference(_ newTabPreference: NewTabPreference) {
        guard self.newTabPreference != newTabPreference else { return }
        self.newTabPreference = newTabPreference
        defaults.set(newTabPreference.rawValue, forKey: BrowserSettingKeys.newTabPreference)
    }

    func setHomePageURL(_ homePageURL: String) {
        guard self.homePageURL != homePageURL else { return }
        self.homePageURL = homePageURL
        defaults.set(homePageURL, forKey: BrowserSettingKeys.homePageURL)
    }

    func setContentBlockingEnabled(_ contentBlockingEnabled: Bool) {
        guard self.contentBlockingEnabled != contentBlockingEnabled else { return }
        self.contentBlockingEnabled = contentBlockingEnabled
        defaults.set(contentBlockingEnabled, forKey: BrowserSettingKeys.contentBlockingEnabled)
    }

    func setSaveBrowsingHistory(_ saveBrowsingHistory: Bool) {
        guard self.saveBrowsingHistory != saveBrowsingHistory else { return }
        self.saveBrowsingHistory = saveBrowsingHistory
        defaults.set(saveBrowsingHistory, forKey: BrowserSettingKeys.saveBrowsingHistory)
    }

    func setShowRecentSites(_ showRecentSites: Bool) {
        guard self.showRecentSites != showRecentSites else { return }
        self.showRecentSites = showRecentSites
        defaults.set(showRecentSites, forKey: BrowserSettingKeys.showRecentSites)
    }

    func setDownloadDestinationMode(_ downloadDestinationMode: DownloadDestinationMode) {
        guard self.downloadDestinationMode != downloadDestinationMode else { return }
        self.downloadDestinationMode = downloadDestinationMode
        defaults.set(downloadDestinationMode.rawValue, forKey: BrowserSettingKeys.downloadDestinationMode)
    }

    private static func resolveShowsTabsInSidebar(_ defaults: UserDefaults) -> Bool {
        if defaults.object(forKey: BrowserSettingKeys.showTabsInSidebar) != nil {
            return defaults.bool(forKey: BrowserSettingKeys.showTabsInSidebar)
        }

        let legacyLayout = defaults.string(forKey: BrowserSettingKeys.legacyPreferredTabLayout)
        return legacyLayout == "sidebar"
    }
}
