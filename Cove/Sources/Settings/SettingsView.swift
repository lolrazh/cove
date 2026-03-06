import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsPane()
                .tabItem {
                    Label("General", systemImage: ChromeSymbols.Settings.general)
                }

            PrivacySettingsPane()
                .tabItem {
                    Label("Privacy", systemImage: ChromeSymbols.Settings.privacy)
                }

            DownloadsSettingsPane()
                .tabItem {
                    Label("Downloads", systemImage: ChromeSymbols.Settings.downloads)
                }
        }
        .scenePadding()
        .frame(width: 500, height: 360)
    }
}

private struct GeneralSettingsPane: View {
    @AppStorage(BrowserSettingKeys.searchEngine) private var searchEngine = SearchEngine.google.rawValue
    @AppStorage(BrowserSettingKeys.newTabPreference) private var newTabPreference = NewTabPreference.startPage.rawValue
    @AppStorage(BrowserSettingKeys.homePageURL) private var homePageURL = "https://www.google.com"
    @AppStorage(BrowserSettingKeys.preferredTabLayout) private var preferredTabLayout = PreferredTabLayout.horizontal.rawValue
    @AppStorage(BrowserSettingKeys.autoHideSidebar) private var autoHideSidebar = true

    private var isHomePageMode: Bool {
        newTabPreference == NewTabPreference.homePage.rawValue
    }

    var body: some View {
        Form {
            Section("Browsing") {
                Picker("Search engine", selection: $searchEngine) {
                    ForEach(SearchEngine.allCases) { engine in
                        Text(engine.displayName).tag(engine.rawValue)
                    }
                }

                Picker("New tabs open with", selection: $newTabPreference) {
                    ForEach(NewTabPreference.allCases) { preference in
                        Text(preference.displayName).tag(preference.rawValue)
                    }
                }

                TextField("Home page URL", text: $homePageURL)
                    .disabled(!isHomePageMode)

                Picker("Default tab layout", selection: $preferredTabLayout) {
                    ForEach(PreferredTabLayout.allCases) { layout in
                        Text(layout.displayName).tag(layout.rawValue)
                    }
                }

                Toggle("Auto-hide sidebar in sidebar mode", isOn: $autoHideSidebar)
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

private struct PrivacySettingsPane: View {
    @ObservedObject private var settingsStore = BrowserSettingsStore.shared
    @AppStorage(BrowserSettingKeys.contentBlockingEnabled) private var contentBlockingEnabled = true
    @AppStorage(BrowserSettingKeys.saveBrowsingHistory) private var saveBrowsingHistory = true
    @AppStorage(BrowserSettingKeys.showRecentSites) private var showRecentSites = true

    var body: some View {
        Form {
            Section("Privacy") {
                Toggle("Block ads and trackers", isOn: $contentBlockingEnabled)
                Toggle("Save browsing history", isOn: $saveBrowsingHistory)
                Toggle("Show recent sites on the start page", isOn: $showRecentSites)
                    .disabled(!saveBrowsingHistory)
            }

            Section("History") {
                Button("Clear History") {
                    settingsStore.clearHistory()
                }

                Text("Turning off history also removes recent sites from the start page.")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
            }
        }
        .formStyle(.grouped)
    }
}

private struct DownloadsSettingsPane: View {
    @AppStorage(BrowserSettingKeys.downloadDestinationMode) private var downloadDestinationMode = DownloadDestinationMode.downloadsFolder.rawValue

    var body: some View {
        Form {
            Section("Downloads") {
                Picker("Save downloaded files to", selection: $downloadDestinationMode) {
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
