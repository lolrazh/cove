import SwiftUI

/// A name edited where it's shown: a tab's title or a folder's name. It takes
/// focus as it appears with the whole name selected, so typing replaces it.
/// Return and clicking away keep the new name; Escape cancels.
struct RenameField: View {
    let prompt: String
    @Binding var text: String
    let onCommit: () -> Void
    let onCancel: () -> Void

    @FocusState private var isFocused: Bool
    @State private var selection: TextSelection?

    var body: some View {
        // Keep the insertion point visible when a name exceeds the row width.
        TextField(prompt, text: $text, selection: $selection, axis: .horizontal)
            .lineLimit(1)
            .textFieldStyle(.plain)
            .focused($isFocused)
            .onAppear { isFocused = true }
            .onSubmit(onCommit)
            .onExitCommand(perform: onCancel)
            .onChange(of: isFocused) { _, isFocused in
                if isFocused {
                    selection = TextSelection(range: text.startIndex..<text.endIndex)
                } else {
                    onCommit()
                }
            }
    }
}
