import Foundation

/// A Today tab that went unused long enough to leave the sidebar.
struct ArchivedTab: Identifiable, Hashable {
    let id: UUID
    let url: String
    /// What the tab was called: the user's name for it, or the page's title.
    let title: String
    let archivedAt: Date
}

/// Tabs archived out of Today, newest first. Each keeps its back/forward list
/// in SQLite, so reopening one brings the whole tab back. The Command Bar
/// searches the entries; the Library will list them.
@MainActor
final class TabArchive: ObservableObject {
    @Published private(set) var entries: [ArchivedTab] = []

    private let db: Database?
    /// Beyond this many, the oldest are dropped.
    private let limit: Int

    init(directory: URL = TabArchive.defaultDirectory, limit: Int = 500) {
        self.limit = limit
        do {
            db = try Database(path: directory.appendingPathComponent("archive.db").path)
        } catch {
            print("Failed to open archive database: \(error)")
            db = nil
        }
        db?.execute("""
            CREATE TABLE IF NOT EXISTS archive (
                id TEXT PRIMARY KEY,
                url TEXT NOT NULL,
                title TEXT NOT NULL DEFAULT '',
                custom_title TEXT,
                interaction_state BLOB,
                archived_at REAL NOT NULL
            )
        """)
        entries = loadEntries()
    }

    private static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Cove")
    }

    /// Puts a tab in the archive. A start page has nothing to keep.
    func add(_ tab: SavedTab, at date: Date = .now) {
        guard let db, !tab.url.isEmpty else { return }
        let entry = ArchivedTab(id: UUID(), url: tab.url, title: tab.customTitle ?? tab.title, archivedAt: date)
        try? db.run(
            "INSERT INTO archive (id, url, title, custom_title, interaction_state, archived_at) VALUES (?, ?, ?, ?, ?, ?)",
            params: [entry.id.uuidString, tab.url, tab.title, tab.customTitle, tab.interactionState, date.timeIntervalSince1970]
        )
        entries.insert(entry, at: 0)
        trim()
    }

    /// Removes an archived tab and returns it, ready to be restored.
    func take(_ id: UUID) -> SavedTab? {
        guard let db, let index = entries.firstIndex(where: { $0.id == id }) else { return nil }
        let entry = entries.remove(at: index)
        let row = (try? db.query("SELECT title, custom_title, interaction_state FROM archive WHERE id = ?", params: [id.uuidString]))?.first
        try? db.run("DELETE FROM archive WHERE id = ?", params: [id.uuidString])
        return SavedTab(
            url: entry.url,
            title: row?["title"] as? String ?? entry.title,
            customTitle: row?["custom_title"] as? String,
            interactionState: row?["interaction_state"] as? Data,
            lastUsedAt: nil
        )
    }

    private func loadEntries() -> [ArchivedTab] {
        let rows = (try? db?.query("SELECT id, url, title, archived_at FROM archive ORDER BY archived_at DESC")) ?? []
        return rows.compactMap { row in
            guard let id = (row["id"] as? String).flatMap(UUID.init),
                  let url = row["url"] as? String,
                  let archivedAt = row["archived_at"] as? Double else { return nil }
            return ArchivedTab(id: id, url: url, title: row["title"] as? String ?? "", archivedAt: Date(timeIntervalSince1970: archivedAt))
        }
    }

    private func trim() {
        guard entries.count > limit else { return }
        try? db?.run(
            "DELETE FROM archive WHERE id IN (SELECT id FROM archive ORDER BY archived_at DESC LIMIT -1 OFFSET ?)",
            params: [limit]
        )
        entries.removeLast(entries.count - limit)
    }
}
