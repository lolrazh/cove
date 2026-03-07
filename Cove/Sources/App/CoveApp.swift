import SwiftUI

@main
struct CoveApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            BrowserView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unifiedCompact)
        .windowBackgroundDragBehavior(.enabled)
        .commands {
            BrowserViewCommands()
        }

        Settings {
            SettingsView()
        }
    }
}
