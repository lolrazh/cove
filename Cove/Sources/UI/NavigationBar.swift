import SwiftUI

struct NavigationBar: View {
    @ObservedObject var session: TabSession
    @ObservedObject private var downloadManager: DownloadManager

    @State private var addressText: String
    @State private var isAddressFocused: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        session: TabSession,
        downloadManager: DownloadManager
    ) {
        self._session = ObservedObject(wrappedValue: session)
        self._downloadManager = ObservedObject(wrappedValue: downloadManager)
        _addressText = State(initialValue: session.currentURL)
    }

    var body: some View {
        HStack(spacing: 8) {
            navCluster
            addressBar
            DownloadsStatusButton(downloadManager: downloadManager)
        }
        .padding(.horizontal, 8)
        .frame(height: ChromeMetrics.navigationBarHeight)
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
                    .foregroundStyle(session.canGoBack ? .primary : .tertiary)
            }

            toolbarButton(enabled: session.canGoForward, action: session.goForward) {
                Image(systemName: ChromeSymbols.Navigation.forward)
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
        AddressTextField(
            text: $addressText,
            isFocused: $isAddressFocused,
            placeholder: "Search or enter URL",
            focusRequest: session.addressFocusRequest,
            onSubmit: submitAddress
        )
        .frame(height: 18)
        .frame(maxWidth: .infinity)
        .chromeFieldStyle(focused: isAddressFocused)
    }

    private var reloadIcon: some View {
        let icon = Image(systemName: session.isLoading ? ChromeSymbols.Navigation.stop : ChromeSymbols.Navigation.reload)

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
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) -> some View {
        Button(action: action) {
            label()
        }
        .disabled(!enabled)
        .buttonStyle(ChromeButtonStyle())
    }

    private func submitAddress() {
        session.navigate(addressText)
        isAddressFocused = false
    }
}
