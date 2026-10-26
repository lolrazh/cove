import SwiftUI
import AppKit

/// A plain single-line field for URLs. Return submits and Escape cancels, and
/// both hand keyboard focus back to the window, like Safari's address field.
struct AddressTextField: NSViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool

    let placeholder: String
    /// A change in this value focuses the field and selects its text. `nil`
    /// means this field isn't the one Command-L should reach right now; the
    /// request is dropped rather than queued for when it next becomes live.
    let focusRequest: Int?
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let textField = FocusReportingTextField()
        textField.delegate = context.coordinator
        textField.onBecomeFirstResponder = { [coordinator = context.coordinator] in
            coordinator.parent.isFocused = true
        }
        textField.isBezeled = false
        textField.isBordered = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.usesSingleLineMode = true
        textField.lineBreakMode = .byTruncatingMiddle
        textField.font = .systemFont(ofSize: 13)
        textField.placeholderString = placeholder
        textField.stringValue = text
        return textField
    }

    func updateNSView(_ textField: NSTextField, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        textField.placeholderString = placeholder

        if !coordinator.isEditing, textField.stringValue != text {
            textField.stringValue = text
        }

        defer { coordinator.lastFocusRequest = focusRequest }
        guard let focusRequest, let last = coordinator.lastFocusRequest, last != focusRequest else { return }

        DispatchQueue.main.async {
            textField.window?.makeFirstResponder(textField)
            textField.currentEditor()?.selectAll(nil)
            textField.selectText(nil)
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: AddressTextField
        var isEditing = false
        var lastFocusRequest: Int?

        init(_ parent: AddressTextField) {
            self.parent = parent
            self.lastFocusRequest = parent.focusRequest
        }

        func controlTextDidBeginEditing(_ notification: Notification) {
            isEditing = true
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            isEditing = false
            parent.isFocused = false
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            parent.text = textField.stringValue
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.insertNewline(_:)):
                parent.text = textView.string
                parent.onSubmit()
            case #selector(NSResponder.cancelOperation(_:)):
                break
            default:
                return false
            }
            // Ending editing this way fires `controlTextDidEndEditing`, where
            // the owner restores the field to the page's URL.
            control.window?.makeFirstResponder(nil)
            return true
        }
    }
}

/// `controlTextDidBeginEditing` only fires on the first keystroke, so a field
/// that was clicked or focused by Command-L wouldn't look focused until typed
/// into. Becoming first responder is the moment focus actually arrives.
private final class FocusReportingTextField: NSTextField {
    var onBecomeFirstResponder: (() -> Void)?

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { onBecomeFirstResponder?() }
        return accepted
    }
}
