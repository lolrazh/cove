import Foundation
import SQLite3

enum BrowserImportSource: String, CaseIterable, Identifiable, Sendable {
    case safari = "Safari", chrome = "Chrome", dia = "Dia", other = "Other browser"
    var id: String { rawValue }
}

struct ImportedHistoryVisit: Equatable, Sendable {
    let url: URL
    let title: String
    let visitedAt: Date
}

/// An immutable preview. The caller captures the destination profile before
/// opening the picker and changes that profile only after the user confirms.
struct BrowserImportPreview: Sendable {
    let source: BrowserImportSource
    let bookmarks: [ImportedBookmark]
    let history: [ImportedHistoryVisit]
    let issues: [String]

    var bookmarkCount: Int { BookmarkImport.Preview(source: .html, bookmarks: bookmarks).pageCount }
    var folderCount: Int { BookmarkImport.Preview(source: .html, bookmarks: bookmarks).folderCount }
    var historyCount: Int { history.count }

    static func read(from url: URL, source: BrowserImportSource) throws -> Self {
        let isFolder = try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
        var bookmarks: [ImportedBookmark] = []
        var history: [ImportedHistoryVisit] = []
        var issues: [String] = []
        let files: [URL]
        if isFolder {
            files = ["Bookmarks", "Bookmarks.plist", "Bookmarks.html", "History", "History.db"]
                .map { url.appendingPathComponent($0) }
                .filter { FileManager.default.fileExists(atPath: $0.path) }
            guard !files.isEmpty else { throw ImportError.noFiles }
        } else {
            files = [url]
        }
        for file in files {
            do {
                let handle = try FileHandle(forReadingFrom: file)
                let signature = try handle.read(upToCount: 16) ?? Data()
                try handle.close()
                if signature.starts(with: Data("SQLite format 3\0".utf8)) {
                    history += try BrowserHistoryImport.read(file)
                } else {
                    let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    guard size <= 32 * 1024 * 1024 else { throw BookmarkImport.Failure.fileTooLarge }
                    bookmarks += try BookmarkImport.bookmarks(from: Data(contentsOf: file))
                }
            } catch {
                issues.append("\(file.lastPathComponent): \(error.localizedDescription)")
            }
        }
        return Self(source: source, bookmarks: bookmarks, history: history, issues: issues)
    }

    enum ImportError: Error, LocalizedError {
        case noFiles, unreadableHistory, tooMuchHistory
        var errorDescription: String? {
            switch self {
            case .noFiles: "Choose a browser profile folder with Bookmarks or History, or a bookmarks export."
            case .unreadableHistory: "Could not read this history file. Close the source browser and try again."
            case .tooMuchHistory: "This file has more than 100,000 visits. Choose a smaller history file."
            }
        }
    }
}

enum BrowserHistoryImport {
    static func read(_ url: URL) throws -> [ImportedHistoryVisit] {
        var connection: OpaquePointer?
        guard sqlite3_open_v2(url.path, &connection, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK,
              let db = connection else {
            if let connection { sqlite3_close(connection) }
            throw BrowserImportPreview.ImportError.unreadableHistory
        }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 1_000)
        let safari = tableExists("history_visits", db: db)
        let sql: String
        if safari {
            sql = "SELECT i.url, v.title, v.visit_time + 978307200 FROM history_visits v JOIN history_items i ON i.id = v.history_item ORDER BY v.visit_time DESC LIMIT 100001"
        } else if tableExists("visits", db: db) {
            sql = "SELECT u.url, u.title, (v.visit_time / 1000000.0) - 11644473600 FROM visits v JOIN urls u ON u.id = v.url WHERE u.hidden = 0 ORDER BY v.visit_time DESC LIMIT 100001"
        } else {
            throw BrowserImportPreview.ImportError.unreadableHistory
        }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw BrowserImportPreview.ImportError.unreadableHistory
        }
        defer { sqlite3_finalize(statement) }
        var visits: [ImportedHistoryVisit] = []
        var rowCount = 0
        var status = sqlite3_step(statement)
        while status == SQLITE_ROW {
            rowCount += 1
            guard rowCount <= 100_000 else { throw BrowserImportPreview.ImportError.tooMuchHistory }
            let timestamp = sqlite3_column_double(statement, 2)
            if let bytes = sqlite3_column_text(statement, 0),
               let page = BookmarkImport.tabURL(String(cString: bytes)),
               timestamp.isFinite, timestamp > 0, timestamp <= Date.now.timeIntervalSince1970 + 86_400 {
                let title = sqlite3_column_text(statement, 1).map { String(cString: $0) } ?? ""
                visits.append(ImportedHistoryVisit(url: page, title: title, visitedAt: Date(timeIntervalSince1970: timestamp)))
            }
            status = sqlite3_step(statement)
        }
        guard status == SQLITE_DONE else { throw BrowserImportPreview.ImportError.unreadableHistory }
        return visits
    }

    private static func tableExists(_ name: String, db: OpaquePointer) -> Bool {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?", -1, &statement, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(statement) }
        return name.withCString { pointer in
            sqlite3_bind_text(statement, 1, pointer, -1, nil)
            return sqlite3_step(statement) == SQLITE_ROW
        }
    }
}
