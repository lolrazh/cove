import AppKit

/// A paragraph's look in a note.
enum NoteTextStyle: CaseIterable {
    case title
    case heading
    case subheading
    case body
    case monospaced

    var name: String {
        switch self {
        case .title: "Title"
        case .heading: "Heading"
        case .subheading: "Subheading"
        case .body: "Body"
        case .monospaced: "Monospaced"
        }
    }

    var font: NSFont {
        switch self {
        case .title: .systemFont(ofSize: 28, weight: .bold)
        case .heading: .systemFont(ofSize: 22, weight: .semibold)
        case .subheading: .systemFont(ofSize: 17, weight: .semibold)
        case .body: .systemFont(ofSize: 17)
        case .monospaced: .monospacedSystemFont(ofSize: 15, weight: .regular)
        }
    }

    var paragraphStyle: NSParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 4
        paragraph.paragraphSpacing = self == .body || self == .monospaced ? 6 : 10
        return paragraph
    }

    var attributes: [NSAttributedString.Key: Any] {
        [.font: font, .foregroundColor: NSColor.textColor, .paragraphStyle: paragraphStyle]
    }

}

/// The lists a note has. A list item starts with its marker between tabs, as
/// AppKit's own lists do, so RTF keeps them; a checklist's marker is a box,
/// checked by clicking it.
enum NoteList: CaseIterable {
    case bulleted
    case numbered
    case dashed
    case checklist

    static let unchecked: Character = "☐"
    static let checked: Character = "☑"

    var name: String {
        switch self {
        case .bulleted: "Bulleted List"
        case .numbered: "Numbered List"
        case .dashed: "Dashed List"
        case .checklist: "Checklist"
        }
    }

    var textList: NSTextList {
        switch self {
        case .bulleted: NSTextList(markerFormat: .disc, options: 0)
        case .dashed: NSTextList(markerFormat: NSTextList.MarkerFormat("–"), options: 0)
        case .numbered: NSTextList(markerFormat: NSTextList.MarkerFormat("{decimal}."), options: 0)
        case .checklist: NSTextList(markerFormat: NSTextList.MarkerFormat(String(Self.unchecked)), options: 0)
        }
    }

