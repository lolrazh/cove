import SwiftUI

struct BrowserView: View {
    @StateObject private var tabManager = TabManager()

    var body: some View {
        Group {
            if let activeTab = tabManager.activeTab {
                WindowChromeHost(isVisible: stripVisible) {
                    BrowserShellView(tabManager: tabManager, activeTab: activeTab) {
                        activeTabContent
                    }
                }
            }
        }
        .background(ChromePalette.window)
        .frame(minWidth: 900, minHeight: 640)
        .focusedObject(tabManager)
    }

    private var stripVisible: Bool {
        !tabManager.hideTabs || tabManager.areTabsVisible
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
    @ObservedObject var tab: Tab

    var body: some View {
        Group {
            if tab.isNewTabPage {
                NewTabPage { input in
                    tab.isNewTabPage = false
                    tab.viewModel.loadURL(input)
                }
            } else {
                WebViewRepresentable(webView: tab.viewModel.webView)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
