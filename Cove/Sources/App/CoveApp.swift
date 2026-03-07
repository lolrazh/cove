import SwiftUI

@MainActor
@main
struct CoveApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    private let appServices: AppServices

    init() {
        let appServices = AppServices()
        self.appServices = appServices
        appServices.prepareForLaunch()
    }

    var body: some Scene {
        WindowGroup {
            BrowserView(appServices: appServices)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unifiedCompact)
        .windowBackgroundDragBehavior(.enabled)
        .commands {
            BrowserViewCommands()
        }

        Settings {
            SettingsView(
                settingsStore: appServices.settingsStore,
                historyStore: appServices.historyStore
            )
        }
    }
}
