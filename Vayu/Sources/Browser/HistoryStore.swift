import Foundation

struct HistoryEntry: Identifiable {
    let id: Int64
    let url: String
    let title: String
    let visitedAt: Date
}

@MainActor
final class HistoryStore {
    static let shared = HistoryStore()

    private let db: Database?

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dbPath = appSupport.appendingPathComponent("Vayu/history.db").path

        do {
            db = try Database(path: dbPath)
            createTables()
        } catch {
            print("Failed to open history database: \(error)")
            db = nil
        }
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
        // Skip blank/internal pages
        guard !url.isEmpty, url.hasPrefix("http") else { return }

        let timestamp = Date().timeIntervalSince1970
        try? db.run(
            "INSERT INTO history (url, title, visited_at) VALUES (?, ?, ?)",
            params: [url, title, timestamp]
        )
    }

    func search(query: String, limit: Int = 50) -> [HistoryEntry] {
        guard let db else { return [] }

        let results: [[String: Any]]
        if query.isEmpty {
            // Recent history
            results = (try? db.query(
                "SELECT id, url, title, visited_at FROM history ORDER BY visited_at DESC LIMIT ?",
                params: [limit]
            )) ?? []
        } else {
            // FTS search
            let ftsQuery = query.split(separator: " ").map { "\($0)*" }.joined(separator: " ")
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

    func clearAll() {
        db?.execute("DELETE FROM history")
        db?.execute("INSERT INTO history_fts(history_fts) VALUES ('rebuild')")
    }
}
