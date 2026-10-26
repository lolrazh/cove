import SwiftUI

/// The toolbar in the page card, in top-tab mode: navigation, the address
/// field and downloads.
struct NavigationBar: View {
    @ObservedObject var session: TabSession
    @ObservedObject private var downloadManager: DownloadManager
    /// Whether Command-L and the pill reach this field. Only the address UI of
    /// the current tab mode responds, so one request can't focus two fields.
    let acceptsFocusRequests: Bool

    @State private var addressText: String
    @State private var isAddressFocused: Bool = false

    init(
        session: TabSession,
        downloadManager: DownloadManager,
        acceptsFocusRequests: Bool
    ) {
        self._session = ObservedObject(wrappedValue: session)
        self._downloadManager = ObservedObject(wrappedValue: downloadManager)
        self.acceptsFocusRequests = acceptsFocusRequests
        _addressText = State(initialValue: session.currentURL)
    }

    var body: some View {
        HStack(spacing: 8) {
            NavigationControls(session: session)
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
        // Leaving the field, by Return, Escape or a click elsewhere, shows the
        // page's URL again rather than whatever was typed.
        .onChange(of: isAddressFocused) { _, focused in
            if !focused {
                addressText = session.currentURL
            }
        }
    }

    private var addressBar: some View {
        AddressTextField(
            text: $addressText,
            isFocused: $isAddressFocused,
            placeholder: "Search or enter URL",
            focusRequest: acceptsFocusRequests ? session.addressFocusRequest : nil,
            onSubmit: { session.navigate(addressText) }
        )
        .frame(height: 18)
        .frame(maxWidth: .infinity)
        .chromeFieldStyle(focused: isAddressFocused)
    }
}
