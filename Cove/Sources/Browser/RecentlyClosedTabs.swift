import Foundation

/// Pages whose tabs were closed this session, most recent first. Backs
/// History > Recently Closed and Reopen Last Closed Tab.
@MainActor
final class RecentlyClosedTabs: ObservableObject {
    struct Entry: Identifiable {
        let id = UUID()
        let url: String
        let title: String
    }

    @Published private(set) var entries: [Entry] = []

    private let limit = 20

    func record(url: String, title: String) {
        guard !url.isEmpty else { return }
        entries.insert(Entry(url: url, title: title), at: 0)
        if entries.count > limit {
            entries.removeLast(entries.count - limit)
        }
    }

    /// Removes and returns an entry, so a reopened tab leaves the list.
    func take(_ id: UUID? = nil) -> Entry? {
        guard let index = id.map({ id in entries.firstIndex { $0.id == id } }) ?? entries.indices.first else {
            return nil
        }
        return entries.remove(at: index)
    }
}
