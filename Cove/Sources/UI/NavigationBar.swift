import SwiftUI

/// The toolbar in the page card, in top-tab mode: navigation, the address
/// field, the media player and downloads. The field only shows the URL; clicking it opens the
/// Command Bar, where all editing happens.
struct NavigationBar: View {
    @ObservedObject var session: TabSession
    private let tabManager: TabManager
    @ObservedObject private var downloadManager: DownloadManager

    init(
        session: TabSession,
        tabManager: TabManager,
        downloadManager: DownloadManager
    ) {
        self._session = ObservedObject(wrappedValue: session)
        self.tabManager = tabManager
        self._downloadManager = ObservedObject(wrappedValue: downloadManager)
    }

    var body: some View {
        HStack(spacing: 8) {
            NavigationControls(session: session)
            addressField
            MediaPlayer(tabManager: tabManager, style: .compact)
            DownloadsStatusButton(downloadManager: downloadManager)
        }
        .padding(.horizontal, 8)
        .frame(height: ChromeMetrics.navigationBarHeight)
    }

    private var addressField: some View {
        Text(session.currentURL.isEmpty ? "Search or enter URL" : session.currentURL)
            .foregroundStyle(session.currentURL.isEmpty ? .secondary : .primary)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(height: 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .chromeFieldStyle(focused: false)
            .contentShape(Rectangle())
            .onTapGesture(perform: tabManager.editCurrentURL)
    }
}
