import SwiftUI

struct BrowserView: View {
    static let windowID = "browser"

    private let appServices: AppServices
    @StateObject private var tabManager: TabManager
    @State private var areTabsVisible = true
    @Environment(\.appearsActive) private var appearsActive
    @Environment(\.openWindow) private var openWindow

    init(appServices: AppServices) {
        self.appServices = appServices
        self._tabManager = StateObject(
            wrappedValue: TabManager(
                settings: appServices.settingsStore,
                services: appServices.tabSessionServices,
                recentlyClosed: appServices.recentlyClosedTabs,
                session: appServices.sessionStore
            )
        )
    }

    var body: some View {
        Group {
            if let activeTab = tabManager.activeTab {
                WindowChromeHost(showsTrafficLights: stripVisible) { window in
                    appServices.sessionStore.attach(window, to: tabManager)
                } content: {
                    BrowserShellView(
                        appServices: appServices,
                        tabManager: tabManager,
                        activeTab: activeTab,
                        areTabsVisible: $areTabsVisible
                    ) {
                        activeTabContent(activeTab)
                    }
                }
            }
        }
        .background(ChromePalette.shell)
        .frame(minWidth: 900, minHeight: 640)
        .focusedSceneObject(tabManager)
        .onAppear {
            areTabsVisible = !tabManager.hideTabs
            for _ in 0..<appServices.sessionStore.takeWindowsToReopen() {
                openWindow(id: Self.windowID)
            }
        }
        .onDisappear {
            appServices.sessionStore.untrack(tabManager)
        }
        // Tells the router which window was active last, so links from other
        // apps and from History land here only if this is it.
        .onChange(of: appearsActive, initial: true) { _, active in
            guard active, let window = NSApp.keyWindow else { return }
            appServices.externalURLRouter.activate(tabManager, in: window)
        }
        // Links from other apps come to an open window instead of each opening
        // a new one (SwiftUI opens one only if none exists), then go through
        // the router like everything else.
        .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
        .onOpenURL { url in
            appServices.externalURLRouter.open([url])
        }
        .onChange(of: tabManager.hideTabs) { _, hide in
            withAnimation(ChromeMotion.shell) {
                areTabsVisible = !hide
            }
        }
        .onChange(of: tabManager.tabLayout) { _, _ in
            withAnimation(ChromeMotion.shell) {
                areTabsVisible = !tabManager.hideTabs
            }
        }
    }

    private var stripVisible: Bool {
        !tabManager.hideTabs || areTabsVisible
    }

    private func activeTabContent(_ tab: TabSession) -> some View {
        ActiveTabView(tab: tab, appServices: appServices)
            .id(tab.id)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transaction { $0.animation = nil }
    }
}

struct ActiveTabView: View {
    @ObservedObject var tab: TabSession
    private let appServices: AppServices

    init(tab: TabSession, appServices: AppServices) {
        self._tab = ObservedObject(wrappedValue: tab)
        self.appServices = appServices
    }

    var body: some View {
        Group {
            if tab.isNewTabPage {
                NewTabPage(
                    settingsStore: appServices.settingsStore,
                    historyStore: appServices.historyStore,
                    faviconStore: appServices.faviconStore
                ) { input in
                    tab.navigate(input)
                }
            } else {
                WebViewRepresentable(tab: tab)
                    .overlay {
                        if let failure = tab.loadFailure {
                            LoadFailurePage(failure: failure, onRetry: tab.retry)
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
