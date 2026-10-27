import Foundation

/// Keeps the Boosts between launches, in a JSON file of their own: small,
/// readable, and ready to be exported or synced as it is. One store for the
/// app. Without a file it keeps nothing, which tests want.
@MainActor
final class BoostStore: ObservableObject {
    @Published private(set) var boosts: [Boost]

    private let fileURL: URL?

    init(fileURL: URL? = BoostStore.defaultFileURL) {
        self.fileURL = fileURL
        boosts = StoreFile.read(fileURL) { try? JSONDecoder().decode([Boost].self, from: $0) } ?? []
    }

    static var defaultFileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Cove/boosts.json")
    }

    /// The Boost to edit on the page: the site's own, else the nearest one
    /// covering it, else nil for a site without one.
    func boost(for site: Site) -> Boost? {
        boosts.filter { $0.covers(site.domain) }.max { $0.domain.count < $1.domain.count }
    }

    /// Adds the Boost or replaces the one with its ID. One that changes
    /// nothing is removed instead, so opening the editor and closing it
    /// leaves nothing behind.
    func save(_ boost: Boost) {
        var boosts = boosts
        if let index = boosts.firstIndex(where: { $0.id == boost.id }) {
            if boost.isEmpty { boosts.remove(at: index) } else { boosts[index] = boost }
        } else if !boost.isEmpty {
            boosts.append(boost)
        }
        guard boosts != self.boosts else { return }
        self.boosts = boosts
        write()
    }

    func remove(_ id: UUID) {
        boosts.removeAll { $0.id == id }
        write()
    }

    /// Writes at once: the file is a few kilobytes, even when it's being
    /// rewritten on every keystroke in the editor.
    private func write() {
        guard let fileURL else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(boosts) else { return }
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }
}
