import Foundation

/// Netscape bookmark exports use optional HTML end tags, so they are not XML.
/// Read only their folder lists, headings, and links. Never render the document.
enum BookmarkHTML {
    private struct List {
        var title: String?
        var items: [ImportedBookmark] = []
    }

    static func read(_ data: Data) throws -> [ImportedBookmark] {
        guard let html = String(data: data, encoding: .utf8),
              html.localizedCaseInsensitiveContains("NETSCAPE-Bookmark-file-1") else {
            throw BookmarkImport.Failure.unrecognizedFile
        }
        let tokens = try NSRegularExpression(
            pattern: #"<(?:(/?)DL\b[^>]*|H3\b[^>]*>(.*?)</H3\s*|A\b([^>]*)>(.*?)</A\s*)>"#,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        )
        let href = try NSRegularExpression(
            pattern: #"(?:^|\s)HREF\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))"#,
            options: [.caseInsensitive]
        )
        let text = html as NSString
        var lists = [List()]
        var nextTitle: String?
        var sawList = false
        for token in tokens.matches(in: html, range: NSRange(location: 0, length: text.length)) {
            if token.range(at: 1).location != NSNotFound {
                sawList = true
                if text.substring(with: token.range(at: 1)) == "/" {
                    closeList(&lists)
                } else {
                    guard lists.count < 128 else { throw BookmarkImport.Failure.unrecognizedFile }
                    lists.append(List(title: nextTitle))
                    nextTitle = nil
                }
            } else if token.range(at: 2).location != NSNotFound {
                nextTitle = decode(text.substring(with: token.range(at: 2)))
            } else {
                let attributes = text.substring(with: token.range(at: 3))
                guard let match = href.firstMatch(in: attributes, range: NSRange(location: 0, length: (attributes as NSString).length)),
                      let range = (1...3).map({ match.range(at: $0) }).first(where: { $0.location != NSNotFound }),
                      let url = BookmarkImport.tabURL(decode((attributes as NSString).substring(with: range))) else { continue }
                let title = decode(text.substring(with: token.range(at: 4)))
                lists[lists.count - 1].items.append(.page(title: title.isEmpty ? url.absoluteString : title, url: url))
            }
        }
        guard sawList else { throw BookmarkImport.Failure.unrecognizedFile }
        while lists.count > 1 { closeList(&lists) }
        return lists[0].items
    }

    private static func closeList(_ lists: inout [List]) {
        guard lists.count > 1 else { return }
        let list = lists.removeLast()
        guard !list.items.isEmpty else { return }
        if let title = list.title {
            lists[lists.count - 1].items.append(.folder(title: title, children: list.items))
        } else {
            lists[lists.count - 1].items.append(contentsOf: list.items)
        }
    }

    /// Decode once: a title that contains literal `&amp;` must stay literal.
    private static func decode(_ string: String) -> String {
        let named: [String: String] = ["amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " "]
        guard let pattern = try? NSRegularExpression(pattern: #"&(#x[0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);"#) else { return string }
        let source = string as NSString
        let result = NSMutableString(string: string)
        for match in pattern.matches(in: string, range: NSRange(location: 0, length: source.length)).reversed() {
            let entity = source.substring(with: match.range(at: 1))
            let replacement: String?
            if entity.hasPrefix("#x") {
                replacement = UInt32(entity.dropFirst(2), radix: 16).flatMap(UnicodeScalar.init).map(String.init)
            } else if entity.hasPrefix("#") {
                replacement = UInt32(entity.dropFirst()).flatMap(UnicodeScalar.init).map(String.init)
            } else {
                replacement = named[entity]
            }
            if let replacement { result.replaceCharacters(in: match.range, with: replacement) }
        }
        return result as String
    }
}
