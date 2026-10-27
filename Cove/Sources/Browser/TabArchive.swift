import Foundation

/// A Today tab that left the sidebar, closed or gone unused.
struct ArchivedTab: Identifiable, Hashable {
    enum Reason: Int {
        /// Untouched long enough for the sweep to take it.
        case idle
        /// Closed by hand: what Reopen Last Closed Tab brings back.
        case closed
    }

    let id: UUID
    let url: String
    /// What the tab was called: the user's name for it, or the page's title.
    let title: String
    let archivedAt: Date
    let reason: Reason
}

/// Tabs that left Today, newest first, as Arc keeps them: every closed tab
/// and every idle one. Each keeps its back/forward list in SQLite, so
/// reopening one brings the whole tab back. The Library lists the entries and
/// the Command Bar searches them.
@MainActor
final class TabArchive: ObservableObject {
    @Published private(set) var entries: [ArchivedTab] = []

    private let db: Database?
    /// Beyond this many, the oldest are dropped.
    private let limit: Int

    /// A private window passes no directory: its archive lives in memory and
    /// goes with the window.
    init(directory: URL? = TabArchive.defaultDirectory, limit: Int = 500) {
        self.limit = limit
        do {
            db = try Database(path: directory?.appendingPathComponent("archive.db").path ?? Database.inMemory)
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
                archived_at REAL NOT NULL,
                reason INTEGER NOT NULL DEFAULT 0
            )
        """)
        // Archives made before closed tabs were kept here lack the column;
        // everywhere else this fails, harmlessly.
        db?.execute("ALTER TABLE archive ADD COLUMN reason INTEGER NOT NULL DEFAULT 0")
        entries = loadEntries()
    }

    private static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Cove")
    }

    /// The tab closed most recently, for Reopen Last Closed Tab.
    var lastClosed: ArchivedTab? {
        entries.first { $0.reason == .closed }
    }

    /// Puts a tab in the archive. A start page has nothing to keep.
    func add(_ tab: SavedTab, reason: ArchivedTab.Reason, at date: Date = .now) {
        guard let db, !tab.url.isEmpty else { return }
        let entry = ArchivedTab(id: UUID(), url: tab.url, title: tab.customTitle ?? tab.title, archivedAt: date, reason: reason)
        try? db.run(
            "INSERT INTO archive (id, url, title, custom_title, interaction_state, archived_at, reason) VALUES (?, ?, ?, ?, ?, ?, ?)",
            params: [entry.id.uuidString, tab.url, tab.title, tab.customTitle, tab.interactionState, date.timeIntervalSince1970, reason.rawValue]
        )
        entries.insert(entry, at: 0)
        trim()
    }

    /// Removes an archived tab and returns it, ready to be restored.
    func take(_ id: UUID) -> SavedTab? {
        guard let db, let entry = entries.first(where: { $0.id == id }) else { return nil }
        let row = (try? db.query("SELECT title, custom_title, interaction_state FROM archive WHERE id = ?", params: [id.uuidString]))?.first
        remove(id)
        return SavedTab(
            url: entry.url,
            title: row?["title"] as? String ?? entry.title,
            customTitle: row?["custom_title"] as? String,
            interactionState: row?["interaction_state"] as? Data,
            lastUsedAt: nil
        )
    }

    func remove(_ id: UUID) {
        try? db?.run("DELETE FROM archive WHERE id = ?", params: [id.uuidString])
        entries.removeAll { $0.id == id }
    }

    private func loadEntries() -> [ArchivedTab] {
        let rows = (try? db?.query("SELECT id, url, title, archived_at, reason FROM archive ORDER BY archived_at DESC")) ?? []
        return rows.compactMap { row in
            guard let id = (row["id"] as? String).flatMap(UUID.init),
                  let url = row["url"] as? String,
                  let archivedAt = row["archived_at"] as? Double else { return nil }
            return ArchivedTab(
                id: id,
                url: url,
                title: row["title"] as? String ?? "",
                archivedAt: Date(timeIntervalSince1970: archivedAt),
                reason: (row["reason"] as? Int64).flatMap { ArchivedTab.Reason(rawValue: Int($0)) } ?? .idle
            )
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

extension [ArchivedTab] {
    /// The entries whose title or address holds every typed word, still newest
    /// first, as the Command Bar matches them. Nothing typed keeps them all.
    func matching(_ query: String) -> [ArchivedTab] {
        let match = QueryMatch(query)
        guard !match.tokens.isEmpty else { return self }
        return filter { match.quality(title: $0.title, url: $0.url) != nil }
    }
}
