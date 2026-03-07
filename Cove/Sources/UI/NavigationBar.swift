import SwiftUI

struct NavigationBar: View {
    @ObservedObject var session: TabSession

    @State private var addressText: String
    @State private var showHistory: Bool = false
    @FocusState private var isAddressFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(session: TabSession) {
        self._session = ObservedObject(wrappedValue: session)
        _addressText = State(initialValue: session.currentURL)
    }

    var body: some View {
        HStack(spacing: 8) {
            navCluster
            addressBar
            utilityCluster
        }
        .onChange(of: session.currentURL) { _, newURL in
            if !isAddressFocused {
                addressText = newURL
            }
        }
    }

    private var navCluster: some View {
        HStack(spacing: 4) {
            toolbarButton(enabled: session.canGoBack, action: session.goBack) {
                Image(systemName: ChromeSymbols.Navigation.back)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(session.canGoBack ? .primary : .tertiary)
            }

            toolbarButton(enabled: session.canGoForward, action: session.goForward) {
                Image(systemName: ChromeSymbols.Navigation.forward)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(session.canGoForward ? .primary : .tertiary)
            }

            toolbarButton(action: {
                session.isLoading ? session.stopLoading() : session.reload()
            }) {
                reloadIcon
                    .foregroundStyle(.primary)
            }
        }
    }

    private var addressBar: some View {
        HStack(spacing: 8) {
            FaviconView(image: session.favicon, size: 14)

            TextField("Search or enter URL", text: $addressText)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .regular, design: .default))
                .focused($isAddressFocused)
                .onSubmit {
                    session.navigate(addressText)
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
                        session.navigate(url)
                    },
                    onDismiss: { showHistory = false }
                )
            }
        }
    }

    private var reloadIcon: some View {
        let icon = Image(systemName: session.isLoading ? ChromeSymbols.Navigation.stop : ChromeSymbols.Navigation.reload)
            .font(.system(size: 13, weight: .medium))

        return Group {
            if reduceMotion {
                icon
            } else {
                icon.symbolEffect(.bounce, value: session.isLoading)
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