    /// The list a paragraph's marker says it's in.
    init?(marker: Substring) {
        guard let first = marker.first else { return nil }
        if first == Self.unchecked || first == Self.checked {
            self = .checklist
        } else if first.isNumber && marker.last == "." && marker.dropLast().allSatisfy(\.isNumber) {
            self = .numbered
        } else if marker == "–" || marker == "-" {
            self = .dashed
        } else if marker == "•" {
            self = .bulleted
        } else {
            return nil
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
            let restored = (text.attribute(.paragraphStyle, at: range.location, effectiveRange: nil) as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle
            let style = restored ?? list.paragraphStyle.mutableCopy() as! NSMutableParagraphStyle
            style.textLists = [list.textList]
            text.addAttribute(.paragraphStyle, value: style, range: range)
        }
    }

    /// Markers sit in a narrow gutter, and wrapped lines line up with the
    /// text after them.
    var paragraphStyle: NSParagraphStyle {
        let style = NoteTextStyle.body.paragraphStyle.mutableCopy() as! NSMutableParagraphStyle
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

    /// Attach a layout without assigning `font` or `textColor`: those setters
    /// rewrite the shared storage and erase saved rich-text formatting.
    static func editor(for note: Note) -> NoteTextView {
        let layout = NSLayoutManager()
        note.text.addLayoutManager(layout)
        let container = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layout.addTextContainer(container)
        let editor = NoteTextView(frame: .zero, textContainer: container)
        editor.isRichText = true
        editor.importsGraphics = true
        editor.allowsUndo = true
        editor.isAutomaticLinkDetectionEnabled = true
        editor.isAutomaticQuoteSubstitutionEnabled = true
        editor.isAutomaticDashSubstitutionEnabled = true
        editor.isContinuousSpellCheckingEnabled = true
        editor.smartInsertDeleteEnabled = true
        editor.usesFindBar = true
        editor.isIncrementalSearchingEnabled = true
        editor.drawsBackground = false
        editor.typingAttributes = NoteTextStyle.body.attributes
        editor.defaultParagraphStyle = NoteTextStyle.body.paragraphStyle
        editor.textContainerInset = NSSize(width: 0, height: 12)
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        editor.setAccessibilityLabel("Note body")
        return editor
    }

    // MARK: - Keys

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard window?.firstResponder === self else { return super.performKeyEquivalent(with: event) }
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        let key = event.charactersIgnoringModifiers?.lowercased()
        if flags == [.command, .shift] {
            switch key {
            case "t": apply(.title)
            case "h": apply(.heading)
            case "j": apply(.subheading)
            case "b": apply(.body)
            case "m": apply(.monospaced)
            case "7", "&": toggle(.bulleted)
            case "8", "*": toggle(.dashed)
            case "9", "(": toggle(.numbered)
            case "l": toggle(.checklist)
            case "u": toggleCheckedItem()
            default: return super.performKeyEquivalent(with: event)
            }
            return true
        }
        guard flags == .command else { return super.performKeyEquivalent(with: event) }
        switch key {
        case "b": toggleFontTrait(.boldFontMask)
        case "i": toggleFontTrait(.italicFontMask)
        case "u": toggleLine(.underlineStyle)
        case "k": editLink()
        case "]" where currentList != nil: indentList(by: 1)
        case "[" where currentList != nil: indentList(by: -1)
        default: return super.performKeyEquivalent(with: event)
        }
        return true
    }

    /// Return continues a list. A second Return ends it. A heading ends at
    /// the paragraph break, so the next sentence starts in body text.
    override func insertNewline(_ sender: Any?) {
        guard let item = listItem(at: selectedRange().location) else {
            let wasHeading = [.title, .heading, .subheading].contains(formatting.style)
            super.insertNewline(sender)
            if wasHeading { apply(.body) }
            return
        }
        if item.content.length == 0 {
            replace(item.marker, with: NSAttributedString(string: ""), paragraphStyle: NoteTextStyle.body.paragraphStyle)
        } else {
            let number = item.list == .numbered ? item.number + 1 : 1
            typingAttributes[.strikethroughStyle] = nil
            insertText("\n" + item.list.marker(forItem: number), replacementRange: selectedRange())
        }
    }

    override func deleteBackward(_ sender: Any?) {
        if selectedRange().length == 0, let item = listItem(at: selectedRange().location), selectedRange().location == item.content.location {
            replace(item.marker, with: NSAttributedString(string: ""), paragraphStyle: NoteTextStyle.body.paragraphStyle)
        } else {
            super.deleteBackward(sender)
        }
    }

    override func insertTab(_ sender: Any?) {
        if currentList != nil { indentList(by: 1) } else { super.insertTab(sender) }
    }

    override func insertBacktab(_ sender: Any?) {
        if currentList != nil { indentList(by: -1) } else { super.insertBacktab(sender) }
    }

    override func insertText(_ insertString: Any, replacementRange: NSRange) {
        let typedSpace = insertString as? String == " " && !hasMarkedText()
        super.insertText(insertString, replacementRange: replacementRange)
        guard typedSpace, currentList == nil else { return }
        let range = selectedParagraphs
        let prefix = (string as NSString).substring(with: range)
        let list: NoteList?
        switch prefix {
        case "* ": list = .bulleted
        case "- ": list = .dashed
        case "1. ": list = .numbered
        case "[] ": list = .checklist
        default: list = nil
        }
        guard let list else { return }
        let marker = NSAttributedString(string: list.marker(forItem: 1), attributes: typingAttributes)
        replace(range, with: marker, paragraphStyle: list.paragraphStyle)
    }

    func toggleCheckedItem() {
        guard let item = listItem(at: selectedRange().location), item.list == .checklist else { return }
        toggleCheck(item)
    }

    func showFindBar() {
        let item = NSMenuItem()
        item.tag = NSTextFinder.Action.showFindInterface.rawValue
        performTextFinderAction(item)
    }

    func indentList(by level: Int) {
        guard currentList != nil else { return }
        changeAttributes(in: [selectedParagraphs]) { range in
            self.textStorage?.enumerateAttribute(.paragraphStyle, in: range) { value, run, _ in
                guard let old = value as? NSParagraphStyle, !old.textLists.isEmpty,
                      let style = old.mutableCopy() as? NSMutableParagraphStyle else { return }
                let indent = min(120, max(0, old.firstLineHeadIndent + CGFloat(level) * 24))
                let delta = indent - old.firstLineHeadIndent
                style.firstLineHeadIndent = indent
                style.headIndent += delta
                style.tabStops = old.tabStops.map { NSTextTab(textAlignment: $0.alignment, location: $0.location + delta) }
                self.textStorage?.addAttribute(.paragraphStyle, value: style, range: run)
            }
        }
        if let textStorage, selectedRange().location < textStorage.length {
            typingAttributes[.paragraphStyle] = textStorage.attribute(.paragraphStyle, at: selectedRange().location, effectiveRange: nil)
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
            self.textStorage?.enumerateAttribute(.paragraphStyle, in: range) { value, run, _ in
                let paragraph = (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
                paragraph.lineSpacing = style.paragraphStyle.lineSpacing
                paragraph.paragraphSpacing = style.paragraphStyle.paragraphSpacing
                self.textStorage?.addAttribute(.paragraphStyle, value: paragraph, range: run)
            }
        }
        typingAttributes[.font] = style.font
        let paragraph = (typingAttributes[.paragraphStyle] as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
        paragraph.lineSpacing = style.paragraphStyle.lineSpacing
        paragraph.paragraphSpacing = style.paragraphStyle.paragraphSpacing
        typingAttributes[.paragraphStyle] = paragraph
        NotificationCenter.default.post(name: NSTextView.didChangeTypingAttributesNotification, object: self)
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
            replacement.addAttribute(.paragraphStyle, value: removing ? NoteTextStyle.body.paragraphStyle : list.paragraphStyle, range: NSRange(location: start, length: length))
        }
        let selectedWholeParagraphs = selectedRange().length > 0
        replaceCharacters(in: range, withUndoable: replacement)
        if selectedWholeParagraphs { setSelectedRange(NSRange(location: range.location, length: replacement.length)) }
        typingAttributes[.paragraphStyle] = removing ? NoteTextStyle.body.paragraphStyle : list.paragraphStyle
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
        guard let textStorage, textStorage.length > 0, index >= 0, index <= textStorage.length else { return nil }
        let text = textStorage.string as NSString
        let paragraph = text.paragraphRange(for: NSRange(location: index, length: 0))
        guard paragraph.length > 0,
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
        var range = selectedRange()
        // A selection ending at the next paragraph does not format that paragraph.
        if range.length > 0 { range.length -= 1 }
        return (string as NSString).paragraphRange(for: range)
    }

    var currentList: NoteList? { listItem(at: selectedRange().location)?.list }

    struct Formatting: Equatable {
        var style: NoteTextStyle = .body
        var bold = false
        var italic = false
        var underline = false
        var list: NoteList?
    }

    var formatting: Formatting {
        let font = currentFont
        let traits = NSFontManager.shared.traits(of: font)
        let style = NoteTextStyle.allCases.first { $0.font == font } ?? .body
        let attributes = selectedRange().length > 0 ? textStorage?.attributes(at: selectedRange().location, effectiveRange: nil) ?? typingAttributes : typingAttributes
        return Formatting(style: style, bold: traits.contains(.boldFontMask), italic: traits.contains(.italicFontMask), underline: (attributes[.underlineStyle] as? Int ?? 0) != 0, list: currentList)
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
        breakUndoCoalescing()
        guard let textStorage, shouldChangeText(inRanges: ranges.map { NSValue(range: $0) }, replacementStrings: nil) else { return }
        textStorage.beginEditing()
        ranges.forEach(change)
        textStorage.endEditing()
        didChangeText()
    }

    private func replaceCharacters(in range: NSRange, withUndoable replacement: NSAttributedString) {
        breakUndoCoalescing()
        guard let textStorage, shouldChangeText(in: range, replacementString: replacement.string) else { return }
        textStorage.replaceCharacters(in: range, with: replacement)
        didChangeText()
        setSelectedRange(NSRange(location: range.location + replacement.length, length: 0))
    }

    /// Replaces a range and gives its paragraph a style, as one undoable change.
    private func replace(_ range: NSRange, with replacement: NSAttributedString, paragraphStyle: NSParagraphStyle) {
        undoManager?.beginUndoGrouping()
        defer { undoManager?.endUndoGrouping() }
        replaceCharacters(in: range, withUndoable: replacement)
        let paragraph = (string as NSString).paragraphRange(for: NSRange(location: range.location, length: 0))
        changeAttributes(in: [paragraph]) { self.textStorage?.addAttribute(.paragraphStyle, value: paragraphStyle, range: $0) }
        typingAttributes[.paragraphStyle] = paragraphStyle
    }
}
