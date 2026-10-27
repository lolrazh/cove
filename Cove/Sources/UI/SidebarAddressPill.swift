import SwiftUI

/// Arc's URL pill at the top of the sidebar: the site's domain behind the
/// site controls glyph. Clicking the domain opens the Command Bar with the
/// full URL; nothing is edited in place.
struct SidebarAddressPill: View {
    @ObservedObject var tabManager: TabManager
    @ObservedObject var session: TabSession
    let presentsSiteControls: Bool

    var body: some View {
        HStack(spacing: 4) {
            // A note on screen in place of the page shows its title.
            if let id = tabManager.activeDocumentID, let store = tabManager.documentStore {
                DocumentLabel(id: id, store: store)
                    .padding(.leading, 4)
            } else {
                SiteControlsButton(tabManager: tabManager, page: session, presentsControls: presentsSiteControls)

                Text(domain)
                    .foregroundStyle(url == nil ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 0)
        }
        .padding(.leading, 6)
        .padding(.trailing, 10)
        .frame(height: ChromeMetrics.sidebarRowHeight)
        .chromeFieldStyle(focused: false, minimumRadius: ChromeRadius.tab)
        .contentShape(Rectangle())
        .onTapGesture(perform: tabManager.editCurrentURL)
    }

    private var url: URL? {
        session.currentURL.isEmpty ? nil : URL(string: session.currentURL)
    }

    private var domain: String {
        guard let url else { return "Search or enter URL" }
        // An extension's own page goes by the extension's name.
        if let name = session.services.context.extensions.pageName(for: url) {
            return name
        }
        return Site(url)?.domain ?? url.absoluteString
    }
}
