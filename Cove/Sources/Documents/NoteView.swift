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

    private static let columnWidth: CGFloat = 680

    var body: some View {
        VStack(spacing: 0) {
            NoteFormattingBar(textView: textView)
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                titleField
                NoteTextEditor(note: note, onOpenLink: onOpenLink) { textView = $0 }
            }
            .frame(maxWidth: Self.columnWidth)
            .padding(.top, 32)
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
    @State private var formatting = NoteTextView.Formatting()

    var body: some View {
        HStack(spacing: 6) {
            Menu {
                ForEach(NoteTextStyle.allCases, id: \.self) { style in
                    Button {
                        act { $0.apply(style) }
                    } label: {
                        if formatting.style == style { Label(style.name, systemImage: "checkmark") }
                        else { Text(style.name) }
                    }
                }
                Divider()
                Button("Strikethrough") { act { $0.toggleLine(.strikethroughStyle) } }
            } label: {
                Label("Text Style", systemImage: "textformat")
                    .labelStyle(.iconOnly)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.visible)
            .fixedSize()
            .help("Text style")
            .accessibilityLabel("Text style")

            separator
            button("Bold (⌘B)", symbol: "bold", selected: formatting.bold) { $0.toggleFontTrait(.boldFontMask) }
            button("Italic (⌘I)", symbol: "italic", selected: formatting.italic) { $0.toggleFontTrait(.italicFontMask) }
            button("Underline (⌘U)", symbol: "underline", selected: formatting.underline) { $0.toggleLine(.underlineStyle) }
            separator
            Menu {
                ForEach(NoteList.allCases, id: \.self) { list in
                    Button(list.name) { act { $0.toggle(list) } }
                }
                Divider()
                Button("Indent") { act { $0.indentList(by: 1) } }
                    .disabled(formatting.list == nil)
                Button("Outdent") { act { $0.indentList(by: -1) } }
                    .disabled(formatting.list == nil)
            } label: {
                Image(systemName: "list.bullet")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Lists")
            .accessibilityLabel("Lists")
            button("Checklist (⇧⌘L)", symbol: "checklist", selected: formatting.list == .checklist) { $0.toggle(.checklist) }
            separator
            button("Link (⌘K)", symbol: ChromeSymbols.Navigation.link) { $0.editLink() }
            button("Find in Note (⌘F)", symbol: "magnifyingglass") { $0.showFindBar() }
        }
        .font(.system(size: 14, weight: .medium))
        .disabled(textView == nil)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .onChange(of: textView) { _, _ in refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSTextView.didChangeSelectionNotification)) { notification in
            if notification.object as? NoteTextView === textView { refresh() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSTextView.didChangeTypingAttributesNotification)) { notification in
            if notification.object as? NoteTextView === textView { refresh() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSText.didChangeNotification)) { notification in
            if notification.object as? NoteTextView === textView { refresh() }
        }
    }

    private var separator: some View { Divider().frame(height: 16).padding(.horizontal, 4) }

    private func refresh() { formatting = textView?.formatting ?? .init() }

    private func act(_ action: (NoteTextView) -> Void) {
        guard let textView else { return }
        textView.window?.makeFirstResponder(textView)
        action(textView)
        refresh()
    }

    private func button(_ title: String, symbol: String, selected: Bool = false, action: @escaping (NoteTextView) -> Void) -> some View {
        Button { act(action) } label: {
            Image(systemName: symbol)
                .frame(width: 28, height: 28)
                .background(selected ? Color.primary.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .help(title)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// The note's text in a scroll view. Each editor lays out the note's one
/// text storage itself, so the same note in two windows stays in step.
private struct NoteTextEditor: NSViewRepresentable {
    let note: Note
    let onOpenLink: (URL) -> Void
    let onMake: (NoteTextView) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NoteTextView.editor(for: note)
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
