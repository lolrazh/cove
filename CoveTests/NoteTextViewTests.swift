import AppKit
import Testing
@testable import Cove

@MainActor
struct NoteTextViewTests {
    private func editor(_ string: String = "") -> (Note, NoteTextView, NSWindow) {
        let note = Note(id: UUID(), fileURL: nil, onSave: { _ in })
        note.text.append(NSAttributedString(string: string, attributes: NoteTextStyle.body.attributes))
        let editor = NoteTextView.editor(for: note)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 700, height: 600), styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = editor
        window.makeFirstResponder(editor)
        return (note, editor, window)
    }

    @Test func `opening editors preserves fonts links and attachments`() throws {
        let note = Note(id: UUID(), fileURL: nil, onSave: { _ in })
        note.text.append(NSAttributedString(string: "A heading", attributes: [.font: NoteTextStyle.heading.font, .link: URL(string: "https://example.com")!]))
        note.text.append(NSAttributedString(attachment: NSTextAttachment()))
        let expected = NSAttributedString(attributedString: note.text)
        let first = NoteTextView.editor(for: note)
        let second = NoteTextView.editor(for: note)
        #expect(first.textStorage === second.textStorage)
        #expect(note.text.isEqual(to: expected))
    }

    @Test func `format changes undo and redo without losing selection`() throws {
        let (note, editor, window) = editor("Hello 👋🏽 world")
        defer { window.contentView = nil }
        editor.setSelectedRange(NSRange(location: 0, length: note.text.length))
        let before = NSAttributedString(attributedString: note.text)
        editor.undoManager?.beginUndoGrouping()
        editor.toggleFontTrait(.boldFontMask)
        editor.undoManager?.endUndoGrouping()
        #expect(editor.undoManager?.canUndo == true)
        editor.undoManager?.undo()
        #expect(note.text.isEqual(to: before))
        editor.undoManager?.redo()
        let font = try #require(note.text.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        #expect(NSFontManager.shared.traits(of: font).contains(.boldFontMask))
        #expect(editor.selectedRange().length == note.text.length)
    }

    @Test func `return in an empty note does not read an invalid character`() {
        let (_, editor, window) = editor()
        defer { window.contentView = nil }
        editor.insertNewline(nil)
        #expect(editor.string == "\n")
    }
}
