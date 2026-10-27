import AppKit

/// A note's text, live. Every editor showing the note lays out this one text
/// storage, so a note open in two windows changes in both as it's typed. It's
/// saved as RTFD, images included, a second after the last change.
@MainActor
final class Note {
    let id: UUID
    let text: NSTextStorage
    private let fileURL: URL?
    /// Told the note's words after each save, for the index.
    private let onSave: (String) -> Void
    private var pendingSave: Task<Void, Never>?
    private var editObserver: NSObjectProtocol?

    /// What new text looks like.
    static var bodyFont: NSFont { NoteTextStyle.body.font }

    init(id: UUID, fileURL: URL?, onSave: @escaping (String) -> Void) {
        self.id = id
        self.fileURL = fileURL
        self.onSave = onSave
        let saved = fileURL.flatMap { try? NSAttributedString(url: $0, options: [.documentType: NSAttributedString.DocumentType.rtfd], documentAttributes: nil) }
        text = NSTextStorage(attributedString: saved ?? NSAttributedString())
        NoteList.restore(in: text)
        // Text is kept without a color and drawn in the system's, so it reads
        // in light and dark mode alike.
        text.addAttribute(.foregroundColor, value: NSColor.textColor, range: NSRange(location: 0, length: text.length))

        editObserver = NotificationCenter.default.addObserver(
            forName: NSTextStorage.didProcessEditingNotification,
            object: text,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleSave() }
        }
    }

    /// Adds a capture at the end: the image, then where it came from.
    func append(_ capture: Capture) {
        guard let png = capture.pngData else { return }
        let image = FileWrapper(regularFileWithContents: png)
        image.preferredFilename = "Capture.png"
        let attributes: [NSAttributedString.Key: Any] = [.font: Self.bodyFont, .foregroundColor: NSColor.textColor]
        let source = NSMutableAttributedString(string: capture.source.title.isEmpty ? capture.source.url.absoluteString : capture.source.title, attributes: attributes)
        source.addAttribute(.link, value: capture.source.url, range: NSRange(location: 0, length: source.length))

        let piece = NSMutableAttributedString(string: text.length > 0 && !text.string.hasSuffix("\n") ? "\n" : "", attributes: attributes)
        piece.append(NSAttributedString(attachment: NSTextAttachment(fileWrapper: image)))
        piece.append(NSAttributedString(string: "\n", attributes: attributes))
        piece.append(source)
        piece.append(NSAttributedString(string: "\n", attributes: attributes))
        text.append(piece)
    }

    private func scheduleSave() {
        pendingSave?.cancel()
        pendingSave = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            self?.save()
        }
    }

    /// Saves now, if anything changed since the last save.
    func save() {
        guard let pendingSave else { return }
        pendingSave.cancel()
        self.pendingSave = nil
        onSave(text.string)
        guard let fileURL else { return }
        let saved = NSMutableAttributedString(attributedString: text)
        let range = NSRange(location: 0, length: saved.length)
        saved.removeAttribute(.foregroundColor, range: range)
        NoteList.flatten(saved)
        let wrapper = try? saved.fileWrapper(from: range, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd])
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? wrapper?.write(to: fileURL, options: .atomic, originalContentsURL: nil)
    }
}
