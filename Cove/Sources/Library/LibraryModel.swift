import SwiftUI
import Combine

/// The Library for one window: Downloads, the Archive and History. In the
/// sidebar it takes the tabs' place, as in Arc; with tabs on top it's a
/// popover from the navigation bar. Owned by the window's `TabManager`.
@MainActor
final class LibraryModel: ObservableObject {
    enum Section: CaseIterable, Identifiable {
        case downloads
        case archive
        case history

        var id: Self { self }

        var title: String {
            switch self {
            case .downloads: "Downloads"
            case .archive: "Archive"
            case .history: "History"
            }
        }
    }

    @Published private(set) var isPresented = false
    @Published var section: Section = .downloads

    let downloads: DownloadManager
    let archive: TabArchive
    let historyStore: HistoryStore
    let faviconStore: FaviconStore
    private unowned let tabManager: TabManager
    private var cancellables: Set<AnyCancellable> = []

    init(tabManager: TabManager, services: TabSessionServices, archive: TabArchive) {
        self.tabManager = tabManager
        self.downloads = services.downloadManager
        self.archive = archive
        self.historyStore = services.historyStore
        self.faviconStore = services.faviconStore

        // The Library lives somewhere else in the other layout; switching
        // closes it rather than carrying it across.
        tabManager.$tabLayout
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in self?.dismiss() }
            .store(in: &cancellables)
    }

    /// With tabs on top the Library is a popover; in the sidebar it isn't.
    var showsPopover: Bool {
        isPresented && tabManager.tabLayout == .horizontal
    }

    // MARK: - Presenting

    /// ⌘⇧L and the Library button. Opens on Downloads while something is
    /// downloading or has just finished, since that's what the button shows.
    func toggle() {
        isPresented ? dismiss() : present(downloads.hasActiveDownloads || downloads.hasUnseenDownloads ? .downloads : nil)
    }

    func present(_ section: Section? = nil) {
        if let section {
            self.section = section
        }
        isPresented = true
    }

    func dismiss() {
        isPresented = false
    }

    // MARK: - Acting

    /// Brings an archived tab back into Today, selected, with its history.
    func reopen(_ tab: ArchivedTab) {
        tabManager.reopenArchivedTab(tab.id)
    }

    func open(_ url: String) {
        tabManager.addTab(url: url)
    }

    /// Visits newest first, each page once at its latest visit, by day.
    func history(matching query: String) -> [HistoryDay] {
        var seen = Set<String>()
        let visits = historyStore.search(query: query, limit: 500).filter { seen.insert($0.url).inserted }
        return HistoryDay.group(Array(visits.prefix(Self.historyLimit)))
    }

    /// Enough for the sidebar; the History window holds the rest.
    private static let historyLimit = 150

    func copyLink(_ url: String) {
        tabManager.copyLink(url)
    }
}
