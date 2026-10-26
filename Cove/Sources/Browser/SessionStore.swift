import AppKit
import Combine

/// A tab as it's saved between launches. The interaction state is WebKit's
/// opaque copy of the back/forward list, so restored tabs can still go back.
struct SavedTab: Codable {
    let url: String
    let title: String
    let interactionState: Data?
}

struct SavedWindow: Codable {
    let tabs: [SavedTab]
    let activeTabIndex: Int
}

/// Saves every browser window's tabs shortly after they change, and hands them
/// back on the next launch, one saved window to each window that opens.
@MainActor
final class SessionStore {
    private struct TrackedWindow {
        weak var tabManager: TabManager?
        let changes: AnyCancellable
    }

    private let fileURL: URL
    private var restorableWindows: [SavedWindow]
    private var trackedWindows: [TrackedWindow] = []
    private var pendingSave: Task<Void, Never>?
    private var terminationObserver: NSObjectProtocol?

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        fileURL = appSupport.appendingPathComponent("Cove/session.plist")
        restorableWindows = (try? Data(contentsOf: fileURL))
            .flatMap { try? PropertyListDecoder().decode([SavedWindow].self, from: $0) } ?? []

        // A change in the last second before quitting would miss the debounce.
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.save() }
        }
    }

    /// The next window saved last session, if any are left to restore.
    func takeRestorableWindow() -> SavedWindow? {
        restorableWindows.isEmpty ? nil : restorableWindows.removeFirst()
    }

    /// Saves the window whenever its tabs, active tab or any tab's page change.
    func track(_ tabManager: TabManager) {
        let tabsChanged = tabManager.$tabs
            .map { tabs in Publishers.MergeMany(tabs.map { $0.$currentURL.map { _ in } }) }
            .switchToLatest()
        let changes = Publishers.Merge(tabsChanged, tabManager.$activeTabID.map { _ in })
            .sink { [weak self] in self?.scheduleSave() }
        trackedWindows.append(TrackedWindow(tabManager: tabManager, changes: changes))
    }

    /// A closed window's tabs are forgotten, except the last window's: closing
    /// it quits Cove, and its tabs come back next launch like after any quit.
    func untrack(_ tabManager: TabManager) {
        trackedWindows.removeAll { $0.tabManager == nil }
        guard trackedWindows.count > 1 else { return }
        trackedWindows.removeAll { $0.tabManager === tabManager }
        scheduleSave()
    }

    private func scheduleSave() {
        pendingSave?.cancel()
        pendingSave = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            self?.save()
        }
    }

    private func save() {
        pendingSave?.cancel()
        let windows = trackedWindows.compactMap { $0.tabManager?.savedWindow }
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        guard let data = try? encoder.encode(windows) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
