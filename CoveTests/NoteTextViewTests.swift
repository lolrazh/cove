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
    @Test func `heading return resumes body and retains the heading`() throws {
        let (note, editor, window) = editor("Heading")
        defer { window.contentView = nil }
        editor.setSelectedRange(NSRange(location: note.text.length, length: 0))
        editor.apply(.heading)
        editor.insertNewline(nil)
        editor.insertText("Body", replacementRange: editor.selectedRange())
        #expect(note.text.attribute(.font, at: 0, effectiveRange: nil) as? NSFont == NoteTextStyle.heading.font)
        #expect(note.text.attribute(.font, at: 8, effectiveRange: nil) as? NSFont == NoteTextStyle.body.font)
    }

    @Test func `paragraph formatting stops before the next unselected paragraph`() {
        let (note, editor, window) = editor("One\nTwo")
        defer { window.contentView = nil }
        editor.setSelectedRange(NSRange(location: 0, length: 4))
        editor.apply(.heading)
        #expect(note.text.attribute(.font, at: 4, effectiveRange: nil) as? NSFont == NoteTextStyle.body.font)
    }

    @Test(arguments: NoteList.allCases)
    func `lists continue end and undo as native text`(list: NoteList) {
        let (_, editor, window) = editor("First")
        defer { window.contentView = nil }
        editor.setSelectedRange(NSRange(location: 5, length: 0))
        editor.toggle(list)
        editor.insertNewline(nil)
        let second = list.marker(forItem: list == .numbered ? 2 : 1)
        #expect(editor.string == list.marker(forItem: 1) + "First\n" + second)
        // Preparation is not part of the edit being undone.
        editor.breakUndoCoalescing()
        editor.undoManager?.removeAllActions()
        editor.undoManager?.beginUndoGrouping()
        editor.insertNewline(nil)
        editor.undoManager?.endUndoGrouping()
        #expect(editor.string == list.marker(forItem: 1) + "First\n")
        editor.undoManager?.undo()
        #expect(editor.string.hasSuffix(second))
        editor.undoManager?.redo()
        editor.insertNewline(nil)
        #expect(!editor.string.hasSuffix(second))
        #expect(editor.currentList == nil)
    }

    @Test func `list formatting preserves a multi paragraph selection`() {
        let (_, editor, window) = editor("One\nTwo")
        defer { window.contentView = nil }
        editor.setSelectedRange(NSRange(location: 0, length: 7))
        editor.toggle(.bulleted)
        #expect(editor.selectedRange() == NSRange(location: 0, length: editor.string.utf16.count))
        editor.toggle(.bulleted)
        #expect(editor.string == "One\nTwo")
    }

    @Test func `typing a list prefix and backspacing the marker are reversible`() {
        let (_, editor, window) = editor()
        defer { window.contentView = nil }
        editor.insertText("-", replacementRange: editor.selectedRange())
        editor.insertText(" ", replacementRange: editor.selectedRange())
        #expect(editor.currentList == .dashed)
        editor.deleteBackward(nil)
        #expect(editor.string.isEmpty)
        #expect(editor.currentList == nil)
    }

    @Test func `checklist completion does not carry into the next item`() {
        let (_, editor, window) = editor("Finish")
        defer { window.contentView = nil }
        editor.setSelectedRange(NSRange(location: 6, length: 0))
        editor.toggle(.checklist)
        editor.toggleCheckedItem()
        #expect(editor.string.contains("☑"))
        editor.insertNewline(nil)
        editor.insertText("Next", replacementRange: editor.selectedRange())
        #expect(editor.string == "\t☑\tFinish\n\t☐\tNext")
        #expect(editor.typingAttributes[.strikethroughStyle] == nil)
    }

    @Test func `indents survive RTF list restoration and ordinary tabs stay ordinary`() {
        let (note, editor, window) = editor("Item")
        defer { window.contentView = nil }
        editor.toggle(.bulleted)
        editor.indentList(by: 1)
        let saved = NSMutableAttributedString(attributedString: note.text)
        NoteList.flatten(saved)
        NoteList.restore(in: saved)
        #expect((saved.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)?.firstLineHeadIndent == 24)
        let plain = NSMutableAttributedString(string: "\tName\tValue")
        NoteList.restore(in: plain)
        #expect(plain.attribute(.paragraphStyle, at: 0, effectiveRange: nil) == nil)
    }

    @Test func `block quote returns to body without leaving an indent`() {
        let (_, editor, window) = editor("Quoted text")
        defer { window.contentView = nil }
        editor.apply(.quote)
        #expect(editor.formatting.style == .quote)
        editor.apply(.body)
        #expect(editor.formatting.style == .body)
        #expect((editor.typingAttributes[.paragraphStyle] as? NSParagraphStyle)?.headIndent == 0)
    }

    @Test func `highlight toggles without changing text or selection`() {
        let (note, editor, window) = editor("Highlight these words")
        defer { window.contentView = nil }
        let selection = NSRange(location: 10, length: 5)
        editor.setSelectedRange(selection)
        editor.toggleHighlight()
        #expect(note.text.attribute(.backgroundColor, at: 10, effectiveRange: nil) != nil)
        #expect(note.text.attribute(.backgroundColor, at: 0, effectiveRange: nil) == nil)
        editor.toggleHighlight()
        #expect(note.text.attribute(.backgroundColor, at: 10, effectiveRange: nil) == nil)
        #expect(editor.selectedRange() == selection)
        #expect(editor.string == "Highlight these words")
    }

    @Test func `table keys move between cells and append an undoable row`() {
        let (note, editor, window) = editor()
        defer { window.contentView = nil }
        let table = NSTextTable()
        table.numberOfColumns = 2
        for row in 0..<2 {
            for column in 0..<2 {
                let cell = NSTextTableBlock(table: table, startingRow: row, rowSpan: 1, startingColumn: column, columnSpan: 1)
                let style = NoteTextStyle.body.paragraphStyle.mutableCopy() as! NSMutableParagraphStyle
                style.textBlocks = [cell]
                var attributes = NoteTextStyle.body.attributes
                attributes[.paragraphStyle] = style
                note.text.append(NSAttributedString(string: "Cell\n", attributes: attributes))
            }
        }
        editor.setSelectedRange(NSRange(location: 0, length: 0))
        editor.insertTab(nil)
        #expect(editor.selectedRange().location == 5)
        editor.insertNewline(nil)
        #expect(editor.selectedRange().location == 15)
        editor.insertBacktab(nil)
        #expect(editor.selectedRange().location == 10)
        editor.insertLineBreak(nil)
        #expect(editor.selectedRange().location == 0)
        editor.setSelectedRange(NSRange(location: 15, length: 0))
        editor.undoManager?.removeAllActions()
        editor.insertNewline(nil)
        #expect(editor.selectedRange().location == 21)
        #expect(note.text.length == 22)
        editor.undoManager?.undo()
        #expect(note.text.length == 20)
    }

    @Test func `inserting a numbered item updates the following numbers`() {
        let (_, editor, window) = editor("First\nLast")
        defer { window.contentView = nil }
        editor.setSelectedRange(NSRange(location: 0, length: editor.string.utf16.count))
        editor.toggle(.numbered)
        let firstLine = (editor.string as NSString).range(of: "\n").location
        editor.setSelectedRange(NSRange(location: firstLine, length: 0))
        editor.insertNewline(nil)
        editor.insertText("Middle", replacementRange: editor.selectedRange())
        #expect(editor.string == "\t1.\tFirst\n\t2.\tMiddle\n\t3.\tLast")
    }

}
