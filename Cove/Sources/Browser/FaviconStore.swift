import AppKit

@MainActor
final class FaviconStore {
    private let db: Database?
    private var memoryCache: [String: NSImage] = [:]

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dbPath = appSupport.appendingPathComponent("Cove/favicons.db").path

        do {
            db = try Database(path: dbPath)
            createTable()
        } catch {
            print("Failed to open favicon database: \(error)")
            db = nil
        }
    }

    private func createTable() {
        db?.execute("""
            CREATE TABLE IF NOT EXISTS favicons (
                domain TEXT PRIMARY KEY,
                image_data BLOB NOT NULL,
                updated_at REAL NOT NULL
            )
        """)
    }

    func get(domain: String) -> NSImage? {
        if let cached = memoryCache[domain] {
            return cached
        }

        guard let db,
              let row = (try? db.query(
                "SELECT image_data FROM favicons WHERE domain = ? LIMIT 1",
                params: [domain]
              ))?.first,
              let data = row["image_data"] as? Data,
              let image = NSImage(data: data), image.isValid else {
            return nil
        }

        memoryCache[domain] = image
        return image
    }

    func store(domain: String, imageData: Data) {
        guard let image = NSImage(data: imageData), image.isValid else { return }
        memoryCache[domain] = image
        guard let db else { return }
        try? db.run(
            "INSERT OR REPLACE INTO favicons (domain, image_data, updated_at) VALUES (?, ?, ?)",
            params: [domain, imageData, Date().timeIntervalSince1970]
        )
    }
}
