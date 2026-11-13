import Foundation
import WebKit

/// Keeps the profiles between launches, and each profile's
/// browsing context while Cove runs. One store for the app: every window
/// shows the same profiles, each window one of them at a time.
@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var profiles: Profiles

    private let fileURL: URL?
    private let makeContext: (UUID) -> BrowsingContext
    private var contexts: [UUID: BrowsingContext] = [:]

    /// `initialTheme` colors the first profile on a first launch.
    init(
        fileURL: URL? = ProfileStore.defaultFileURL,
        initialTheme: ChromeTheme = .system,
        makeContext: @escaping (_ profileID: UUID) -> BrowsingContext
    ) {
        self.fileURL = fileURL
        self.makeContext = makeContext
        profiles = StoreFile.read(fileURL) { try? PropertyListDecoder().decode(Profiles.self, from: $0) }
            ?? Profiles(theme: initialTheme)
    }

    static var defaultFileURL: URL {
        ProfileMigration.root.appendingPathComponent("profiles.plist")
    }

    /// Changes the profiles and saves them at once: edits are few and small.
    func change(_ change: (inout Profiles) -> Void) {
        var profiles = profiles
        change(&profiles)
        guard profiles != self.profiles else { return }
        self.profiles = profiles
        save()
    }

    /// What a profile's tabs browse with: its profile's context, made the first
    /// time it's needed.
    func context(for profile: Profile) -> BrowsingContext {
        if let context = contexts[profile.id] { return context }
        let context = makeContext(profile.id)
        contexts[profile.id] = context
        return context
    }

    /// Deletes a profile and everything sites stored in it. Its profiles move
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
        let kept = Set(profiles.profiles.map(\.id))
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
        guard let data = try? encoder.encode(profiles) else { return }
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }
}
