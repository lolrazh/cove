import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsStore: BrowserSettingsStore
    let historyStore: HistoryStore

    var body: some View {
        TabView {
            Tab("General", systemImage: ChromeSymbols.Settings.general) {
                GeneralSettingsPane(settings: settingsStore)
            }
            Tab("Appearance", systemImage: ChromeSymbols.Settings.appearance) {
                AppearanceSettingsPane(settings: settingsStore)
            }
            Tab("Privacy", systemImage: ChromeSymbols.Settings.privacy) {
                PrivacySettingsPane(settings: settingsStore, historyStore: historyStore)
            }
            Tab("Downloads", systemImage: ChromeSymbols.Settings.downloads) {
                DownloadsSettingsPane(settings: settingsStore)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 400)
    }
}

private struct GeneralSettingsPane: View {
    @ObservedObject var settings: BrowserSettingsStore

    var body: some View {
        Form {
            Section("Search") {
                Picker("Search engine", selection: settings.binding(\.searchEngine, set: settings.setSearchEngine)) {
                    ForEach(SearchEngine.allCases) { engine in
                        Text(engine.displayName).tag(engine)
                    }
                }
            }

            Section("New Tabs") {
                Picker("New tabs open with", selection: settings.binding(\.newTabPreference, set: settings.setNewTabPreference)) {
                    ForEach(NewTabPreference.allCases) { preference in
                        Text(preference.displayName).tag(preference)
                    }
                }

                TextField("Home page", text: settings.binding(\.homePageURL, set: settings.setHomePageURL), prompt: Text("https://"))
                    .disabled(settings.newTabPreference != .homePage)
            }

            Section {
                Picker("Sleep background tabs after", selection: settings.binding(\.sleepTabsAfter, set: settings.setSleepTabsAfter)) {
                    ForEach(TabSleepDelay.allCases) { delay in
                        Text(delay.displayName).tag(delay)
                    }
                }

                Picker("Archive unused tabs after", selection: settings.binding(\.archiveTabsAfter, set: settings.setArchiveTabsAfter)) {
                    ForEach(TabArchiveDelay.allCases) { delay in
                        Text(delay.displayName).tag(delay)
                    }
                }
            } header: {
                Text("Tabs")
            } footer: {
                Text("Sleeping tabs give back their memory and reload when selected. Archived tabs leave the sidebar and can be reopened from the Command Bar.")
            }
        }
    }
}

private struct AppearanceSettingsPane: View {
    @ObservedObject var settings: BrowserSettingsStore

    var body: some View {
        Form {
            Section {
                LabeledContent("Frame color") {
                    HStack(spacing: 10) {
                        ForEach(ChromeTheme.presets, id: \.rawValue) { theme in
                            ThemeSwatch(theme: theme, isSelected: theme == settings.theme) {
                                settings.setTheme(theme)
                            }
                        }
                    }
                }

                ColorPicker("Custom color", selection: customTint, supportsOpacity: false)
            } header: {
                Text("Theme")
            } footer: {
                Text("Tints the frame around the page. The page itself is never tinted.")
            }

            Section("Tabs") {
                Toggle("Show Tabs in Sidebar", isOn: settings.binding(\.showsTabsInSidebar, set: settings.setShowsTabsInSidebar))
                Toggle("Hide Tabs", isOn: settings.binding(\.hideTabs, set: settings.setHideTabs))
            }
        }
    }

    private var customTint: Binding<Color> {
        Binding(
            get: { settings.theme.tint ?? Color(nsColor: .underPageBackgroundColor) },
            set: { settings.setTheme(ChromeTheme(tint: $0)) }
        )
    }
}

/// One theme to pick: its tint as a disc, the system gray for none, with a
/// ring in the accent color around the selected one.
private struct ThemeSwatch: View {
    let theme: ChromeTheme
    let isSelected: Bool
    let action: () -> Void

    private let side: CGFloat = 22

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(theme.tint ?? Color(nsColor: .underPageBackgroundColor))
                .overlay {
                    Circle().strokeBorder(.separator)
                }
                .padding(3)
                .overlay {
                    Circle()
                        .strokeBorder(.tint, lineWidth: 2)
                        .opacity(isSelected ? 1 : 0)
                }
                .frame(width: side + 6, height: side + 6)
                .animation(ChromeMotion.hover, value: isSelected)
        }
        .buttonStyle(.plain)
        .help(theme.tint == nil ? "System" : "Color \(theme.rawValue)")
    }
}

private struct PrivacySettingsPane: View {
    @ObservedObject var settings: BrowserSettingsStore
    let historyStore: HistoryStore

    var body: some View {
        Form {
            Section("Privacy") {
                Toggle("Block ads and trackers", isOn: settings.binding(\.contentBlockingEnabled, set: settings.setContentBlockingEnabled))
                Toggle("Save browsing history", isOn: settings.binding(\.saveBrowsingHistory, set: settings.setSaveBrowsingHistory))
                Toggle("Show recent sites on the start page", isOn: settings.binding(\.showRecentSites, set: settings.setShowRecentSites))
                    .disabled(!settings.saveBrowsingHistory)
                Toggle("Show search suggestions in the Command Bar", isOn: settings.binding(\.showSearchSuggestions, set: settings.setShowSearchSuggestions))
            }

            Section {
                Button("Clear History", action: historyStore.clearAll)
            } header: {
                Text("History")
            } footer: {
                Text("Turning off history also removes recent sites from the start page.")
            }
        }
    }
}

private struct DownloadsSettingsPane: View {
    @ObservedObject var settings: BrowserSettingsStore

    var body: some View {
        Form {
            Section("Downloads") {
                Picker("Save downloaded files to", selection: settings.binding(\.downloadDestinationMode, set: settings.setDownloadDestinationMode)) {
                    ForEach(DownloadDestinationMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
            }
        }
    }
}

private extension BrowserSettingsStore {
    /// A control binding for a setting: reads the published value, writes
    /// through its setter.
    func binding<Value>(
        _ keyPath: KeyPath<BrowserSettingsStore, Value>,
        set: @escaping @MainActor (Value) -> Void
    ) -> Binding<Value> {
        Binding(get: { self[keyPath: keyPath] }, set: set)
    }
}
