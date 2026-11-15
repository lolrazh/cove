import Foundation

/// A bookmark read from another browser: a page, or a folder of them. It
/// becomes a Pinned tab or folder when imported.
enum ImportedBookmark: Equatable, Sendable {
    case page(title: String, url: URL)
    case folder(title: String, children: [ImportedBookmark])
}

/// Reads only the file selected by the user. Parsing never changes a profile.
enum BookmarkImport {
    enum Failure: Error, LocalizedError {
        case unrecognizedFile
        case fileTooLarge

        var errorDescription: String? {
            switch self {
            case .unrecognizedFile: "Choose a bookmarks HTML export, Safari plist, or Chromium Bookmarks file."
            case .fileTooLarge: "This bookmarks file is too large. Export a smaller collection and try again."
            }
        }
    }

    enum Source: String, Sendable {
        case safari = "Safari"
        case chrome = "Chrome"
        case html = "Bookmarks File"
    }

    struct Preview: Sendable {
        let source: Source
        let bookmarks: [ImportedBookmark]

        var pageCount: Int { counts.pages }
        var folderCount: Int { counts.folders }

        private var counts: (pages: Int, folders: Int) {
            var pending = bookmarks
            var pages = 0
            var folders = 0
            while let item = pending.popLast() {
                switch item {
                case .page: pages += 1
                case .folder(_, let children):
                    folders += 1
                    pending.append(contentsOf: children)
                }
            }
            return (pages, folders)
        }
    }

    static func preview(from data: Data) throws -> Preview {
        Preview(source: source(of: data), bookmarks: try bookmarks(from: data))
    }

    static func source(of data: Data) -> Source {
        let prefix = String(decoding: data.prefix(4096), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\u{FEFF}")))
        if prefix.hasPrefix("{") { return .chrome }
        if prefix.localizedCaseInsensitiveContains("NETSCAPE-Bookmark-file-1") { return .html }
        return .safari
    }

    static func bookmarks(from data: Data) throws -> [ImportedBookmark] {
        guard data.count <= 32 * 1024 * 1024 else { throw Failure.fileTooLarge }
        switch source(of: data) {
        case .chrome: return try chrome(data)
        case .safari: return try safari(data)
        case .html: return try BookmarkHTML.read(data)
        }
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
    static func tabURL(_ string: String?) -> URL? {
        guard let string, let url = URL(string: string),
              ["http", "https"].contains(url.scheme?.lowercased()),
              let host = url.host, !host.isEmpty else {
            return nil
        }
        return url
    }

    private static func folder(_ title: String, _ children: [ImportedBookmark]) -> ImportedBookmark? {
        children.isEmpty ? nil : .folder(title: title, children: children)
    }
}
