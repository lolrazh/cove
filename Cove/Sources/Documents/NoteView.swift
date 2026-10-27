import SwiftUI

/// A note in the page card: a formatting bar, then its title and text in a
/// column that keeps lines readable.
struct NoteView: View {
    let id: UUID
    let note: Note
    @ObservedObject var store: DocumentStore
    let onOpenLink: (URL) -> Void

    @State private var textView: NoteTextView?
    @FocusState private var isTitleFocused: Bool

    private static let columnWidth: CGFloat = 720

    var body: some View {
        VStack(spacing: 0) {
            NoteFormattingBar(textView: textView)
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                titleField
                NoteTextEditor(note: note, onOpenLink: onOpenLink) { textView = $0 }
            }
            .frame(maxWidth: Self.columnWidth)
            .padding(.top, 28)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(ChromePalette.content)
        // A new note asks for its title first.
        .onAppear { isTitleFocused = store.documents[id]?.title.isEmpty ?? false }
    }

    /// Return moves on to the text.
    private var titleField: some View {
        TextField(
            store.documents[id]?.kind.untitledName ?? "",
            text: Binding(get: { store.documents[id]?.title ?? "" }, set: { store.rename(id, to: $0) })
        )
        .textFieldStyle(.plain)
        .font(.system(size: 28, weight: .bold))
        .focused($isTitleFocused)
        .onSubmit { textView?.window?.makeFirstResponder(textView) }
        // The text's own line padding, so title and text line up.
        .padding(.horizontal, NSTextContainer().lineFragmentPadding)
    }
}

/// Styles, character traits, lists and links for the note's text view.
private struct NoteFormattingBar: View {
    let textView: NoteTextView?

    var body: some View {
        HStack(spacing: 2) {
            Menu {
                ForEach(NoteTextStyle.allCases, id: \.self) { style in
                    Button(style.name) { textView?.apply(style) }
                }
            } label: {
                Image(systemName: "textformat.size")
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .buttonStyle(ChromeButtonStyle())
            .fixedSize()
            .help("Text Style")

            separator
            button("Bold", symbol: "bold") { $0.toggleFontTrait(.boldFontMask) }
            button("Italic", symbol: "italic") { $0.toggleFontTrait(.italicFontMask) }
            button("Underline", symbol: "underline") { $0.toggleLine(.underlineStyle) }
            button("Strikethrough", symbol: "strikethrough") { $0.toggleLine(.strikethroughStyle) }
            separator
            button(NoteList.bulleted.name, symbol: "list.bullet") { $0.toggle(.bulleted) }
            button(NoteList.numbered.name, symbol: "list.number") { $0.toggle(.numbered) }
            button(NoteList.checklist.name, symbol: "checklist") { $0.toggle(.checklist) }
            separator
            button("Link", symbol: ChromeSymbols.Navigation.link) { $0.editLink() }
        }
        .disabled(textView == nil)
        .frame(maxWidth: .infinity)
        .frame(height: ChromeMetrics.navigationBarHeight)
    }

    private var separator: some View {
        Divider().frame(height: 16).padding(.horizontal, 6)
    }

    private func button(_ title: String, symbol: String, action: @escaping (NoteTextView) -> Void) -> some View {
        Button {
            guard let textView else { return }
            action(textView)
            textView.window?.makeFirstResponder(textView)
        } label: {
            Image(systemName: symbol)
        }
        .buttonStyle(ChromeButtonStyle())
        .help(title)
    }
}

/// The note's text in a scroll view. Each editor lays out the note's one
/// text storage itself, so the same note in two windows stays in step.
private struct NoteTextEditor: NSViewRepresentable {
    let note: Note
    let onOpenLink: (URL) -> Void
    let onMake: (NoteTextView) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let layoutManager = NSLayoutManager()
        note.text.addLayoutManager(layoutManager)
        let container = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layoutManager.addTextContainer(container)

        let textView = NoteTextView(frame: .zero, textContainer: container)
        textView.isRichText = true
        textView.importsGraphics = true
        textView.allowsUndo = true
        textView.isAutomaticLinkDetectionEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = true
        textView.isAutomaticDashSubstitutionEnabled = true
        textView.drawsBackground = false
        textView.textColor = .textColor
        textView.font = Note.bodyFont
        textView.typingAttributes = [.font: Note.bodyFont, .foregroundColor: NSColor.textColor]
        textView.textContainerInset = NSSize(width: 0, height: 8)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.onOpenLink = onOpenLink

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = textView
        DispatchQueue.main.async { onMake(textView) }
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        (scrollView.documentView as? NoteTextView)?.onOpenLink = onOpenLink
    }

    /// The editor's layout leaves the note's text storage with it.
    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: ()) {
        guard let layoutManager = (scrollView.documentView as? NSTextView)?.layoutManager else { return }
        layoutManager.textStorage?.removeLayoutManager(layoutManager)
    }
}
