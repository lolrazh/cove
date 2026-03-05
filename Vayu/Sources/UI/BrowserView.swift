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
        if let tab = tabManager.activeTab {
            NavigationBar(viewModel: tab.viewModel)

            if tab.viewModel.isLoading {
                ProgressView(value: tab.viewModel.estimatedProgress)
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
                    .transition(.opacity)
            }

            WebViewRepresentable(webView: tab.viewModel.webView)
                .id(tab.id)
        }
    }
}
