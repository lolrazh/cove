import SwiftUI

struct BrowserView: View {
    static let windowID = "browser"
    static let privateWindowID = "private"

    private let appServices: AppServices
    @ObservedObject private var settings: BrowserSettingsStore
    @StateObject private var tabManager: TabManager
    @State private var areTabsVisible = true
    @Environment(\.appearsActive) private var appearsActive
    @Environment(\.openWindow) private var openWindow

    init(appServices: AppServices, isPrivate: Bool = false) {
        self.appServices = appServices
        self._settings = ObservedObject(wrappedValue: appServices.settingsStore)
        self._tabManager = StateObject(wrappedValue: Self.makeTabManager(appServices: appServices, isPrivate: isPrivate))
    }

    /// A normal window browses with the shared context and is saved with the
    /// session. A private window gets a context of its own and keeps nothing:
    /// no session, no pins, and an archive of its own, in memory, for its
    /// closed tabs.
    private static func makeTabManager(appServices: AppServices, isPrivate: Bool) -> TabManager {
        let context = isPrivate ? BrowsingContext.makePrivate(over: appServices.browsingContext) : appServices.browsingContext
        return TabManager(
            settings: appServices.settingsStore,
            services: appServices.tabSessionServices(in: context),
            archive: isPrivate ? TabArchive(directory: nil) : appServices.tabArchive,
            pins: isPrivate ? PinStore(fileURL: nil) : appServices.pinStore,
            session: isPrivate ? nil : appServices.sessionStore
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
                    .overlay {
                        CommandBarOverlay(model: tabManager.commandBar)
                    }
                }
            }
        }
        .background(ChromePalette.shell)
        .environment(\.chromeTheme, tabManager.isPrivate ? .privateBrowsing : settings.theme)
        .frame(minWidth: 900, minHeight: 640)
        .focusedSceneObject(tabManager)
        .onAppear {
            areTabsVisible = !tabManager.hideTabs
            guard !tabManager.isPrivate else { return }
            for _ in 0..<appServices.sessionStore.takeWindowsToReopen() {
                openWindow(id: Self.windowID)
            }
        }
        .onDisappear {
            guard !tabManager.isPrivate else { return }
            appServices.sessionStore.untrack(tabManager)
        }
        // Tells the router which window was active last, so links from other
        // apps and from History land here only if this is it. They never land
        // in a private window.
        .onChange(of: appearsActive, initial: true) { _, active in
            guard active, !tabManager.isPrivate, let window = NSApp.keyWindow else { return }
            appServices.externalURLRouter.activate(tabManager, in: window)
        }
        // Links from other apps come to an open window instead of each opening
        // a new one (SwiftUI opens one only if none exists), then go through
        // the router like everything else.
        .handlesExternalEvents(preferring: externalEvents, allowing: externalEvents)
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

    private var externalEvents: Set<String> {
        tabManager.isPrivate ? [] : ["*"]
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
            } else if case .awake(let webView) = tab.page {
                // Only the selected tab is shown, and it's always awake.
                WebViewRepresentable(webView: webView, onAppear: tab.pageDidAppear)
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
