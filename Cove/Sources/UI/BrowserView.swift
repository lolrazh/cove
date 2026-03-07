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
        if !tabManager.tabs.isEmpty {
            ZStack {
                ForEach(tabManager.tabs) { tab in
                    ActiveTabView(tab: tab)
                        .opacity(tab.id == tabManager.activeTabID ? 1 : 0)
                        .allowsHitTesting(tab.id == tabManager.activeTabID)
                        .accessibilityHidden(tab.id != tabManager.activeTabID)
                        .zIndex(tab.id == tabManager.activeTabID ? 1 : 0)
                }
            }
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
