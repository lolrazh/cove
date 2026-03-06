import SwiftUI

struct NavigationBar: View {
    @ObservedObject var viewModel: WebViewModel
    @ObservedObject var tabManager: TabManager
    var onNavigate: ((String) -> Void)?

    @State private var addressText: String
    @State private var showHistory: Bool = false
    @State private var showDownloads: Bool = false
    @ObservedObject private var downloadManager = DownloadManager.shared
    @FocusState private var isAddressFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(viewModel: WebViewModel, tabManager: TabManager, onNavigate: ((String) -> Void)? = nil) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self._tabManager = ObservedObject(wrappedValue: tabManager)
        self.onNavigate = onNavigate
        _addressText = State(initialValue: viewModel.currentURL)
    }

    var body: some View {
        HStack(spacing: 8) {
            if tabManager.tabLayout == .sidebar {
                toolbarButton(
                    isSelected: tabManager.isSidebarVisible,
                    action: tabManager.revealSidebar
                ) {
                    Image(systemName: ChromeSymbols.Navigation.sidebar)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(tabManager.isSidebarVisible ? .primary : .secondary)
                }
                .help("Reveal sidebar")
            }

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
            if !downloadManager.items.isEmpty {
                toolbarButton(action: { showDownloads.toggle() }) {
                    VStack(spacing: 3) {
                        downloadsIcon
                            .foregroundStyle(.primary)

                        if downloadManager.hasActiveDownloads {
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(ChromePalette.fieldStroke)
                                    Capsule()
                                        .fill(Color.accentColor)
                                        .frame(width: geometry.size.width * downloadManager.overallProgress)
                                        .animation(ChromeMotion.loading, value: downloadManager.overallProgress)
                                }
                            }
                            .frame(width: 18, height: 4)
                        } else {
                            Spacer()
                                .frame(height: 4)
                        }
                    }
                }
                .popover(isPresented: $showDownloads, arrowEdge: .bottom) {
                    DownloadPopover(manager: downloadManager)
                }
            }

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

    private var downloadsIcon: some View {
        let icon = Image(
            systemName: downloadManager.hasActiveDownloads
                ? ChromeSymbols.Navigation.downloadsActive
                : ChromeSymbols.Navigation.downloads
        )
        .font(.system(size: 13, weight: .medium))

        return Group {
            if reduceMotion {
                icon
            } else {
                icon.symbolEffect(.bounce, value: downloadManager.items.count)
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
