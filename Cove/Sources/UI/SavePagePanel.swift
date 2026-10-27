import AppKit
import UniformTypeIdentifiers

/// Save Page As: a save sheet with a format menu beneath it, as in Safari.
@MainActor
final class SavePagePanel: NSObject {
    enum Format: CaseIterable {
        /// The page and everything it loaded, in one file Safari opens.
        case webArchive
        /// The page's HTML as the server sent it.
        case source

        var title: String {
            switch self {
            case .webArchive: "Web Archive"
            case .source: "Page Source"
            }
        }

        var contentType: UTType {
            switch self {
            case .webArchive: .webArchive
            case .source: .html
            }
        }
    }

    private let panel = NSSavePanel()
    private let formatMenu = NSPopUpButton()

    /// Where to save the page and as what, or nil if cancelled.
    static func run(suggestedName: String, in window: NSWindow) async -> (url: URL, format: Format)? {
        await SavePagePanel(suggestedName: suggestedName).run(in: window)
    }

    private init(suggestedName: String) {
        super.init()
        formatMenu.addItems(withTitles: Format.allCases.map(\.title))
        formatMenu.target = self
        formatMenu.action = #selector(formatChanged)

        let label = NSTextField(labelWithString: "Format:")
        let accessory = NSStackView(views: [label, formatMenu])
        accessory.edgeInsets = NSEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)

        panel.accessoryView = accessory
        panel.nameFieldStringValue = suggestedName
        panel.canSelectHiddenExtension = true
        formatChanged()
    }

    private var format: Format {
        Format.allCases[formatMenu.indexOfSelectedItem]
    }

    private func run(in window: NSWindow) async -> (url: URL, format: Format)? {
        guard await panel.beginSheetModal(for: window) == .OK, let url = panel.url else { return nil }
        return (url, format)
    }

    /// Switching formats swaps the name's extension.
    @objc private func formatChanged() {
        panel.allowedContentTypes = [format.contentType]
    }
}
