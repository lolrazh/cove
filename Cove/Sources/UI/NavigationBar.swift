import SwiftUI

/// The toolbar in the page card, in top-tab mode: navigation, the address
/// field, extensions' buttons, the media player and the Library. The field only shows the URL behind
/// the site controls glyph; clicking the URL opens the Command Bar, where all
/// editing happens.
struct NavigationBar: View {
    @ObservedObject var session: TabSession
    private let tabManager: TabManager
    private let presentsSiteControls: Bool

    init(
        session: TabSession,
        tabManager: TabManager,
        presentsSiteControls: Bool
    ) {
        self._session = ObservedObject(wrappedValue: session)
        self.tabManager = tabManager
        self.presentsSiteControls = presentsSiteControls
    }

    var body: some View {
        HStack(spacing: 8) {
            NavigationControls(session: session)
            addressField
            if tabManager.isPrivate {
                PrivateBadge()
            }
            ExtensionToolbar(tabManager: tabManager)
            MediaPlayer(tabManager: tabManager, style: .compact)
            LibraryButton(library: tabManager.library, popoverEdge: .bottom)
        }
        .padding(.horizontal, 8)
        .frame(height: ChromeMetrics.navigationBarHeight)
    }

    private var addressField: some View {
        HStack(spacing: 4) {
            SiteControlsButton(tabManager: tabManager, page: session, presentsControls: presentsSiteControls)

            Text(session.currentURL.isEmpty ? "Search or enter URL" : session.currentURL)
                .foregroundStyle(session.currentURL.isEmpty ? .secondary : .primary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, 4)
        .padding(.trailing, 10)
        .padding(.vertical, 4)
        .chromeFieldStyle(focused: false)
        .contentShape(Rectangle())
        .onTapGesture(perform: tabManager.editCurrentURL)
    }
}
