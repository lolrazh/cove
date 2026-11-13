import SwiftUI

@MainActor
@main
struct CoveApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    private let appServices: AppServices

    init() {
        do {
            try ProfileMigration.run(initialTheme: ChromeTheme(rawValue: UserDefaults.standard.string(forKey: BrowserSettingKeys.legacyThemeColor) ?? ""))
        } catch {
            let alert = NSAlert()
            alert.messageText = "Cove could not migrate your profiles"
            alert.informativeText = "Your original files are unchanged. Cove will close to protect your data. \(error.localizedDescription)"
            alert.runModal()
            exit(EXIT_FAILURE)
        }
        let appServices = AppServices()
        self.appServices = appServices
        appServices.prepareForLaunch()
    }

    var body: some Scene {
        WindowGroup(id: BrowserView.windowID) {
            BrowserView(appServices: appServices)
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        }
        .browserWindowStyle()
        .commands {
            BrowserViewCommands(appServices: appServices)
            TabCommands()
            ProfileCommands()
            PageToolsCommands()
        }

        // Private windows: never reopened, and never the target of links from
        // other apps.
        WindowGroup("Private Window", id: BrowserView.privateWindowID) {
            BrowserView(appServices: appServices, isPrivate: true)
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        }
        .browserWindowStyle()
        .handlesExternalEvents(matching: [])

        WindowGroup("History", id: HistoryWindow.windowID, for: UUID.self) { $profileID in
            ProfileHistoryView(appServices: appServices, store: appServices.profileStore,
                               profileID: profileID ?? Profile.defaultID)
        }
        .defaultSize(width: 760, height: 560)
        .handlesExternalEvents(matching: [])
        .restorationBehavior(.disabled)

        Settings {
            SettingsView(
                settingsStore: appServices.settingsStore,

                profileStore: appServices.profileStore,
                extensionLibrary: appServices.extensionLibrary
            )
        }
    }


}

private struct ProfileHistoryView: View {
    let appServices: AppServices
    @ObservedObject var store: ProfileStore
    let profileID: UUID

    var body: some View {
        if let profile = store.profiles.profile(profileID), let data = store.context(for: profile).profileData {
            HistoryWindow(historyStore: data.history, faviconStore: data.favicons) { urlString in
                guard let url = URL(string: urlString) else { return }
                appServices.externalURLRouter.open([url], in: profileID)
            }
            .navigationTitle("\(profile.name) History")
        } else {
            Text("This profile was deleted.").foregroundStyle(.secondary)
        }
    }
}

private extension Scene {
    func browserWindowStyle() -> some Scene {
        windowStyle(.titleBar)
            .windowToolbarStyle(.unifiedCompact)
            .windowBackgroundDragBehavior(.enabled)
            // `SessionStore` reopens browser windows, with their tabs.
            .restorationBehavior(.disabled)
    }
}
