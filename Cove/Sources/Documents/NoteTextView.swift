import AppKit

/// A paragraph's look in a note.
enum NoteTextStyle: CaseIterable {
    case title
    case heading
    case subheading
    case body

    var name: String {
        switch self {
        case .title: "Title"
        case .heading: "Heading"
        case .subheading: "Subheading"
        case .body: "Body"
        }
    }

    var font: NSFont {
        switch self {
        case .title: .systemFont(ofSize: 24, weight: .bold)
        case .heading: .systemFont(ofSize: 18, weight: .semibold)
        case .subheading: .systemFont(ofSize: 15, weight: .semibold)
        case .body: .systemFont(ofSize: 14)
        }
    }
}

/// The lists a note has. A list item starts with its marker between tabs, as
/// AppKit's own lists do, so RTF keeps them; a checklist's marker is a box,
/// checked by clicking it.
enum NoteList: CaseIterable {
    case bulleted
    case numbered
    case checklist

    static let unchecked: Character = "☐"
    static let checked: Character = "☑"

    var name: String {
        switch self {
        case .bulleted: "Bulleted List"
        case .numbered: "Numbered List"
        case .checklist: "Checklist"
        }
    }

    var textList: NSTextList {
        switch self {
        case .bulleted: NSTextList(markerFormat: .disc, options: 0)
        case .numbered: NSTextList(markerFormat: NSTextList.MarkerFormat("{decimal}."), options: 0)
        case .checklist: NSTextList(markerFormat: NSTextList.MarkerFormat(String(Self.unchecked)), options: 0)
        }
    }

    /// The list a paragraph's marker says it's in.
    init?(marker: Substring) {
        guard let first = marker.first else { return nil }
        if first == Self.unchecked || first == Self.checked {
            self = .checklist
        } else if first.isNumber {
            self = .numbered
        } else {
            self = .bulleted
        }
    }

    /// An item's marker, with the tabs around it.
    func marker(forItem number: Int) -> String {
        "\t\(textList.marker(forItemNumber: number))\t"
    }

    /// RTF rewrites AppKit's lists as it reads them, losing custom markers,
    /// so a note is saved with its markers as plain text and its paragraphs'
    /// lists dropped; reading it back makes the lists again from the markers.
    static func flatten(_ text: NSMutableAttributedString) {
        text.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: text.length)) { value, range, _ in
            guard let style = value as? NSParagraphStyle, !style.textLists.isEmpty,
                  let flat = style.mutableCopy() as? NSMutableParagraphStyle else { return }
            flat.textLists = []
            text.addAttribute(.paragraphStyle, value: flat, range: range)
        }
    }

    static func restore(in text: NSMutableAttributedString) {
        let string = text.string as NSString
        string.enumerateSubstrings(in: NSRange(location: 0, length: string.length), options: .byParagraphs) { line, range, _, _ in
            guard let line, line.hasPrefix("\t"), let close = line.dropFirst().prefix(8).firstIndex(of: "\t"),
                  let list = NoteList(marker: line[line.index(after: line.startIndex)..<close]) else { return }
            text.addAttribute(.paragraphStyle, value: list.paragraphStyle, range: range)
        }
    }

    /// Markers sit in a narrow gutter, and wrapped lines line up with the
    /// text after them.
    var paragraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.textLists = [textList]
        style.tabStops = [NSTextTab(textAlignment: .natural, location: 6), NSTextTab(textAlignment: .natural, location: 26)]
        style.headIndent = 26
        return style
    }
}

/// A note's text view: rich text with styles, lists, checklists, links and
/// images, every change undoable. ⌘B, ⌘I and ⌘U toggle bold, italic and
/// underline, and ⌘K edits a link, as in most editors.
final class NoteTextView: NSTextView {
    /// A link clicked in the note.
    var onOpenLink: ((URL) -> Void)?

