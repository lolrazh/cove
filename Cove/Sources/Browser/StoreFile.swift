import Foundation
import os

/// Reads a store's file. One that exists but can't be decoded, as one written
/// by a newer Cove, is moved aside to `<name>.unreadable-<date>` before the
/// store starts afresh, so the next save never overwrites it: nothing is lost
/// silently.
enum StoreFile {
    private static let logger = Logger(subsystem: "com.cove.browser", category: "StoreFile")

    static func read<Value>(_ url: URL?, decode: (Data) -> Value?) -> Value? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        if let value = decode(data) { return value }
        let aside = url.appendingPathExtension("unreadable-\(Int(Date.now.timeIntervalSince1970))")
        do {
            try FileManager.default.moveItem(at: url, to: aside)
            logger.error("Couldn't read \(url.lastPathComponent, privacy: .public); moved it to \(aside.lastPathComponent, privacy: .public)")
        } catch {
            logger.error("Couldn't read or move \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
        return nil
    }
}
