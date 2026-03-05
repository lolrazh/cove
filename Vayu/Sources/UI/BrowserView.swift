import SwiftUI

struct BrowserView: View {
    @StateObject private var viewModel = WebViewModel()

    var body: some View {
        VStack(spacing: 0) {
            NavigationBar(viewModel: viewModel)

            // Progress bar
            if viewModel.isLoading {
                ProgressView(value: viewModel.estimatedProgress)
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
            }

            WebViewRepresentable(webView: viewModel.webView)
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}
