import SwiftUI

struct BrowserView: View {
    @StateObject private var tabManager = TabManager()

    var body: some View {
        VStack(spacing: 0) {
            TabStripView(tabManager: tabManager)

            if let tab = tabManager.activeTab {
                NavigationBar(viewModel: tab.viewModel)

                if tab.viewModel.isLoading {
                    ProgressView(value: tab.viewModel.estimatedProgress)
                        .progressViewStyle(.linear)
                        .tint(.accentColor)
                }

                WebViewRepresentable(webView: tab.viewModel.webView)
                    .id(tab.id)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}
