import SwiftUI
import AppKit

/// The Command Bar's text field. AppKit, because the list's keys (arrows,
/// Return, Tab, Escape) must be read while the field holds focus, and because
/// inline completion needs to set the selection.
///
/// `text` is what was typed. A completion is shown as a selected suffix after
/// it, which the next keystroke replaces, so the binding never contains it
/// until it's accepted.
struct CommandBarField: NSViewRepresentable {
    enum Key {
        case moveUp
        case moveDown
        case submit(newTab: Bool)
        case cancel
    }

    @Binding var text: String
    let completion: String?
    let placeholder: String
    let onKey: (Key) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> FieldView {
        let field = FieldView()
        field.delegate = context.coordinator
        field.isBezeled = false
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.usesSingleLineMode = true
        field.cell?.isScrollable = true
        field.font = .preferredFont(forTextStyle: .title2)
        field.placeholderString = placeholder
        field.stringValue = text
        field.onCommandReturn = { [coordinator = context.coordinator] in
            coordinator.parent.onKey(.submit(newTab: true))
        }
        return field
    }

    func updateNSView(_ field: FieldView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self

        if field.stringValue != text, field.stringValue != coordinator.shownCompletion {
            field.stringValue = text
            coordinator.shownCompletion = nil
        }

        guard coordinator.wantsCompletion else { return }
        coordinator.wantsCompletion = false
        guard let completion, completion.hasPrefix(text), completion != text,
              let editor = field.currentEditor() else { return }

        field.stringValue = completion
        let typedLength = text.utf16.count
        editor.selectedRange = NSRange(location: typedLength, length: completion.utf16.count - typedLength)
        coordinator.shownCompletion = completion
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: CommandBarField
        /// Set when the last change extended the typed text, which is the only
        /// time a completion should appear: never while deleting.
        var wantsCompletion = false
        /// The full text on display while a completion suffix is selected.
        var shownCompletion: String?
        private var typed: String

        init(_ parent: CommandBarField) {
            self.parent = parent
            self.typed = parent.text
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            let current = field.stringValue
            wantsCompletion = current.count > typed.count && current.hasPrefix(typed)
            shownCompletion = nil
            typed = current
            parent.text = current
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.moveUp(_:)):
                parent.onKey(.moveUp)
            case #selector(NSResponder.moveDown(_:)):
                parent.onKey(.moveDown)
            case #selector(NSResponder.insertNewline(_:)):
                parent.onKey(.submit(newTab: false))
            case #selector(NSResponder.cancelOperation(_:)):
                parent.onKey(.cancel)
            case #selector(NSResponder.insertTab(_:)):
                acceptCompletion(in: textView)
            case #selector(NSResponder.moveRight(_:)), #selector(NSResponder.moveToEndOfLine(_:)):
                // Moving past the suffix accepts it, as in Safari. Otherwise
                // the caret moves as usual.
                guard shownCompletion != nil, textView.selectedRange().length > 0 else { return false }
                acceptCompletion(in: textView)
            default:
                return false
            }
            return true
        }

        private func acceptCompletion(in textView: NSTextView) {
            guard shownCompletion != nil else { return }
            let accepted = textView.string
            textView.setSelectedRange(NSRange(location: accepted.utf16.count, length: 0))
            shownCompletion = nil
            typed = accepted
            parent.text = accepted
        }
    }

    /// Takes focus on arrival and gives it back on departure, so the page's
    /// keyboard focus survives a trip through the Command Bar.
    final class FieldView: NSTextField {
        var onCommandReturn: (() -> Void)?
        private weak var previousResponder: NSResponder?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            previousResponder = window.firstResponder
            DispatchQueue.main.async {
                window.makeFirstResponder(self)
            }
        }

        override func viewWillMove(toWindow newWindow: NSWindow?) {
            super.viewWillMove(toWindow: newWindow)
            guard newWindow == nil, let window, currentEditor() != nil else { return }
            window.makeFirstResponder(restorableResponder(in: window))
        }

        /// The previous responder, if it's still a view in the window. A field
        /// editor stands in for the control it was editing, which may be gone.
        private func restorableResponder(in window: NSWindow) -> NSResponder? {
            var candidate = previousResponder as? NSView
            if let editor = candidate as? NSTextView, editor.isFieldEditor {
                candidate = editor.delegate as? NSView
            }
            return candidate?.window == window ? candidate : nil
        }

        /// ⌘Return never reaches the field editor as a command, so catch it here.
        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            let isReturn = event.keyCode == 36 || event.keyCode == 76
            if isReturn, event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command {
                onCommandReturn?()
                return true
            }
            return super.performKeyEquivalent(with: event)
        }
    }
}
