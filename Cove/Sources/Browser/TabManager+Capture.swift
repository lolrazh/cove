import AppKit
import UniformTypeIdentifiers

/// Arc's Capture (⌘⇧2, the Command Bar, a page's context menu): a region or
/// an element of the active page as an image, to copy, save, or send to a
/// note.
extension TabManager {
    /// Starts capturing the active page, in region mode.
    func startCapture() {
        guard let page = activePage, page.webView != nil else { return }
        endCapture()
        isShowingSiteControls = false
        capture = CaptureSession(page: page) { [weak self] in self?.endCapture() }
    }

    func endCapture() {
        capture?.stopPicking()
        capture = nil
    }

    /// The capture to the pasteboard, as PNG and TIFF.
    func copyCapture(_ capture: Capture) {
        let item = NSPasteboardItem()
        if let png = capture.pngData { item.setData(png, forType: .png) }
        if let tiff = capture.image.tiffRepresentation { item.setData(tiff, forType: .tiff) }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([item])
        endCapture()
        toasts.show("Copied Capture", symbol: ChromeSymbols.Capture.capture)
    }

    /// The notes a capture can go to, most recently changed first.
    var captureDestinations: [DocumentInfo] {
        (documentStore?.documents.values.filter { $0.kind == .note } ?? [])
            .sorted { $0.modifiedAt > $1.modifiedAt }
    }

    /// The capture at the end of a note, or of a new one named for its page;
    /// the note comes on screen.
    func sendCapture(_ capture: Capture, toNote id: UUID?) {
        guard let documentStore else { return }
        let id = id ?? documentStore.create(.note).id
        if documentStore.documents[id]?.title.isEmpty == true {
            documentStore.rename(id, to: capture.source.name)
        }
        documentStore.note(id)?.append(capture)
        endCapture()
        showDocument(id)
    }

    /// The capture as a PNG file, wherever the save sheet says.
    func saveCapture(_ capture: Capture) {
        guard let window = activePage?.webView?.window, let png = capture.pngData else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "\(capture.source.name).png"
        Task {
            guard await panel.beginSheetModal(for: window) == .OK, let url = panel.url else { return }
            if (try? png.write(to: url, options: .atomic)) != nil {
                endCapture()
            } else {
                toasts.show("Couldn't Save Capture", symbol: ChromeSymbols.Navigation.loadFailed)
            }
        }
    }
}
