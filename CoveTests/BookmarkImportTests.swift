import Foundation
import Testing
@testable import Cove

struct BookmarkImportTests {
    @Test func htmlPreservesFoldersUnicodeAndEntities() throws {
        let html = """
        <!DOCTYPE NETSCAPE-Bookmark-file-1>
        <DL><p>
          <DT><H3>Work &amp; &#x1F30A;</H3>
          <DL><p>
            <DT><A HREF="https://example.com/?a=1&amp;b=2">தமிழ் &quot;Web&quot;</A>
            <DT><H3>Nested</H3><DL>
              <DT><A HREF='https://swift.org/'>Swift &#38; Web</A>
              <DT><A HREF="javascript:alert(1)">Bad</A>
              <DT><A HREF="https:missing-host">Bad</A>
            </DL>
          </DL>
        </DL>
        """
        let preview = try BookmarkImport.preview(from: Data(html.utf8))
        #expect(preview.source == .html)
        #expect(preview.pageCount == 2)
        #expect(preview.folderCount == 2)
        #expect(preview.bookmarks == [.folder(title: "Work & 🌊", children: [
            .page(title: "தமிழ் \"Web\"", url: URL(string: "https://example.com/?a=1&b=2")!),
            .folder(title: "Nested", children: [.page(title: "Swift & Web", url: URL(string: "https://swift.org/")!)])
        ])])
    }

    @Test func htmlDecodesOnceAndRejectsUnrelatedDocuments() throws {
        let html = "<!DOCTYPE NETSCAPE-Bookmark-file-1><DL><A HREF=https://example.com>&amp;amp; &#60; &#128512;</A></DL>"
        #expect(try BookmarkImport.bookmarks(from: Data(html.utf8)) == [
            .page(title: "&amp; < 😀", url: URL(string: "https://example.com")!)
        ])
        #expect(throws: BookmarkImport.Failure.self) {
            try BookmarkImport.bookmarks(from: Data("<!doctype html><a href='https://example.com'>Page</a>".utf8))
        }
    }

    private let swift = URL(string: "https://swift.org/")!
    private let webkit = URL(string: "https://webkit.org/")!

    private func safariFile(_ children: [[String: Any]]) throws -> Data {
        let root: [String: Any] = ["WebBookmarkType": "WebBookmarkTypeList", "Title": "", "Children": children]
        return try PropertyListSerialization.data(fromPropertyList: root, format: .binary, options: 0)
    }

    private func safariList(_ title: String, _ children: [[String: Any]]) -> [String: Any] {
        ["WebBookmarkType": "WebBookmarkTypeList", "Title": title, "Children": children]
    }

    private func safariLeaf(_ title: String, _ url: String) -> [String: Any] {
        ["WebBookmarkType": "WebBookmarkTypeLeaf", "URLString": url, "URIDictionary": ["title": title]]
    }

    @Test func `safari's folders come back by their shown names, nested`() throws {
        let data = try safariFile([
            ["WebBookmarkType": "WebBookmarkTypeProxy", "Title": "History"],
            safariList("BookmarksBar", [
                safariLeaf("Swift", swift.absoluteString),
                safariList("Web", [safariLeaf("WebKit", webkit.absoluteString)]),
            ]),
            safariList("BookmarksMenu", []),
            safariList("com.apple.ReadingList", [safariLeaf("Later", "https://example.com/")]),
        ])

        #expect(try BookmarkImport.bookmarks(from: data) == [
            .folder(title: "Favorites", children: [
                .page(title: "Swift", url: swift),
                .folder(title: "Web", children: [.page(title: "WebKit", url: webkit)]),
            ]),
        ])
    }

    @Test func `chrome's roots come back as folders, bookmarklets left out`() throws {
        let json = """
        {
          "checksum": "0",
          "roots": {
            "bookmark_bar": { "type": "folder", "name": "Bookmarks bar", "children": [
              { "type": "url", "name": "Swift", "url": "https://swift.org/" },
              { "type": "url", "name": "Tidy", "url": "javascript:void(0)" },
              { "type": "folder", "name": "Web", "children": [
                { "type": "url", "name": "", "url": "https://webkit.org/" }
              ] }
            ] },
            "other": { "type": "folder", "name": "Other bookmarks", "children": [] },
            "synced": { "type": "folder", "name": "Mobile bookmarks", "children": [] }
          },
          "version": 1
        }
        """

        #expect(try BookmarkImport.bookmarks(from: Data(json.utf8)) == [
            .folder(title: "Bookmarks bar", children: [
                .page(title: "Swift", url: swift),
                .folder(title: "Web", children: [.page(title: webkit.absoluteString, url: webkit)]),
            ]),
        ])
    }

    @Test func `anything else is not a bookmarks file`() {
        #expect(throws: BookmarkImport.Failure.self) { try BookmarkImport.bookmarks(from: Data("{\"a\": 1}".utf8)) }
        #expect(throws: BookmarkImport.Failure.self) { try BookmarkImport.bookmarks(from: Data("hello".utf8)) }
    }
}
