import SwiftUI

/// Arc's URL pill at the top of the sidebar: the site's domain behind a lock,
/// globe or search glyph. Clicking it opens the Command Bar with the full URL;
/// nothing is edited in place.
struct SidebarAddressPill: View {
    @ObservedObject var session: TabSession
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: glyph)
                .foregroundStyle(.secondary)

            Text(domain)
                .foregroundStyle(url == nil ? .secondary : .primary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(height: ChromeMetrics.sidebarRowHeight)
        .chromeFieldStyle(focused: false, minimumRadius: ChromeRadius.tab)
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
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
