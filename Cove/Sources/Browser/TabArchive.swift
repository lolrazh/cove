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
    /// A closed tab returns to its slot only in the same live window. Other
    /// windows (and a new app session) must not reuse an unrelated index.
    var sourceWindowID: UUID? = nil
    var todayIndex: Int? = nil
    var tabGroup: ArchivedTabGroup? = nil
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
    @MainActor private final class PendingSave {
        let tab: TabSession
        var timeout: Task<Void, Never>?
        init(_ tab: TabSession) { self.tab = tab }
    }
    /// In-flight state saves only: at most eight pages, each for at most a second.
    private var pendingSaves: [UUID: PendingSave] = [:]

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
        db?.execute("ALTER TABLE archive ADD COLUMN source_window_id TEXT")
        db?.execute("ALTER TABLE archive ADD COLUMN today_index INTEGER")
        db?.execute("ALTER TABLE archive ADD COLUMN background_rgb INTEGER")
        db?.execute("ALTER TABLE archive ADD COLUMN tab_id TEXT")
        db?.execute("ALTER TABLE archive ADD COLUMN tab_group BLOB")
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
    @discardableResult
    func add(_ tab: SavedTab, reason: ArchivedTab.Reason, sourceWindowID: UUID? = nil,
             todayIndex: Int? = nil, tabGroup: ArchivedTabGroup? = nil, at date: Date = .now) -> UUID? {
        guard let db, !tab.url.isEmpty else { return nil }
        let entry = ArchivedTab(id: UUID(), url: tab.url, title: tab.customTitle ?? tab.title, archivedAt: date, reason: reason,
                                sourceWindowID: sourceWindowID, todayIndex: todayIndex, tabGroup: tabGroup)
        try? db.run(
            "INSERT INTO archive (id, url, title, custom_title, interaction_state, archived_at, reason, source_window_id, today_index, background_rgb, tab_id, tab_group) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            params: [entry.id.uuidString, tab.url, tab.title, tab.customTitle, tab.interactionState, date.timeIntervalSince1970, reason.rawValue, sourceWindowID?.uuidString, todayIndex, tab.backgroundRGB, tab.id?.uuidString, tabGroup.flatMap { try? JSONEncoder().encode($0) }]
        )
        entries.insert(entry, at: 0)
        trim()
        return entry.id
    }

    /// The row is already present for immediate LIFO undo. Refresh only its
    /// opaque state once the closed page has actually become hidden.
    func saveAfterHiding(_ tab: TabSession, entryID: UUID) {
        guard tab.webView != nil, entries.contains(where: { $0.id == entryID }) else { return }
        let pending = PendingSave(tab)
        pendingSaves[entryID] = pending
        let deadline = ContinuousClock.now.advanced(by: .seconds(1))
        pending.timeout = Task { [weak self] in
            try? await Task.sleep(until: deadline, clock: .continuous)
            guard !Task.isCancelled else { return }
            self?.finishPendingSave(entryID)
        }
        tab.prepareArchiveSnapshot { [weak self] in self?.finishPendingSave(entryID) }
        if pendingSaves.count > 8,
           let oldest = entries.reversed().first(where: { pendingSaves[$0.id] != nil }) {
            finishPendingSave(oldest.id)
        }
    }

    private func finishPendingSave(_ id: UUID) {
        guard let pending = pendingSaves.removeValue(forKey: id) else { return }
        pending.timeout?.cancel()
        let saved = pending.tab.savedTab
        if entries.contains(where: { $0.id == id }), let state = saved.interactionState {
            try? db?.run("UPDATE archive SET interaction_state = ?, background_rgb = ? WHERE id = ?",
                        params: [state, saved.backgroundRGB, id.uuidString])
        }
        pending.tab.endArchiveSnapshot(restoring: false)
    }

    /// Immediate undo can take the live page before its save completes. The
    /// receiving window must rebind its host; finished saves restore from disk.
    func takeForRestoration(_ id: UUID) -> (saved: SavedTab, live: TabSession?)? {
        let pending = pendingSaves.removeValue(forKey: id)
        pending?.timeout?.cancel()
        guard let saved = take(id) else {
            pending?.tab.endArchiveSnapshot(restoring: false)
            return nil
        }
        pending?.tab.endArchiveSnapshot(restoring: true)
        return (saved, pending?.tab)
    }

    /// Removes an archived tab and returns it, ready to be restored.
    func take(_ id: UUID) -> SavedTab? {
        guard let db, let entry = entries.first(where: { $0.id == id }) else { return nil }
        let row = (try? db.query("SELECT title, custom_title, interaction_state, background_rgb, tab_id FROM archive WHERE id = ?", params: [id.uuidString]))?.first
        remove(id)
        return SavedTab(
            url: entry.url,
            title: row?["title"] as? String ?? entry.title,
            customTitle: row?["custom_title"] as? String,
            interactionState: row?["interaction_state"] as? Data,
            lastUsedAt: nil,
            backgroundRGB: (row?["background_rgb"] as? Int64).flatMap(Int.init(exactly:)),
            id: (row?["tab_id"] as? String).flatMap(UUID.init)
        )
    }

    func remove(_ id: UUID) {
        if let pending = pendingSaves.removeValue(forKey: id) {
            pending.timeout?.cancel()
            pending.tab.endArchiveSnapshot(restoring: false)
        }
        try? db?.run("DELETE FROM archive WHERE id = ?", params: [id.uuidString])
        entries.removeAll { $0.id == id }
    }

    private func loadEntries() -> [ArchivedTab] {
        let rows = (try? db?.query("SELECT id, url, title, custom_title, archived_at, reason, source_window_id, today_index, tab_group FROM archive ORDER BY archived_at DESC, rowid DESC")) ?? []
        return rows.compactMap { row in
            guard let id = (row["id"] as? String).flatMap(UUID.init),
                  let url = row["url"] as? String,
                  let archivedAt = row["archived_at"] as? Double else { return nil }
            return ArchivedTab(
                id: id,
                url: url,
                title: row["custom_title"] as? String ?? row["title"] as? String ?? "",
                archivedAt: Date(timeIntervalSince1970: archivedAt),
                reason: (row["reason"] as? Int64).flatMap { ArchivedTab.Reason(rawValue: Int($0)) } ?? .idle,
                sourceWindowID: (row["source_window_id"] as? String).flatMap(UUID.init),
                todayIndex: (row["today_index"] as? Int64).flatMap(Int.init(exactly:)),
                tabGroup: (row["tab_group"] as? Data).flatMap { try? JSONDecoder().decode(ArchivedTabGroup.self, from: $0) }
            )
        }
    }

    private func trim() {
        guard entries.count > limit else { return }
        try? db?.run(
            "DELETE FROM archive WHERE id IN (SELECT id FROM archive ORDER BY archived_at DESC, rowid DESC LIMIT -1 OFFSET ?)",
            params: [limit]
        )
        let removed = entries.suffix(entries.count - limit).map(\.id)
        entries.removeLast(removed.count)
        for id in removed {
            if let pending = pendingSaves.removeValue(forKey: id) {
                pending.timeout?.cancel()
                pending.tab.endArchiveSnapshot(restoring: false)
            }
        }
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
