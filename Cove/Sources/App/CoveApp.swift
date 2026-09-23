import SwiftUI

@MainActor
@main
struct CoveApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    private let appServices: AppServices

    init() {
        let appServices = AppServices()
        self.appServices = appServices
        appDelegate.externalURLRouter = appServices.externalURLRouter
        appServices.prepareForLaunch()
    }

    var body: some Scene {
        WindowGroup {
            BrowserView(appServices: appServices)
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unifiedCompact)
        .windowBackgroundDragBehavior(.enabled)
        .commands {
            BrowserViewCommands(appServices: appServices)
        }

        Window("History", id: HistoryWindow.windowID) {
            HistoryWindow(
                historyStore: appServices.historyStore,
                faviconStore: appServices.faviconStore,
                onOpen: openInBrowser
            )
        }
        .defaultSize(width: 760, height: 560)

        Settings {
            SettingsView(
                settingsStore: appServices.settingsStore,
                historyStore: appServices.historyStore
            )
        }
    }

    /// Loads a page from another window (like History) in the frontmost
    /// browser window, and brings that window forward.
    private func openInBrowser(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        appServices.externalURLRouter.enqueue([url])
        NSApp.frontmostBrowserWindow?.makeKeyAndOrderFront(nil)
    }
}
