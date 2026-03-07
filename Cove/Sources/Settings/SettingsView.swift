import SwiftUI

@MainActor
struct SettingsView: View {
    @ObservedObject private var settingsStore: BrowserSettingsStore
    private let historyStore: HistoryStore

    init(settingsStore: BrowserSettingsStore, historyStore: HistoryStore) {
        self._settingsStore = ObservedObject(wrappedValue: settingsStore)
        self.historyStore = historyStore
    }

    var body: some View {
        TabView {
            GeneralSettingsPane(settingsStore: settingsStore)
                .tabItem {
                    Label("General", systemImage: ChromeSymbols.Settings.general)
                }

            PrivacySettingsPane(settingsStore: settingsStore, historyStore: historyStore)
                .tabItem {
                    Label("Privacy", systemImage: ChromeSymbols.Settings.privacy)
                }

            DownloadsSettingsPane(settingsStore: settingsStore)
                .tabItem {
                    Label("Downloads", systemImage: ChromeSymbols.Settings.downloads)
                }
        }
        .scenePadding()
        .frame(width: 500, height: 360)
    }
}

@MainActor
private struct GeneralSettingsPane: View {
    @ObservedObject private var settingsStore: BrowserSettingsStore

    init(settingsStore: BrowserSettingsStore) {
        self._settingsStore = ObservedObject(wrappedValue: settingsStore)
    }

    private var isHomePageMode: Bool {
        settingsStore.newTabPreference == .homePage
    }

    private var searchEngineBinding: Binding<String> {
        Binding(
            get: { settingsStore.searchEngine.rawValue },
            set: { rawValue in
                guard let searchEngine = SearchEngine(rawValue: rawValue) else { return }
                settingsStore.setSearchEngine(searchEngine)
            }
        )
    }

    private var newTabPreferenceBinding: Binding<String> {
        Binding(
            get: { settingsStore.newTabPreference.rawValue },
            set: { rawValue in
                guard let preference = NewTabPreference(rawValue: rawValue) else { return }
                settingsStore.setNewTabPreference(preference)
            }
        )
    }

    private var homePageURLBinding: Binding<String> {
        Binding(
            get: { settingsStore.homePageURL },
            set: { homePageURL in
                settingsStore.setHomePageURL(homePageURL)
            }
        )
    }

    private var showTabsInSidebarBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.showsTabsInSidebar },
            set: { showsTabsInSidebar in
                settingsStore.setShowsTabsInSidebar(showsTabsInSidebar)
            }
        )
    }

    private var hideTabsBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.hideTabs },
            set: { hideTabs in
                settingsStore.setHideTabs(hideTabs)
            }
        )
    }

    var body: some View {
        Form {
            Section("Browsing") {
                Picker("Search engine", selection: searchEngineBinding) {
                    ForEach(SearchEngine.allCases) { engine in
                        Text(engine.displayName).tag(engine.rawValue)
                    }
                }

                Picker("New tabs open with", selection: newTabPreferenceBinding) {
                    ForEach(NewTabPreference.allCases) { preference in
                        Text(preference.displayName).tag(preference.rawValue)
                    }
                }

                TextField("Home page URL", text: homePageURLBinding)
                    .disabled(!isHomePageMode)

                Toggle("Show Tabs in Sidebar", isOn: showTabsInSidebarBinding)
                Toggle("Hide Tabs", isOn: hideTabsBinding)
            }

            Section {
                Text("Cove keeps the top chrome custom, but uses native macOS behavior where it improves clarity and feel.")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
            }
        }
        .formStyle(.grouped)
    }
}

@MainActor
private struct PrivacySettingsPane: View {
    @ObservedObject private var settingsStore: BrowserSettingsStore
    private let historyStore: HistoryStore

    init(settingsStore: BrowserSettingsStore, historyStore: HistoryStore) {
        self._settingsStore = ObservedObject(wrappedValue: settingsStore)
        self.historyStore = historyStore
    }

    private var contentBlockingBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.contentBlockingEnabled },
            set: { isEnabled in
                settingsStore.setContentBlockingEnabled(isEnabled)
            }
        )
    }

    private var saveBrowsingHistoryBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.saveBrowsingHistory },
            set: { saveBrowsingHistory in
                settingsStore.setSaveBrowsingHistory(saveBrowsingHistory)
            }
        )
    }

    private var showRecentSitesBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.showRecentSites },
            set: { showRecentSites in
                settingsStore.setShowRecentSites(showRecentSites)
            }
        )
    }

    var body: some View {
        Form {
            Section("Privacy") {
                Toggle("Block ads and trackers", isOn: contentBlockingBinding)
                Toggle("Save browsing history", isOn: saveBrowsingHistoryBinding)
                Toggle("Show recent sites on the start page", isOn: showRecentSitesBinding)
                    .disabled(!settingsStore.saveBrowsingHistory)
            }

            Section("History") {
                Button("Clear History") {
                    historyStore.clearAll()
                }

                Text("Turning off history also removes recent sites from the start page.")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
            }
        }
        .formStyle(.grouped)
    }
}

@MainActor
private struct DownloadsSettingsPane: View {
    @ObservedObject private var settingsStore: BrowserSettingsStore

    init(settingsStore: BrowserSettingsStore) {
        self._settingsStore = ObservedObject(wrappedValue: settingsStore)
    }

    private var downloadDestinationModeBinding: Binding<String> {
        Binding(
            get: { settingsStore.downloadDestinationMode.rawValue },
            set: { rawValue in
                guard let mode = DownloadDestinationMode(rawValue: rawValue) else { return }
                settingsStore.setDownloadDestinationMode(mode)
            }
        )
    }

    var body: some View {
        Form {
            Section("Downloads") {
                Picker("Save downloaded files to", selection: downloadDestinationModeBinding) {
                    ForEach(DownloadDestinationMode.allCases) { mode in
                        Text(mode.displayName).tag(mode.rawValue)
                    }
                }
            }

            Section {
                Text("Custom persistent download folders can come later. The native first pass is Downloads or asking every time.")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
            }
        }
        .formStyle(.grouped)
    }
}
