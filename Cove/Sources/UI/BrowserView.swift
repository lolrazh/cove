import SwiftUI

struct BrowserView: View {
    private let appServices: AppServices
    @StateObject private var tabManager: TabManager
    @State private var areTabsVisible = true

    init(appServices: AppServices) {
        self.appServices = appServices
        self._tabManager = StateObject(
            wrappedValue: TabManager(
                settings: appServices.settingsStore,
                services: appServices.tabSessionServices
            )
        )
    }

    var body: some View {
        Group {
            if let activeTab = tabManager.activeTab {
                WindowChromeHost(tabManager: tabManager, isVisible: stripVisible) {
                    BrowserShellView(
                        appServices: appServices,
                        tabManager: tabManager,
                        activeTab: activeTab,
                        areTabsVisible: $areTabsVisible
                    ) {
                        activeTabContent
                    }
                }
            }
        }
        .background(ChromePalette.window)
        .frame(minWidth: 900, minHeight: 640)
        .focusedObject(tabManager)
        .onAppear {
            areTabsVisible = !tabManager.hideTabs
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

    // MARK: - Tab Content

    @ViewBuilder
    private var activeTabContent: some View {
        if let activeTab = tabManager.activeTab {
            ActiveTabView(tab: activeTab, appServices: appServices)
                .id(activeTab.id)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transaction { transaction in
                transaction.animation = nil
            }
        }
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
                WebViewRepresentable(webView: tab.webView)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
