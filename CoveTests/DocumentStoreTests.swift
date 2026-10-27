import AppKit
import Testing
@testable import Cove

@MainActor
struct DocumentStoreTests {
    private let directory = FileManager.default.temporaryDirectory.appendingPathComponent("CoveTests-\(UUID().uuidString)/Documents")

    @Test func `a note and its text come back from its file`() throws {
        let before = DocumentStore(directory: directory)
        let document = before.create(.note)
        before.rename(document.id, to: "Groceries")
        let note = try #require(before.note(document.id))
        note.text.append(NSAttributedString(string: "Milk and eggs", attributes: [.font: NSFont.boldSystemFont(ofSize: 14)]))
        before.save()

        let after = DocumentStore(directory: directory)
        #expect(after.documents[document.id]?.title == "Groceries")
        #expect(after.documents[document.id]?.text == "Milk and eggs")
        let reopened = try #require(after.note(document.id))
        #expect(reopened.text.string == "Milk and eggs")
        let font = reopened.text.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        #expect(font.map { NSFontManager.shared.traits(of: $0).contains(.boldFontMask) } == true)
    }

    @Test func `lists and checked items survive a save`() throws {
        let before = DocumentStore(directory: directory)
        let document = before.create(.note)
        let note = try #require(before.note(document.id))
        let lines = [
            (NoteList.checklist.marker(forItem: 1).replacingOccurrences(of: "☐", with: "☑") + "Bread\n", NoteList.checklist),
            (NoteList.numbered.marker(forItem: 1) + "One\n", NoteList.numbered),
            (NoteList.bulleted.marker(forItem: 1) + "Dot", NoteList.bulleted),
        ]
        for (line, list) in lines {
            note.text.append(NSAttributedString(string: line, attributes: [.paragraphStyle: list.paragraphStyle]))
        }
        before.save()

        let reopened = try #require(DocumentStore(directory: directory).note(document.id))
        #expect(reopened.text.string == "\t☑\tBread\n\t1.\tOne\n\t•\tDot")
        for line in [0, 10, 18] {
            let style = reopened.text.attribute(.paragraphStyle, at: line, effectiveRange: nil) as? NSParagraphStyle
            #expect(style?.textLists.isEmpty == false)
        }
    }

    @Test func `a deleted note leaves no file behind`() throws {
        let store = DocumentStore(directory: directory)
        let document = store.create(.note)
        try #require(store.note(document.id)).text.append(NSAttributedString(string: "Gone"))
        store.save()
        let file = directory.appendingPathComponent("\(document.id.uuidString).rtfd")
        #expect(FileManager.default.fileExists(atPath: file.path))

        store.delete(document.id)
        store.save()
        #expect(!FileManager.default.fileExists(atPath: file.path))
        #expect(DocumentStore(directory: directory).documents.isEmpty)
    }

    @Test func `a store without a directory keeps nothing`() {
        let store = DocumentStore(directory: nil)
        let document = store.create(.note)
        store.note(document.id)?.text.append(NSAttributedString(string: "Nowhere"))
        store.save()
        #expect(store.documents[document.id] != nil)
        #expect(DocumentStore(directory: nil).documents.isEmpty)
    }
}
