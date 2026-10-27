import Foundation

/// A bookmark read from another browser: a page, or a folder of them. It
/// becomes a Pinned tab or folder when imported.
enum ImportedBookmark: Equatable {
    case page(title: String, url: URL)
    case folder(title: String, children: [ImportedBookmark])
}

/// Reads other browsers' bookmark files: Safari's `Bookmarks.plist` and
/// Chrome's `Bookmarks` JSON. Each top-level collection (Favorites, the
/// bookmarks bar, other bookmarks) comes back as a folder; empty folders,
/// Safari's Reading List and History, and anything that can't be a tab, like
/// a bookmarklet, are left out.
enum BookmarkImport {
    enum Failure: Error {
        case unrecognizedFile
    }

    /// Tells the two formats apart by content, since Chrome's file has no
    /// extension: JSON starts with a brace, a property list doesn't.
    static func bookmarks(from data: Data) throws -> [ImportedBookmark] {
        let firstByte = data.first { !Character(UnicodeScalar($0)).isWhitespace }
        return firstByte == UInt8(ascii: "{") ? try chrome(data) : try safari(data)
    }

    // MARK: - Safari

    static func safari(_ data: Data) throws -> [ImportedBookmark] {
        guard let root = try? PropertyListDecoder().decode(SafariNode.self, from: data),
              root.type == SafariNode.list else { throw Failure.unrecognizedFile }
        return (root.children ?? []).compactMap(\.bookmark)
    }

    private struct SafariNode: Decodable {
        static let list = "WebBookmarkTypeList"
        static let leaf = "WebBookmarkTypeLeaf"

        let type: String
        let title: String?
        let urlString: String?
        let uriDictionary: [String: String]?
        let children: [SafariNode]?

        enum CodingKeys: String, CodingKey {
            case type = "WebBookmarkType"
            case title = "Title"
            case urlString = "URLString"
            case uriDictionary = "URIDictionary"
            case children = "Children"
        }

        /// Proxies (History) and the Reading List aren't bookmarks.
        var bookmark: ImportedBookmark? {
            switch type {
            case Self.leaf:
                guard let url = BookmarkImport.tabURL(urlString) else { return nil }
                return .page(title: uriDictionary?["title"] ?? url.absoluteString, url: url)
            case Self.list where title != "com.apple.ReadingList":
                return BookmarkImport.folder(Self.displayName(title ?? ""), (children ?? []).compactMap(\.bookmark))
            default:
                return nil
            }
        }

        /// Safari stores its two built-in folders under internal names.
        private static func displayName(_ title: String) -> String {
            switch title {
            case "BookmarksBar": "Favorites"
            case "BookmarksMenu": "Bookmarks Menu"
            default: title
            }
        }
    }

    // MARK: - Chrome

    static func chrome(_ data: Data) throws -> [ImportedBookmark] {
        guard let file = try? JSONDecoder().decode(ChromeFile.self, from: data) else {
            throw Failure.unrecognizedFile
        }
        let roots = file.roots
        return [roots.bookmarkBar, roots.other, roots.synced].compactMap { $0?.bookmark }
    }

    private struct ChromeFile: Decodable {
        struct Roots: Decodable {
            let bookmarkBar: ChromeNode?
            let other: ChromeNode?
            let synced: ChromeNode?

            enum CodingKeys: String, CodingKey {
                case bookmarkBar = "bookmark_bar"
                case other
                case synced
            }
        }

        let roots: Roots
    }

    private struct ChromeNode: Decodable {
        let type: String
        let name: String
        let url: String?
        let children: [ChromeNode]?

        var bookmark: ImportedBookmark? {
            switch type {
            case "url":
                BookmarkImport.tabURL(url).map { .page(title: name.isEmpty ? $0.absoluteString : name, url: $0) }
            case "folder":
                BookmarkImport.folder(name, (children ?? []).compactMap(\.bookmark))
            default:
                nil
            }
        }
    }

    // MARK: - Shared

    /// Only web pages make tabs.
    private static func tabURL(_ string: String?) -> URL? {
        guard let string, let url = URL(string: string), ["http", "https"].contains(url.scheme?.lowercased()) else {
            return nil
        }
        return url
    }

    private static func folder(_ title: String, _ children: [ImportedBookmark]) -> ImportedBookmark? {
        children.isEmpty ? nil : .folder(title: title, children: children)
    }
}
