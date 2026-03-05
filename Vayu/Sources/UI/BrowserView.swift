import SwiftUI

struct BrowserView: View {
    @StateObject private var tabManager = TabManager()

    var body: some View {
        Group {
            switch tabManager.tabLayout {
            case .horizontal:
                horizontalLayout
            case .sidebar:
                sidebarLayout
            }
        }
        .animation(.easeInOut(duration: 0.25), value: tabManager.tabLayout)
        .frame(minWidth: 800, minHeight: 600)
    }

    private var horizontalLayout: some View {
        VStack(spacing: 0) {
            TabStripView(tabManager: tabManager)
            activeTabContent
        }
    }

    private var sidebarLayout: some View {
        HStack(spacing: 0) {
            SidebarTabView(tabManager: tabManager)
            VStack(spacing: 0) {
                activeTabContent
            }
        }
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
}

struct ActiveTabView: View {
    @ObservedObject var tab: Tab

    var body: some View {
        VStack(spacing: 0) {
            NavigationBar(viewModel: tab.viewModel, onNavigate: { _ in
                tab.isNewTabPage = false
            })
            .overlay(alignment: .bottom) {
                if tab.viewModel.isLoading {
                    ProgressView(value: tab.viewModel.estimatedProgress)
                        .progressViewStyle(.linear)
                        .tint(.accentColor)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                        .allowsHitTesting(false)
                }
            }

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