    // MARK: - Keys

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard window?.firstResponder === self,
              event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command else {
            return super.performKeyEquivalent(with: event)
        }
        switch event.charactersIgnoringModifiers {
        case "b": toggleFontTrait(.boldFontMask)
        case "i": toggleFontTrait(.italicFontMask)
        case "u": toggleLine(.underlineStyle)
        case "k": editLink()
        default: return super.performKeyEquivalent(with: event)
        }
        return true
    }

    /// Return in a list starts the next item; in an empty item it ends the list.
    override func insertNewline(_ sender: Any?) {
        guard let item = listItem(at: selectedRange().location) else { return super.insertNewline(sender) }
        if item.content.length == 0 {
            replace(item.marker, with: NSAttributedString(string: ""), paragraphStyle: NSParagraphStyle())
        } else {
            let number = item.list == .numbered ? item.number + 1 : 1
            // A checked item's line through doesn't carry over.
            typingAttributes[.strikethroughStyle] = nil
            insertText("\n" + item.list.marker(forItem: number), replacementRange: selectedRange())
        }
    }

    // MARK: - Clicks

    /// Clicking a checklist's box checks or unchecks the item.
    override func mouseDown(with event: NSEvent) {
        let index = characterIndexForInsertion(at: convert(event.locationInWindow, from: nil))
        // The box is the marker's second character; a click lands either side of it.
        guard let item = listItem(at: index), item.list == .checklist,
              [item.marker.location + 1, item.marker.location + 2].contains(index) else {
            return super.mouseDown(with: event)
        }
        toggleCheck(item)
    }

    override func clicked(onLink link: Any, at charIndex: Int) {
        let url = (link as? URL) ?? (link as? String).flatMap(URL.init)
        if let url, let onOpenLink {
            onOpenLink(url)
        } else {
            super.clicked(onLink: link, at: charIndex)
        }
    }

    // MARK: - Characters

    func toggleFontTrait(_ trait: NSFontTraitMask) {
        let manager = NSFontManager.shared
        let adding = !manager.traits(of: currentFont).contains(trait)
        changeFonts { adding ? manager.convert($0, toHaveTrait: trait) : manager.convert($0, toNotHaveTrait: trait) }
    }

    /// Underline or strikethrough: on for all of the selection, or off.
    func toggleLine(_ key: NSAttributedString.Key) {
        let ranges = selectedTextRanges
        let isOn = ((ranges.first.map { textStorage?.attribute(key, at: $0.location, effectiveRange: nil) } ?? typingAttributes[key]) as? Int ?? 0) != 0
        let value: Int? = isOn ? nil : NSUnderlineStyle.single.rawValue
        guard !ranges.isEmpty else {
            typingAttributes[key] = value
            return
        }
        changeAttributes(in: ranges) { range in
            if let value { self.textStorage?.addAttribute(key, value: value, range: range) } else { self.textStorage?.removeAttribute(key, range: range) }
        }
    }

    /// A style for the paragraphs the selection touches.
    func apply(_ style: NoteTextStyle) {
        changeAttributes(in: [selectedParagraphs]) { range in
            self.textStorage?.addAttribute(.font, value: style.font, range: range)
        }
        typingAttributes[.font] = style.font
    }

    /// ⌘K: a sheet asking for the selection's link, filled in with the one it
    /// has, or an address on the pasteboard. With nothing selected the address
    /// goes in as its own link.
    func editLink() {
        guard let window else { return }
        let range = selectedRange()
        let existing = range.length > 0 ? textStorage?.attribute(.link, at: range.location, effectiveRange: nil) : nil
        let field = NSTextField(string: (existing as? URL)?.absoluteString
            ?? (existing as? String)
            ?? NSPasteboard.general.string(forType: .string).flatMap { URL(string: $0)?.scheme != nil ? $0 : nil }
            ?? "")
        field.placeholderString = "https://"
        field.frame.size.width = 280

        let alert = NSAlert()
        alert.messageText = existing == nil ? "Add Link" : "Edit Link"
        alert.accessoryView = field
        alert.addButton(withTitle: existing == nil ? "Add" : "Save")
        alert.addButton(withTitle: "Cancel")
        if existing != nil { alert.addButton(withTitle: "Remove Link") }
        alert.window.initialFirstResponder = field
        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self else { return }
            switch response {
            case .alertFirstButtonReturn:
                guard let url = URL(string: field.stringValue.trimmingCharacters(in: .whitespaces)), url.scheme != nil else { return }
                setLink(url, in: range)
            case .alertThirdButtonReturn:
                changeAttributes(in: [range]) { self.textStorage?.removeAttribute(.link, range: $0) }
            default:
                break
            }
        }
    }

    private func setLink(_ url: URL, in range: NSRange) {
        guard range.length > 0 else {
            var attributes = typingAttributes
            attributes[.link] = url
            insertText(NSAttributedString(string: url.absoluteString, attributes: attributes), replacementRange: range)
            return
        }
        changeAttributes(in: [range]) { self.textStorage?.addAttribute(.link, value: url, range: $0) }
    }

    // MARK: - Lists

    /// The selected paragraphs become items of the list, or stop being items
    /// if they all are already.
    func toggle(_ list: NoteList) {
        guard let textStorage else { return }
        let range = selectedParagraphs
        let text = textStorage.string as NSString
        var paragraphs: [NSRange] = []
        text.enumerateSubstrings(in: range, options: [.byParagraphs, .substringNotRequired]) { _, _, enclosing, _ in
            paragraphs.append(enclosing)
        }
        if paragraphs.isEmpty { paragraphs = [range] }
        let removing = paragraphs.allSatisfy { listItem(at: $0.location)?.list == list }

        let replacement = NSMutableAttributedString(attributedString: textStorage.attributedSubstring(from: range))
        for (offset, paragraph) in paragraphs.enumerated().reversed() {
            let start = paragraph.location - range.location
            let existing = listItem(at: paragraph.location)?.marker.length ?? 0
            replacement.deleteCharacters(in: NSRange(location: start, length: existing))
            var length = paragraph.length - existing
            if !removing {
                let marker = list.marker(forItem: offset + 1)
                let attributes = start < replacement.length ? replacement.attributes(at: start, effectiveRange: nil) : typingAttributes
                replacement.insert(NSAttributedString(string: marker, attributes: attributes), at: start)
                length += marker.utf16.count
            }
            replacement.addAttribute(.paragraphStyle, value: removing ? NSParagraphStyle() : list.paragraphStyle, range: NSRange(location: start, length: length))
        }
        replaceCharacters(in: range, withUndoable: replacement)
        typingAttributes[.paragraphStyle] = removing ? NSParagraphStyle() : list.paragraphStyle
    }

    /// A list item: its marker's range, its list and number, and its text.
    private struct ListItem {
        let marker: NSRange
        let list: NoteList
        let number: Int
        let content: NSRange
    }

    /// The list item holding a character, if its paragraph is one: it starts
    /// with a tab, a short marker and another tab, and is styled as a list.
    private func listItem(at index: Int) -> ListItem? {
        guard let textStorage, index >= 0, index <= textStorage.length else { return nil }
        let text = textStorage.string as NSString
        let paragraph = text.paragraphRange(for: NSRange(location: min(index, max(text.length - 1, 0)), length: 0))
        guard paragraph.length > 0 || index == text.length,
              let style = textStorage.attribute(.paragraphStyle, at: min(paragraph.location, max(textStorage.length - 1, 0)), effectiveRange: nil) as? NSParagraphStyle,
              !style.textLists.isEmpty else { return nil }
        let line = text.substring(with: paragraph)
        guard line.hasPrefix("\t"), let close = line.dropFirst().prefix(8).firstIndex(of: "\t") else { return nil }
        let marker = line[line.index(after: line.startIndex)..<close]
        guard let list = NoteList(marker: marker) else { return nil }
        let markerLength = line[...close].utf16.count
        let contentLength = paragraph.length - markerLength - (line.hasSuffix("\n") ? 1 : 0)
        return ListItem(
            marker: NSRange(location: paragraph.location, length: markerLength),
            list: list,
            number: Int(marker.filter(\.isNumber)) ?? 1,
            content: NSRange(location: paragraph.location + markerLength, length: max(contentLength, 0))
        )
    }

    /// Checks or unchecks an item: its box, and a line through its text.
    private func toggleCheck(_ item: ListItem) {
        guard let textStorage else { return }
        let range = NSUnionRange(item.marker, item.content)
        let replacement = NSMutableAttributedString(attributedString: textStorage.attributedSubstring(from: range))
        let isChecked = replacement.string.contains(NoteList.checked)
        let box = (replacement.string as NSString).range(of: String(isChecked ? NoteList.checked : NoteList.unchecked))
        replacement.replaceCharacters(in: box, with: String(isChecked ? NoteList.unchecked : NoteList.checked))
        let content = NSRange(location: item.marker.length, length: item.content.length)
        if isChecked {
            replacement.removeAttribute(.strikethroughStyle, range: content)
        } else {
            replacement.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: content)
        }
        replaceCharacters(in: range, withUndoable: replacement)
    }

    // MARK: - Editing

    private var selectedTextRanges: [NSRange] {
        selectedRanges.map(\.rangeValue).filter { $0.length > 0 }
    }

    /// The whole paragraphs the selection touches.
    private var selectedParagraphs: NSRange {
        (string as NSString).paragraphRange(for: selectedRange())
    }

    private var currentFont: NSFont {
        let font = selectedTextRanges.first.flatMap { textStorage?.attribute(.font, at: $0.location, effectiveRange: nil) } ?? typingAttributes[.font]
        return font as? NSFont ?? Note.bodyFont
    }

    /// Changes every font in the selection, or the typing font without one.
    private func changeFonts(_ convert: @escaping (NSFont) -> NSFont) {
        let ranges = selectedTextRanges
        guard !ranges.isEmpty else {
            typingAttributes[.font] = convert(currentFont)
            return
        }
        changeAttributes(in: ranges) { range in
            self.textStorage?.enumerateAttribute(.font, in: range) { value, run, _ in
                self.textStorage?.addAttribute(.font, value: convert(value as? NSFont ?? Note.bodyFont), range: run)
            }
        }
    }

    /// Attribute changes, undoable as one.
    private func changeAttributes(in ranges: [NSRange], _ change: (NSRange) -> Void) {
        guard let textStorage, shouldChangeText(inRanges: ranges.map { NSValue(range: $0) }, replacementStrings: nil) else { return }
        textStorage.beginEditing()
        ranges.forEach(change)
        textStorage.endEditing()
        didChangeText()
    }

    private func replaceCharacters(in range: NSRange, withUndoable replacement: NSAttributedString) {
        guard let textStorage, shouldChangeText(in: range, replacementString: replacement.string) else { return }
        textStorage.replaceCharacters(in: range, with: replacement)
        didChangeText()
        setSelectedRange(NSRange(location: range.location + replacement.length, length: 0))
    }

    /// Replaces a range and gives its paragraph a style, as one undoable change.
    private func replace(_ range: NSRange, with replacement: NSAttributedString, paragraphStyle: NSParagraphStyle) {
        replaceCharacters(in: range, withUndoable: replacement)
        let paragraph = (string as NSString).paragraphRange(for: NSRange(location: range.location, length: 0))
        changeAttributes(in: [paragraph]) { self.textStorage?.addAttribute(.paragraphStyle, value: paragraphStyle, range: $0) }
        typingAttributes[.paragraphStyle] = paragraphStyle
    }
}
