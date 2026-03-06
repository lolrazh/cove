import Foundation
import SQLite3

final class Database {
    private var db: OpaquePointer?

    init(path: String) throws {
        let dir = (path as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        if sqlite3_open(path, &db) != SQLITE_OK {
            let msg = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.openFailed(msg)
        }

        // WAL mode for better concurrent read/write performance
        execute("PRAGMA journal_mode=WAL")
    }

    deinit {
        sqlite3_close(db)
    }

    @discardableResult
    func execute(_ sql: String) -> Bool {
        sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK
    }

    func prepare(_ sql: String) throws -> OpaquePointer? {
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            let msg = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.prepareFailed(msg)
        }
        return stmt
    }

    func run(_ sql: String, params: [Any?] = []) throws {
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }

        for (i, param) in params.enumerated() {
            let idx = Int32(i + 1)
            switch param {
            case let v as String:
                sqlite3_bind_text(stmt, idx, (v as NSString).utf8String, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            case let v as Int64:
                sqlite3_bind_int64(stmt, idx, v)
            case let v as Double:
                sqlite3_bind_double(stmt, idx, v)
            case let v as Int:
                sqlite3_bind_int64(stmt, idx, Int64(v))
            case let v as Data:
                v.withUnsafeBytes { ptr in
                    sqlite3_bind_blob(stmt, idx, ptr.baseAddress, Int32(v.count), unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                }
            case nil:
                sqlite3_bind_null(stmt, idx)
            default:
                sqlite3_bind_text(stmt, idx, "\(param!)", -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            }
        }

        if sqlite3_step(stmt) != SQLITE_DONE {
            let msg = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.executionFailed(msg)
        }
    }

    func query(_ sql: String, params: [Any?] = []) throws -> [[String: Any]] {
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }

        for (i, param) in params.enumerated() {
            let idx = Int32(i + 1)
            switch param {
            case let v as String:
                sqlite3_bind_text(stmt, idx, (v as NSString).utf8String, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            case let v as Int64:
                sqlite3_bind_int64(stmt, idx, v)
            case let v as Double:
                sqlite3_bind_double(stmt, idx, v)
            case let v as Int:
                sqlite3_bind_int64(stmt, idx, Int64(v))
            case let v as Data:
                v.withUnsafeBytes { ptr in
                    sqlite3_bind_blob(stmt, idx, ptr.baseAddress, Int32(v.count), unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                }
            case nil:
                sqlite3_bind_null(stmt, idx)
            default:
                sqlite3_bind_text(stmt, idx, "\(param!)", -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            }
        }

        var results: [[String: Any]] = []
        let colCount = sqlite3_column_count(stmt)

        while sqlite3_step(stmt) == SQLITE_ROW {
            var row: [String: Any] = [:]
            for i in 0..<colCount {
                let name = String(cString: sqlite3_column_name(stmt, i))
                switch sqlite3_column_type(stmt, i) {
                case SQLITE_TEXT:
                    row[name] = String(cString: sqlite3_column_text(stmt, i))
                case SQLITE_INTEGER:
                    row[name] = sqlite3_column_int64(stmt, i)
                case SQLITE_FLOAT:
                    row[name] = sqlite3_column_double(stmt, i)
                case SQLITE_BLOB:
                    if let bytes = sqlite3_column_blob(stmt, i) {
                        let count = Int(sqlite3_column_bytes(stmt, i))
                        row[name] = Data(bytes: bytes, count: count)
                    }
                case SQLITE_NULL:
                    row[name] = nil
                default:
                    row[name] = String(cString: sqlite3_column_text(stmt, i))
                }
            }
            results.append(row)
        }

        return results
    }
}

enum DatabaseError: Error, LocalizedError {
    case openFailed(String)
    case prepareFailed(String)
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .openFailed(let msg): "Failed to open database: \(msg)"
        case .prepareFailed(let msg): "Failed to prepare statement: \(msg)"
        case .executionFailed(let msg): "Failed to execute statement: \(msg)"
        }
    }
}
