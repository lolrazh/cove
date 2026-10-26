import SwiftUI

/// Arc's URL pill at the top of the sidebar: the site's domain at rest, and the
/// full URL, editable in place, after a click or Command-L.
///
/// Clicking only calls `session.requestAddressFocus()`. That is the one way into
/// editing, so the Command Bar can take the pill over later by rerouting it.
struct SidebarAddressPill: View {
    @ObservedObject var session: TabSession
    @Binding var isEditing: Bool
    /// Whether this pill is the one Command-L reaches; see `AddressTextField`.
    let acceptsFocusRequests: Bool

    @State private var addressText: String

    init(session: TabSession, isEditing: Binding<Bool>, acceptsFocusRequests: Bool) {
        self._session = ObservedObject(wrappedValue: session)
        self._isEditing = isEditing
        self.acceptsFocusRequests = acceptsFocusRequests
        _addressText = State(initialValue: session.currentURL)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            domainLabel
                .opacity(isEditing ? 0 : 1)

            AddressTextField(
                text: $addressText,
                isFocused: $isEditing,
                placeholder: "Search or enter URL",
                focusRequest: acceptsFocusRequests ? session.addressFocusRequest : nil,
                onSubmit: { session.navigate(addressText) }
            )
            .opacity(isEditing ? 1 : 0)
            .allowsHitTesting(isEditing)
        }
        .padding(.horizontal, 10)
        .frame(height: ChromeMetrics.sidebarRowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .chromeFieldStyle(focused: isEditing, minimumRadius: ChromeRadius.tab)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isEditing { session.requestAddressFocus() }
        }
        .onChange(of: session.currentURL) { _, newURL in
            if !isEditing {
                addressText = newURL
            }
        }
        // Leaving the field, by Return, Escape or a click elsewhere, shows the
        // page's URL again rather than whatever was typed.
        .onChange(of: isEditing) { _, editing in
            if !editing {
                addressText = session.currentURL
            }
        }
    }

    private var domainLabel: some View {
        HStack(spacing: 8) {
            Image(systemName: glyph)
                .foregroundStyle(.secondary)

            Text(domain)
                .foregroundStyle(url == nil ? .secondary : .primary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private var url: URL? {
        session.currentURL.isEmpty ? nil : URL(string: session.currentURL)
    }

    private var domain: String {
        guard let url else { return "Search or enter URL" }
        guard let host = url.host() else { return url.absoluteString }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    private var glyph: String {
        switch url?.scheme {
        case nil: ChromeSymbols.Navigation.search
        case "https": ChromeSymbols.Navigation.secure
        default: ChromeSymbols.Navigation.globe
        }
    }
}
