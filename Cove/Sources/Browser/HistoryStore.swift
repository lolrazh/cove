import Foundation

struct HistoryEntry: Identifiable {
    let id: Int64
    let url: String
    let title: String
    let visitedAt: Date
}

/// A distinct page across all its visits, scored for the Command Bar.
struct HistoryPage: Hashable {
    let url: String
    let title: String
    /// Frecency: every visit counts 1 / (1 + its age in days), so a page seen
    /// often and recently rises above one seen once long ago.
    let frecency: Double
}

@MainActor
final class HistoryStore: ObservableObject {
    /// The most recent distinct pages, newest first, for the History menu.
    @Published private(set) var recentlyVisited: [HistoryEntry] = []

    private let settings: BrowserSettingsStore
    private let db: Database?
    private let recentlyVisitedLimit = 8

    init(settings: BrowserSettingsStore) {
        self.settings = settings
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dbPath = appSupport.appendingPathComponent("Cove/history.db").path

        do {
            db = try Database(path: dbPath)
            createTables()
        } catch {
            print("Failed to open history database: \(error)")
            db = nil
        }
        refreshRecentlyVisited()
    }

    private func createTables() {
        // Main history table
        db?.execute("""
            CREATE TABLE IF NOT EXISTS history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                url TEXT NOT NULL,
                title TEXT NOT NULL DEFAULT '',
                visited_at REAL NOT NULL
            )
        """)

        db?.execute("CREATE INDEX IF NOT EXISTS idx_history_visited ON history(visited_at DESC)")

        // FTS5 virtual table for full-text search
        db?.execute("""
            CREATE VIRTUAL TABLE IF NOT EXISTS history_fts USING fts5(
                url, title, content=history, content_rowid=id
            )
        """)

        // Triggers to keep FTS in sync
        db?.execute("""
            CREATE TRIGGER IF NOT EXISTS history_ai AFTER INSERT ON history BEGIN
                INSERT INTO history_fts(rowid, url, title) VALUES (new.id, new.url, new.title);
            END
        """)

        db?.execute("""
            CREATE TRIGGER IF NOT EXISTS history_ad AFTER DELETE ON history BEGIN
                INSERT INTO history_fts(history_fts, rowid, url, title) VALUES ('delete', old.id, old.url, old.title);
            END
        """)

        db?.execute("""
            CREATE TRIGGER IF NOT EXISTS history_au AFTER UPDATE ON history BEGIN
                INSERT INTO history_fts(history_fts, rowid, url, title) VALUES ('delete', old.id, old.url, old.title);
                INSERT INTO history_fts(rowid, url, title) VALUES (new.id, new.url, new.title);
            END
        """)
    }

    func recordVisit(url: String, title: String) {
        guard let db else { return }
        guard settings.saveBrowsingHistory else { return }
        // Skip blank/internal pages
        guard !url.isEmpty, url.hasPrefix("http") else { return }

        let timestamp = Date().timeIntervalSince1970
        try? db.run(
            "INSERT INTO history (url, title, visited_at) VALUES (?, ?, ?)",
            params: [url, title, timestamp]
        )
        refreshRecentlyVisited()
    }

    /// Fills in the title of the latest visit to `url`, for pages whose title
    /// arrives after they finish loading.
    func updateTitle(_ title: String, forLatestVisitTo url: String) {
        guard let db else { return }
        try? db.run(
            "UPDATE history SET title = ? WHERE id = (SELECT MAX(id) FROM history WHERE url = ?)",
            params: [title, url]
        )
        refreshRecentlyVisited()
    }

    func search(query: String, limit: Int = 50) -> [HistoryEntry] {
        guard let db else { return [] }
        guard settings.saveBrowsingHistory else { return [] }

        let results: [[String: Any]]
        if query.isEmpty {
            // Recent history
            results = (try? db.query(
                "SELECT id, url, title, visited_at FROM history ORDER BY visited_at DESC LIMIT ?",
                params: [limit]
            )) ?? []
        } else {
            guard let ftsQuery = Self.ftsQuery(for: query) else { return [] }
            results = (try? db.query(
                """
                SELECT h.id, h.url, h.title, h.visited_at
                FROM history h
                JOIN history_fts fts ON h.id = fts.rowid
                WHERE history_fts MATCH ?
                ORDER BY h.visited_at DESC
                LIMIT ?
                """,
                params: [ftsQuery, limit]
            )) ?? []
        }

        return results.compactMap { row in
            guard let id = row["id"] as? Int64,
                  let url = row["url"] as? String,
                  let timestamp = row["visited_at"] as? Double else { return nil }
            let title = row["title"] as? String ?? ""
            return HistoryEntry(id: id, url: url, title: title, visitedAt: Date(timeIntervalSince1970: timestamp))
        }
    }

    /// Distinct pages matching the query, best first. Each typed word is
    /// prefix-matched against the URL and title, so "git" finds GitHub.
    func pages(matching query: String, limit: Int = 20) -> [HistoryPage] {
        guard let db, settings.saveBrowsingHistory,
              let ftsQuery = Self.ftsQuery(for: query) else { return [] }

        // MAX() makes the bare title column come from the latest visit.
        let rows = (try? db.query(
            """
            SELECT url, title, MAX(visited_at) AS last_visit,
                   SUM(1.0 / (1.0 + (? - visited_at) / 86400.0)) AS frecency
            FROM history
            WHERE id IN (SELECT rowid FROM history_fts WHERE history_fts MATCH ?)
            GROUP BY url
            ORDER BY frecency DESC
            LIMIT ?
            """,
            params: [Date().timeIntervalSince1970, ftsQuery, limit]
        )) ?? []

        return rows.compactMap { row in
            guard let url = row["url"] as? String,
                  let frecency = row["frecency"] as? Double else { return nil }
            return HistoryPage(url: url, title: row["title"] as? String ?? "", frecency: frecency)
        }
    }

    func delete(_ ids: some Collection<Int64>) {
        guard let db else { return }
        for id in ids {
            try? db.run("DELETE FROM history WHERE id = ?", params: [id])
        }
        refreshRecentlyVisited()
    }

    func clearAll() {
        db?.execute("DELETE FROM history")
        db?.execute("INSERT INTO history_fts(history_fts) VALUES ('rebuild')")
        refreshRecentlyVisited()
    }

    /// An FTS5 query that prefix-matches each typed word. Words are split the
    /// way the tokenizer splits them, on anything that isn't a letter or digit,
    /// so "github.com/swift" finds what "github com swift" would. That also
    /// keeps FTS5 syntax out of the query.
    private static func ftsQuery(for query: String) -> String? {
        let tokens = query.split { !$0.isLetter && !$0.isNumber }
        guard !tokens.isEmpty else { return nil }
        return tokens.map { "\($0)*" }.joined(separator: " ")
    }

    /// Visits repeat (reloads, back and forth), so keep one entry per page.
    private func refreshRecentlyVisited() {
        var seen = Set<String>()
        recentlyVisited = Array(
            search(query: "", limit: 100)
                .filter { seen.insert($0.url).inserted }
                .prefix(recentlyVisitedLimit)
        )
    }
}
