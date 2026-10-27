import AppKit

/// View Source: the page's HTML, read-only, in a window of its own beside the
/// browser, with the text view's own find bar.
final class SourceWindow: NSWindow {
    /// Windows on screen. AppKit doesn't keep a window alive by itself.
    private static var open: Set<SourceWindow> = []

    static func show(_ source: String, of pageURL: String, over parent: NSWindow?) {
        let window = SourceWindow(source: source)
        window.subtitle = pageURL
        if let parent {
            window.setFrameTopLeftPoint(NSPoint(x: parent.frame.minX + 40, y: parent.frame.maxY - 40))
        } else {
            window.center()
        }
        open.insert(window)
        window.makeKeyAndOrderFront(nil)
    }

    private init(source: String) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        title = "Page Source"
        isReleasedWhenClosed = false

        let scrollView = NSTextView.scrollableTextView()
        if let textView = scrollView.documentView as? NSTextView {
            textView.string = source
            textView.font = .monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
            textView.isEditable = false
            textView.usesFindBar = true
            textView.isIncrementalSearchingEnabled = true
            textView.textContainerInset = NSSize(width: 8, height: 8)
        }
        contentView = scrollView
    }

    override func close() {
        super.close()
        Self.open.remove(self)
    }
}
