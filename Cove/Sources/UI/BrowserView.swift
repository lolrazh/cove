import SwiftUI

struct BrowserView: View {
    @StateObject private var tabManager = TabManager()
    @State private var areTabsVisible = true

    var body: some View {
        Group {
            if let activeTab = tabManager.activeTab {
                WindowChromeHost(tabManager: tabManager, isVisible: stripVisible) {
                    BrowserShellView(
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
            ActiveTabView(tab: activeTab)
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

    var body: some View {
        Group {
            if tab.isNewTabPage {
                NewTabPage { input in
                    tab.navigate(input)
                }
            } else {
                WebViewRepresentable(webView: tab.webView)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
