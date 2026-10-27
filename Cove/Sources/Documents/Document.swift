import Foundation

/// What a document is: Arc's note, rich text in the page card.
enum DocumentKind: String, Codable, CaseIterable {
    case note

    /// What one is called, as in "Pin Note".
    var name: String {
        switch self {
        case .note: "Note"
        }
    }

    /// What a document without a title is called.
    var untitledName: String {
        switch self {
        case .note: "Untitled Note"
        }
    }

    var symbol: String {
        switch self {
        case .note: ChromeSymbols.Documents.note
        }
    }

    /// The extension of the file the document is kept in.
    var fileExtension: String {
        switch self {
        case .note: "rtfd"
        }
    }
}

/// A note as the index knows it: enough to list it in the sidebar and find
/// it from the Command Bar without opening its file.
struct DocumentInfo: Identifiable, Codable, Hashable {
    let id: UUID
    let kind: DocumentKind
    var title: String
    /// The document's words, for finding it by what it says.
    var text: String
    let createdAt: Date
    var modifiedAt: Date
    /// When it was last on screen: like a tab's, it decides when Today lets
    /// the document go.
    var lastUsedAt: Date

    init(id: UUID = UUID(), kind: DocumentKind, title: String = "", text: String = "", at date: Date = .now) {
        self.id = id
        self.kind = kind
        self.title = title
        self.text = text
        createdAt = date
        modifiedAt = date
        lastUsedAt = date
    }

    /// The title, or what an untitled document is called.
    var displayTitle: String {
        title.isEmpty ? kind.untitledName : title
    }
}
