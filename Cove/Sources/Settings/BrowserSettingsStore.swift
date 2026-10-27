import Foundation
import Combine

enum NewTabDestination {
    case startPage
    case url(String)
}

@MainActor
final class BrowserSettingsStore: ObservableObject {
    @Published private(set) var searchEngine: SearchEngine
    @Published private(set) var newTabPreference: NewTabPreference
    @Published private(set) var homePageURL: String
    @Published private(set) var showsTabsInSidebar: Bool
    @Published private(set) var hideTabs: Bool
    @Published private(set) var sidebarWidth: Double
    @Published private(set) var contentBlockingEnabled: Bool
    @Published private(set) var saveBrowsingHistory: Bool
    @Published private(set) var showRecentSites: Bool
    @Published private(set) var showSearchSuggestions: Bool
    @Published private(set) var downloadDestinationMode: DownloadDestinationMode
    @Published private(set) var sleepTabsAfter: TabSleepDelay
    @Published private(set) var archiveTabsAfter: TabArchiveDelay
    /// Links from other apps open in a small window of their own, as in Arc's
    /// Little Arc, instead of a tab in the browser window.
    @Published private(set) var opensLinksInLittleCove: Bool

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        defaults.register(defaults: [
            BrowserSettingKeys.searchEngine: SearchEngine.google.rawValue,
            BrowserSettingKeys.newTabPreference: NewTabPreference.commandBar.rawValue,
            BrowserSettingKeys.homePageURL: "https://www.google.com",
            BrowserSettingKeys.showTabsInSidebar: false,
            BrowserSettingKeys.hideTabs: false,
            BrowserSettingKeys.sidebarWidth: ChromeMetrics.sidebarDefaultWidth,
            BrowserSettingKeys.contentBlockingEnabled: true,
            BrowserSettingKeys.saveBrowsingHistory: true,
            BrowserSettingKeys.showRecentSites: true,
            BrowserSettingKeys.showSearchSuggestions: true,
            BrowserSettingKeys.downloadDestinationMode: DownloadDestinationMode.downloadsFolder.rawValue,
            BrowserSettingKeys.sleepTabsAfter: TabSleepDelay.thirtyMinutes.rawValue,
            BrowserSettingKeys.archiveTabsAfter: TabArchiveDelay.oneDay.rawValue,
            BrowserSettingKeys.opensLinksInLittleCove: false,
        ])

        self.searchEngine = SearchEngine(rawValue: defaults.string(forKey: BrowserSettingKeys.searchEngine) ?? "") ?? .google
        self.newTabPreference = NewTabPreference(rawValue: defaults.string(forKey: BrowserSettingKeys.newTabPreference) ?? "") ?? .commandBar
        self.homePageURL = defaults.string(forKey: BrowserSettingKeys.homePageURL) ?? "https://www.google.com"
        self.showsTabsInSidebar = Self.resolveShowsTabsInSidebar(defaults)
        self.hideTabs = defaults.bool(forKey: BrowserSettingKeys.hideTabs)
        self.sidebarWidth = defaults.double(forKey: BrowserSettingKeys.sidebarWidth)
        self.contentBlockingEnabled = defaults.bool(forKey: BrowserSettingKeys.contentBlockingEnabled)
        self.saveBrowsingHistory = defaults.bool(forKey: BrowserSettingKeys.saveBrowsingHistory)
        self.showRecentSites = defaults.bool(forKey: BrowserSettingKeys.showRecentSites)
        self.showSearchSuggestions = defaults.bool(forKey: BrowserSettingKeys.showSearchSuggestions)
        self.downloadDestinationMode = DownloadDestinationMode(rawValue: defaults.string(forKey: BrowserSettingKeys.downloadDestinationMode) ?? "") ?? .downloadsFolder
        self.sleepTabsAfter = TabSleepDelay(rawValue: defaults.string(forKey: BrowserSettingKeys.sleepTabsAfter) ?? "") ?? .thirtyMinutes
        self.archiveTabsAfter = TabArchiveDelay(rawValue: defaults.string(forKey: BrowserSettingKeys.archiveTabsAfter) ?? "") ?? .oneDay
        self.opensLinksInLittleCove = defaults.bool(forKey: BrowserSettingKeys.opensLinksInLittleCove)
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

