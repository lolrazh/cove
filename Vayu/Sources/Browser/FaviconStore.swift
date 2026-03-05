import AppKit

@MainActor
final class FaviconStore {
    static let shared = FaviconStore()

    private let db: Database
    private var memoryCache: [String: NSImage] = [:]

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dbPath = appSupport.appendingPathComponent("Vayu/favicons.db").path

        do {
            db = try Database(path: dbPath)
            createTable()
            preWarm()
        } catch {
            fatalError("Failed to open favicon database: \(error)")
        }
    }

    private func createTable() {
        db.execute("""
            CREATE TABLE IF NOT EXISTS favicons (
                domain TEXT PRIMARY KEY,
                image_data BLOB NOT NULL,
                updated_at REAL NOT NULL
            )
        """)
    }

    // Load all cached favicons into memory at launch (Dia-style pre-warming)
    private func preWarm() {
        guard let rows = try? db.query("SELECT domain, image_data FROM favicons") else { return }
        for row in rows {
            guard let domain = row["domain"] as? String,
                  let data = row["image_data"] as? Data,
                  let image = NSImage(data: data), image.isValid else { continue }
            memoryCache[domain] = image
        }
    }

    func get(domain: String) -> NSImage? {
        memoryCache[domain]
    }

    func store(domain: String, imageData: Data) {
        guard let image = NSImage(data: imageData), image.isValid else { return }
        memoryCache[domain] = image
        try? db.run(
            "INSERT OR REPLACE INTO favicons (domain, image_data, updated_at) VALUES (?, ?, ?)",
            params: [domain, imageData, Date().timeIntervalSince1970]
        )
    }

    func image(for domain: String) -> NSImage? {
        memoryCache[domain]
    }
}
