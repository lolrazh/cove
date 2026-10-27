import SwiftUI

/// The toolbar in the page card, in top-tab mode: navigation, the address
/// field, the media player and downloads. The field only shows the URL behind
/// the site controls glyph; clicking the URL opens the Command Bar, where all
/// editing happens.
struct NavigationBar: View {
    @ObservedObject var session: TabSession
    private let tabManager: TabManager
    @ObservedObject private var downloadManager: DownloadManager
    private let presentsSiteControls: Bool

    init(
        session: TabSession,
        tabManager: TabManager,
        downloadManager: DownloadManager,
        presentsSiteControls: Bool
    ) {
        self._session = ObservedObject(wrappedValue: session)
        self.tabManager = tabManager
        self._downloadManager = ObservedObject(wrappedValue: downloadManager)
        self.presentsSiteControls = presentsSiteControls
    }

    var body: some View {
        HStack(spacing: 8) {
            NavigationControls(session: session)
            addressField
            if tabManager.isPrivate {
                PrivateBadge()
            }
            MediaPlayer(tabManager: tabManager, style: .compact)
            DownloadsStatusButton(downloadManager: downloadManager)
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
