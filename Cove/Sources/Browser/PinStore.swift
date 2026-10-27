import AppKit
import Combine

/// Keeps the pinned tabs and favorites between launches, apart from the Today
/// session: every space's layout, and each pin's live tab (its current page
/// and back/forward list) so a pinned tab comes back where it was left. One
/// store for the app; every window shows the same pins with live tabs of its
/// own. Without a file it keeps nothing, which is what a private window wants.
@MainActor
final class PinStore: ObservableObject {
    @Published private(set) var layout: PinLayout

    private struct SavedPins: Codable {
        var layout: PinLayout
        var tabs: [String: SavedTab]
    }

    /// Saved before Spaces: one set of pins, now the first space's and the
    /// default profile's.
    private struct UnscopedPins: Decodable {
        var pins: Pins
        var tabs: [String: SavedTab]

        var scoped: SavedPins {
            var layout = PinLayout()
            layout[.default] = pins
            return SavedPins(layout: layout, tabs: tabs)
        }
    }

    private let fileURL: URL?
    /// The live tab behind each pin, by the pin's ID, as last recorded.
    private var tabs: [String: SavedTab]
    private var pendingSave: Task<Void, Never>?
    private var terminationObserver: NSObjectProtocol?

    init(fileURL: URL? = PinStore.defaultFileURL) {
        self.fileURL = fileURL
        let decoder = PropertyListDecoder()
        let saved = StoreFile.read(fileURL) { data in
            (try? decoder.decode(SavedPins.self, from: data))
                ?? (try? decoder.decode(UnscopedPins.self, from: data))?.scoped
        }
        layout = saved?.layout ?? PinLayout()
        tabs = saved?.tabs ?? [:]

        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.save() }
        }
    }

    static var defaultFileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Cove/pins.plist")
    }

    /// One space's pins.
    func pins(in scope: PinScope) -> Pins {
        layout[scope]
    }

    /// Changes one space's pins: one publish and one save per change, however
    /// much it does.
    func change(in scope: PinScope, _ change: (inout Pins) -> Void) {
        self.change { change(&$0[scope]) }
    }

    /// Changes the layout. The tabs of pins that are gone are forgotten.
    func change(_ change: (inout PinLayout) -> Void) {
        var layout = layout
        change(&layout)
        guard layout != self.layout else { return }
        self.layout = layout
        let kept = Set(layout.all.map(\.id.uuidString))
        tabs = tabs.filter { kept.contains($0.key) }
        scheduleSave()
    }

    /// The live tab behind a pin, as it was last recorded.
    func savedTab(for id: UUID) -> SavedTab? {
        tabs[id.uuidString]
    }

    /// Remembers where a pin's live tab is, for the next launch.
    func record(_ tab: SavedTab, for id: UUID) {
        guard layout.pin(id) != nil else { return }
        tabs[id.uuidString] = tab
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

    /// Saves now. Changes otherwise save a second after the last of them.
    func save() {
        pendingSave?.cancel()
        guard let fileURL else { return }
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        guard let data = try? encoder.encode(SavedPins(layout: layout, tabs: tabs)) else { return }
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }
}
