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

    // MARK: - Setters

    func setSearchEngine(_ v: SearchEngine) { set(\.searchEngine, to: v, key: BrowserSettingKeys.searchEngine) }
    func setNewTabPreference(_ v: NewTabPreference) { set(\.newTabPreference, to: v, key: BrowserSettingKeys.newTabPreference) }
    func setHomePageURL(_ v: String) { set(\.homePageURL, to: v, key: BrowserSettingKeys.homePageURL) }
    func setShowsTabsInSidebar(_ v: Bool) { set(\.showsTabsInSidebar, to: v, key: BrowserSettingKeys.showTabsInSidebar) }
    func setHideTabs(_ v: Bool) { set(\.hideTabs, to: v, key: BrowserSettingKeys.hideTabs) }
    func setContentBlockingEnabled(_ v: Bool) { set(\.contentBlockingEnabled, to: v, key: BrowserSettingKeys.contentBlockingEnabled) }
    func setSaveBrowsingHistory(_ v: Bool) { set(\.saveBrowsingHistory, to: v, key: BrowserSettingKeys.saveBrowsingHistory) }
    func setShowRecentSites(_ v: Bool) { set(\.showRecentSites, to: v, key: BrowserSettingKeys.showRecentSites) }
    func setDownloadDestinationMode(_ v: DownloadDestinationMode) { set(\.downloadDestinationMode, to: v, key: BrowserSettingKeys.downloadDestinationMode) }

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
