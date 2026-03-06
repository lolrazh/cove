import SwiftUI

struct BrowserView: View {
    @StateObject private var tabManager = TabManager()

    var body: some View {
        Group {
            if let activeTab = tabManager.activeTab {
                VStack(spacing: ChromeMetrics.topChromeSpacing) {
                    topChrome(for: activeTab)
                    contentArea
                }
                .padding(ChromeMetrics.windowInset)
                .chromeWindowSurface()
            }
        }
        .animation(ChromeMotion.shell, value: tabManager.tabLayout)
        .background(ChromePalette.window)
        .frame(minWidth: 900, minHeight: 640)
        .focusedSceneValue(\.browserCommandContext, browserCommandContext)
    }

    private func topChrome(for activeTab: Tab) -> some View {
        VStack(spacing: ChromeMetrics.topChromeSpacing) {
            if tabManager.tabLayout == .horizontal {
                TabStripView(tabManager: tabManager)
            }

            NavigationBar(
                viewModel: activeTab.viewModel,
                onNavigate: { _ in
                    activeTab.isNewTabPage = false
                }
            )
            .id(activeTab.id)
        }
        .padding(ChromeMetrics.topChromePadding)
        .chromePanelSurface(.topChrome, cornerRadius: ChromeMetrics.panelCornerRadius)
        .overlay(alignment: .bottom) {
            if activeTab.viewModel.isLoading {
                ProgressView(value: activeTab.viewModel.estimatedProgress)
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
                    .labelsHidden()
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .allowsHitTesting(false)
            }
        }
    }

    private var contentArea: some View {
        ZStack(alignment: .leading) {
            activeTabContent

            if tabManager.tabLayout == .sidebar {
                SidebarTabView(tabManager: tabManager)
                    .zIndex(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .chromePanelSurface(.window, cornerRadius: ChromeMetrics.windowCornerRadius)
    }

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

    private var browserCommandContext: BrowserCommandContext {
        BrowserCommandContext(
            currentTabLayout: tabManager.tabLayout,
            showHorizontalTabs: {
                withAnimation(ChromeMotion.shell) {
                    tabManager.setLayout(.horizontal)
                }
            },
            showSidebarTabs: {
                withAnimation(ChromeMotion.shell) {
                    tabManager.setLayout(.sidebar)
                }
            }
        )
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
