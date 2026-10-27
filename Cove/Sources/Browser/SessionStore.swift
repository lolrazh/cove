import AppKit
import Combine

/// A tab as it's saved between launches. The interaction state is WebKit's
/// opaque copy of the back/forward list, so restored tabs can still go back.
struct SavedTab: Codable {
    let url: String
    let title: String
    /// The user's name for the tab. Absent in sessions saved before renaming.
    let customTitle: String?
    let interactionState: Data?
    /// When the tab was last looked at, so idle time survives a relaunch.
    /// Unknown counts as now.
    let lastUsedAt: Date?
}

/// One space's Today in a window, and the tab it had selected.
struct SavedSpace: Codable {
    let spaceID: UUID
    let tabs: [SavedTab]
    /// The selected tab, if it was one of `tabs`.
    let activeTabIndex: Int?
    /// The selected tab, if it was a pinned tab or favorite: its pin's ID.
    let activePinID: UUID?
}

/// A window: every space's Today as it was left there, and the space shown.
struct SavedWindow: Codable {
    let spaces: [SavedSpace]
    let activeSpaceID: UUID
    var placement: WindowPlacement?

    init(spaces: [SavedSpace], activeSpaceID: UUID) {
        self.spaces = spaces
        self.activeSpaceID = activeSpaceID
    }

    private enum UnscopedKeys: String, CodingKey {
        case tabs, activeTabIndex
    }

    /// A window saved before Spaces had one Today, which is the first space's.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        placement = try container.decodeIfPresent(WindowPlacement.self, forKey: .placement)
        if let spaces = try container.decodeIfPresent([SavedSpace].self, forKey: .spaces) {
            self.spaces = spaces
            activeSpaceID = try container.decode(UUID.self, forKey: .activeSpaceID)
        } else {
            let unscoped = try decoder.container(keyedBy: UnscopedKeys.self)
            spaces = [SavedSpace(
                spaceID: Space.defaultID,
                tabs: try unscoped.decode([SavedTab].self, forKey: .tabs),
                activeTabIndex: try unscoped.decode(Int.self, forKey: .activeTabIndex),
                activePinID: nil
            )]
            activeSpaceID = Space.defaultID
        }
    }
}

/// Where a window was on screen. The frame is the window's size outside full
/// screen, so leaving full screen after a restore returns to it.
struct WindowPlacement: Codable {
    let frame: CGRect
    let isFullScreen: Bool

    /// Puts the window back, fully on a connected screen. A window whose display
    /// is gone is centered on the primary screen.
    @MainActor
    func restore(_ window: NSWindow) {
        var frame = frame
        let screen = NSScreen.screens.first { $0.visibleFrame.intersects(frame) }
        if let visible = (screen ?? NSScreen.screens.first)?.visibleFrame {
            frame.size.width = min(frame.width, visible.width)
            frame.size.height = min(frame.height, visible.height)
            if screen == nil {
                frame.origin = CGPoint(x: visible.midX - frame.width / 2, y: visible.midY - frame.height / 2)
            }
            frame.origin.x = min(max(frame.minX, visible.minX), visible.maxX - frame.width)
            frame.origin.y = min(max(frame.minY, visible.minY), visible.maxY - frame.height)
        }
        window.setFrame(frame, display: true)
        if isFullScreen {
            window.toggleFullScreen(nil)
        }
    }
}

/// Saves every browser window's tabs shortly after they change, and hands them
/// back on the next launch, one saved window to each window that opens. Cove
/// reopens the windows itself (SwiftUI's window restoration is off for them),
/// so all of them come back however macOS is set to treat windows on quit.
@MainActor
final class SessionStore {
    private struct TrackedWindow {
        weak var tabManager: TabManager?
        weak var window: NSWindow?
        /// Where the window was, as restored or last saved: it holds the frame
        /// outside full screen while the window is in full screen.
        var placement: WindowPlacement?
        let changes: AnyCancellable
    }

    private let fileURL: URL
    private var restorableWindows: [SavedWindow]
    private var didReopenWindows = false
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
            MainActor.assumeIsolated {
                self?.save()
                // Windows close after this, and the saved session must keep them.
                self?.trackedWindows.removeAll()
            }
        }
    }

    /// The next window saved last session, if any are left to restore.
    func takeRestorableWindow() -> SavedWindow? {
        restorableWindows.isEmpty ? nil : restorableWindows.removeFirst()
    }

    /// How many more windows to open for the rest of the saved session: nonzero
    /// only for the first window to ask, so reopened windows don't reopen more.
    func takeWindowsToReopen() -> Int {
        guard !didReopenWindows else { return 0 }
        didReopenWindows = true
        return restorableWindows.count
    }

    /// Saves the window whenever its tabs, active tab, space or any saved tab
    /// change. A restored window's placement applies once its window is known.
    func track(_ tabManager: TabManager, placement: WindowPlacement?) {
        let tabsChanged = tabManager.$tabs
            .map { tabs in Publishers.MergeMany(tabs.map(\.savedTabChanges)) }
            .switchToLatest()
        let changes = Publishers.Merge3(tabsChanged, tabManager.$activeTabID.map { _ in }, tabManager.$activeSpaceID.map { _ in })
            .sink { [weak self] in self?.scheduleSave() }
        trackedWindows.append(TrackedWindow(tabManager: tabManager, placement: placement, changes: changes))
    }

    /// Learns the window showing these tabs, and puts it back where it was.
    func attach(_ window: NSWindow, to tabManager: TabManager) {
        guard let index = trackedWindows.firstIndex(where: { $0.tabManager === tabManager }),
              trackedWindows[index].window == nil else { return }
        trackedWindows[index].window = window
        // SwiftUI places a new window after it's attached; this runs after that.
        guard let placement = trackedWindows[index].placement else { return }
        DispatchQueue.main.async {
            placement.restore(window)
        }
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

    /// Full screen fills the screen, so the frame from before it is kept.
    private func recordPlacement(at index: Int) {
        guard let window = trackedWindows[index].window else { return }
        let isFullScreen = window.styleMask.contains(.fullScreen)
        let frame = isFullScreen ? trackedWindows[index].placement?.frame : window.frame
        trackedWindows[index].placement = frame.map { WindowPlacement(frame: $0, isFullScreen: isFullScreen) }
    }

    private func save() {
        pendingSave?.cancel()
        let windows = trackedWindows.indices.compactMap { index -> SavedWindow? in
            recordPlacement(at: index)
            guard var saved = trackedWindows[index].tabManager?.savedWindow else { return nil }
            saved.placement = trackedWindows[index].placement
            return saved
        }
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        guard let data = try? encoder.encode(windows) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
