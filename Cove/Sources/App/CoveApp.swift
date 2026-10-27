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
        WindowGroup(id: BrowserView.windowID) {
            BrowserView(appServices: appServices)
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unifiedCompact)
        .windowBackgroundDragBehavior(.enabled)
        // `SessionStore` reopens browser windows, with their tabs.
        .restorationBehavior(.disabled)
        .commands {
            BrowserViewCommands(appServices: appServices)
            TabCommands()
        }

        Window("History", id: HistoryWindow.windowID) {
            HistoryWindow(
                historyStore: appServices.historyStore,
                faviconStore: appServices.faviconStore,
                onOpen: openInBrowser
            )
        }
        .defaultSize(width: 760, height: 560)
        .handlesExternalEvents(matching: [])
        .restorationBehavior(.disabled)

        Settings {
            SettingsView(
                settingsStore: appServices.settingsStore,
                historyStore: appServices.historyStore
            )
        }
    }

    /// Loads a page from another window (like History) in the browser window
    /// that was active last.
    private func openInBrowser(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        appServices.externalURLRouter.open([url])
    }
}