    /// Where a tab that must exist (the first one, a reopened one) starts. The
    /// Command Bar preference has nothing to show in a tab, so it falls back to
    /// the start page.
    func destinationForNewTab() -> NewTabDestination {
        switch newTabPreference {
        case .commandBar, .startPage:
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

    // MARK: - Setters

    func setSearchEngine(_ v: SearchEngine) { set(\.searchEngine, to: v, key: BrowserSettingKeys.searchEngine) }
    func setNewTabPreference(_ v: NewTabPreference) { set(\.newTabPreference, to: v, key: BrowserSettingKeys.newTabPreference) }
    func setHomePageURL(_ v: String) { set(\.homePageURL, to: v, key: BrowserSettingKeys.homePageURL) }
    func setShowsTabsInSidebar(_ v: Bool) { set(\.showsTabsInSidebar, to: v, key: BrowserSettingKeys.showTabsInSidebar) }
    func setHideTabs(_ v: Bool) { set(\.hideTabs, to: v, key: BrowserSettingKeys.hideTabs) }
    func setSidebarWidth(_ v: Double) { set(\.sidebarWidth, to: v, key: BrowserSettingKeys.sidebarWidth) }
    func setContentBlockingEnabled(_ v: Bool) { set(\.contentBlockingEnabled, to: v, key: BrowserSettingKeys.contentBlockingEnabled) }
    func setSaveBrowsingHistory(_ v: Bool) { set(\.saveBrowsingHistory, to: v, key: BrowserSettingKeys.saveBrowsingHistory) }
    func setShowRecentSites(_ v: Bool) { set(\.showRecentSites, to: v, key: BrowserSettingKeys.showRecentSites) }
    func setShowSearchSuggestions(_ v: Bool) { set(\.showSearchSuggestions, to: v, key: BrowserSettingKeys.showSearchSuggestions) }
    func setDownloadDestinationMode(_ v: DownloadDestinationMode) { set(\.downloadDestinationMode, to: v, key: BrowserSettingKeys.downloadDestinationMode) }
    func setSleepTabsAfter(_ v: TabSleepDelay) { set(\.sleepTabsAfter, to: v, key: BrowserSettingKeys.sleepTabsAfter) }
    func setArchiveTabsAfter(_ v: TabArchiveDelay) { set(\.archiveTabsAfter, to: v, key: BrowserSettingKeys.archiveTabsAfter) }
    func setOpensLinksInLittleCove(_ v: Bool) { set(\.opensLinksInLittleCove, to: v, key: BrowserSettingKeys.opensLinksInLittleCove) }

    // MARK: - Private

    private func set<T: Equatable>(_ keyPath: ReferenceWritableKeyPath<BrowserSettingsStore, T>, to value: T, key: String) {
        guard self[keyPath: keyPath] != value else { return }
        self[keyPath: keyPath] = value
        defaults.set(value, forKey: key)
    }

    private func set<T: Equatable & RawRepresentable>(_ keyPath: ReferenceWritableKeyPath<BrowserSettingsStore, T>, to value: T, key: String) {
        guard self[keyPath: keyPath] != value else { return }
        self[keyPath: keyPath] = value
        defaults.set(value.rawValue, forKey: key)
    }

    private static func resolveShowsTabsInSidebar(_ defaults: UserDefaults) -> Bool {
        if defaults.object(forKey: BrowserSettingKeys.showTabsInSidebar) != nil {
            return defaults.bool(forKey: BrowserSettingKeys.showTabsInSidebar)
        }

        let legacyLayout = defaults.string(forKey: BrowserSettingKeys.legacyPreferredTabLayout)
        return legacyLayout == "sidebar"
    }
}
