import Foundation
import WebKit

/// Keeps the spaces and profiles between launches, and each profile's
/// browsing context while Cove runs. One store for the app: every window
/// shows the same spaces, each window one of them at a time.
@MainActor
final class SpaceStore: ObservableObject {
    @Published private(set) var spaces: Spaces

    private let fileURL: URL?
    private let makeContext: (UUID) -> BrowsingContext
    private var contexts: [UUID: BrowsingContext] = [:]

    /// `initialTheme` colors the first space on a first launch.
    init(
        fileURL: URL? = SpaceStore.defaultFileURL,
        initialTheme: ChromeTheme = .system,
        makeContext: @escaping (_ profileID: UUID) -> BrowsingContext
    ) {
        self.fileURL = fileURL
        self.makeContext = makeContext
        spaces = fileURL
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? PropertyListDecoder().decode(Spaces.self, from: $0) }
            ?? Spaces(theme: initialTheme)
    }

    static var defaultFileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Cove/spaces.plist")
    }

    /// Changes the spaces and saves them at once: edits are few and small.
    func change(_ change: (inout Spaces) -> Void) {
        var spaces = spaces
        change(&spaces)
        guard spaces != self.spaces else { return }
        self.spaces = spaces
        save()
    }

    /// What a space's tabs browse with: its profile's context, made the first
    /// time it's needed.
    func context(for space: Space) -> BrowsingContext {
        if let context = contexts[space.profileID] { return context }
        let context = makeContext(space.profileID)
        contexts[space.profileID] = context
        return context
    }

    /// Deletes a profile and everything sites stored in it. Its spaces move
    /// to the default profile, whose windows rebuild their tabs on the
    /// default store before the data goes.
    func deleteProfile(_ id: UUID) {
        guard id != Profile.defaultID else { return }
        change { $0.removeProfile(id) }
        let context = contexts.removeValue(forKey: id)
        Task {
            if let store = context?.dataStore {
                await store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
            }
            // Fails while WebKit still holds the store; the data is gone
            // either way, and the next launch removes what's left.
            try? await WKWebsiteDataStore.remove(forIdentifier: id)
        }
    }

    /// Removes the stores of profiles deleted while their store was in use,
    /// at launch, before any web view can open one.
    func removeOrphanedDataStores() {
        let kept = Set(spaces.profiles.map(\.id))
        Task {
            for id in await WKWebsiteDataStore.allDataStoreIdentifiers where !kept.contains(id) {
                try? await WKWebsiteDataStore.remove(forIdentifier: id)
            }
        }
    }

    private func save() {
        guard let fileURL else { return }
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        guard let data = try? encoder.encode(spaces) else { return }
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }
}
