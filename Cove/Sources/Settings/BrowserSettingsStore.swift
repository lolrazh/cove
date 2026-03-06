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
    private var cancellables: Set<AnyCancellable> = []

    private init(defaults: UserDefaults = .standard) {
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

        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification, object: defaults)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reloadFromDefaults()
            }
            .store(in: &cancellables)
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
        defaults.set(showsTabsInSidebar, forKey: BrowserSettingKeys.showTabsInSidebar)
    }

    func clearHistory() {
        HistoryStore.shared.clearAll()
    }

    private func reloadFromDefaults() {
        searchEngine = SearchEngine(rawValue: defaults.string(forKey: BrowserSettingKeys.searchEngine) ?? "") ?? .google
        newTabPreference = NewTabPreference(rawValue: defaults.string(forKey: BrowserSettingKeys.newTabPreference) ?? "") ?? .startPage
        homePageURL = defaults.string(forKey: BrowserSettingKeys.homePageURL) ?? "https://www.google.com"
        showsTabsInSidebar = Self.resolveShowsTabsInSidebar(defaults)
        hideTabs = defaults.bool(forKey: BrowserSettingKeys.hideTabs)
        contentBlockingEnabled = defaults.bool(forKey: BrowserSettingKeys.contentBlockingEnabled)
        saveBrowsingHistory = defaults.bool(forKey: BrowserSettingKeys.saveBrowsingHistory)
        showRecentSites = defaults.bool(forKey: BrowserSettingKeys.showRecentSites)
        downloadDestinationMode = DownloadDestinationMode(rawValue: defaults.string(forKey: BrowserSettingKeys.downloadDestinationMode) ?? "") ?? .downloadsFolder
    }

    private static func resolveShowsTabsInSidebar(_ defaults: UserDefaults) -> Bool {
        if defaults.object(forKey: BrowserSettingKeys.showTabsInSidebar) != nil {
            return defaults.bool(forKey: BrowserSettingKeys.showTabsInSidebar)
        }

        let legacyLayout = defaults.string(forKey: BrowserSettingKeys.legacyPreferredTabLayout)
        return legacyLayout == "sidebar"
    }
}
