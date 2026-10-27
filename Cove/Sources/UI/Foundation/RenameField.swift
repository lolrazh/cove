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

    var body: some View {
        TextField(prompt, text: $text)
            .textFieldStyle(.plain)
            .focused($isFocused)
            .onAppear { isFocused = true }
            .onSubmit(onCommit)
            .onExitCommand(perform: onCancel)
            .onChange(of: isFocused) { _, isFocused in
                isFocused ? selectAll() : onCommit()
            }
    }

    /// A field focused from code keeps its insertion point where it was,
    /// unlike one clicked into; the field editor behind it can select all,
    /// once it exists.
    private func selectAll() {
        DispatchQueue.main.async {
            (NSApp.keyWindow?.firstResponder as? NSTextView)?.selectAll(nil)
        }
    }
}
