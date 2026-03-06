import SwiftUI

struct NavigationBar: View {
    @ObservedObject var viewModel: WebViewModel
    var onNavigate: ((String) -> Void)?

    @State private var addressText: String
    @State private var showHistory: Bool = false
    @ObservedObject private var downloadManager = DownloadManager.shared
    @FocusState private var isAddressFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(viewModel: WebViewModel, onNavigate: ((String) -> Void)? = nil) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self.onNavigate = onNavigate
        _addressText = State(initialValue: viewModel.currentURL)
    }

    var body: some View {
        HStack(spacing: 8) {
            navCluster
            addressBar
            utilityCluster
        }
        .onChange(of: viewModel.currentURL) { _, newURL in
            if !isAddressFocused {
                addressText = newURL
            }
        }
    }

    private var navCluster: some View {
        HStack(spacing: 4) {
            toolbarButton(enabled: viewModel.canGoBack, action: viewModel.goBack) {
                Image(systemName: ChromeSymbols.Navigation.back)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(viewModel.canGoBack ? .primary : .tertiary)
            }

            toolbarButton(enabled: viewModel.canGoForward, action: viewModel.goForward) {
                Image(systemName: ChromeSymbols.Navigation.forward)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(viewModel.canGoForward ? .primary : .tertiary)
            }

            toolbarButton(action: {
                viewModel.isLoading ? viewModel.stopLoading() : viewModel.reload()
            }) {
                reloadIcon
                    .foregroundStyle(.primary)
            }
        }
    }

    private var addressBar: some View {
        HStack(spacing: 8) {
            FaviconView(image: viewModel.favicon, size: 14)

            TextField("Search or enter URL", text: $addressText)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .regular, design: .default))
                .focused($isAddressFocused)
                .onSubmit {
                    onNavigate?(addressText)
                    viewModel.loadURL(addressText)
                    isAddressFocused = false
                }
        }
        .frame(maxWidth: .infinity)
        .chromeFieldStyle(focused: isAddressFocused, prominence: .regular)
    }

    private var utilityCluster: some View {
        HStack(spacing: 4) {
            DownloadsStatusButton()

            toolbarButton(action: { showHistory.toggle() }) {
                Image(systemName: ChromeSymbols.Navigation.history)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .popover(isPresented: $showHistory, arrowEdge: .bottom) {
                HistoryView(
                    onNavigate: { url in
                        onNavigate?(url)
                        viewModel.loadURL(url)
                    },
                    onDismiss: { showHistory = false }
                )
            }
        }
    }

    private var reloadIcon: some View {
        let icon = Image(systemName: viewModel.isLoading ? ChromeSymbols.Navigation.stop : ChromeSymbols.Navigation.reload)
            .font(.system(size: 13, weight: .medium))

        return Group {
            if reduceMotion {
                icon
            } else {
                icon.symbolEffect(.bounce, value: viewModel.isLoading)
            }
        }
    }

    private func toolbarButton<Label: View>(
        enabled: Bool = true,
        isSelected: Bool = false,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) -> some View {
        Button(action: action) {
            label()
        }
        .disabled(!enabled)
        .buttonStyle(ChromeButtonStyle(kind: .toolbar, isSelected: isSelected))
    }
}
