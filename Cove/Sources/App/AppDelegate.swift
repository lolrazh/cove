import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private let windowToolbarIdentifier = NSToolbar.Identifier("CoveWindowToolbar")

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Cove has its own in-app tab model, so AppKit's window tabbing
        // only creates confusing parallel behavior in the Window menu.
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure no transparent titlebar material (anti-Liquid Glass)
        for window in NSApplication.shared.windows {
            configureWindow(window)
        }

        // Re-apply window config after display changes (prevents titlebar
        // background flash when moving between screens via window managers)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidChangeScreen(_:)),
            name: NSWindow.didChangeScreenNotification,
            object: nil
        )

        // Pre-compile content blocking rules
        if BrowserSettingsStore.shared.contentBlockingEnabled {
            Task { await ContentBlockerManager.shared.load() }
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        for window in NSApplication.shared.windows {
            configureWindow(window)
        }
    }

    @objc
    private func windowDidChangeScreen(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        configureWindow(window)
    }

    private func configureWindow(_ window: NSWindow) {
        window.tabbingMode = .disallowed
        window.styleMask.insert(.fullSizeContentView)
        window.styleMask.insert(.unifiedTitleAndToolbar)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.titlebarSeparatorStyle = .none
        window.isOpaque = true
        window.backgroundColor = .windowBackgroundColor
        installWindowToolbarIfNeeded(on: window)
        window.toolbarStyle = .unifiedCompact
        hideNativeTrafficLights(on: window)
    }

    private func hideNativeTrafficLights(on window: NSWindow) {
        for type: NSWindow.ButtonType in [.closeButton, .miniaturizeButton, .zoomButton] {
            window.standardWindowButton(type)?.isHidden = true
        }
    }

    private func installWindowToolbarIfNeeded(on window: NSWindow) {
        if let toolbar = window.toolbar, toolbar.identifier == windowToolbarIdentifier {
            toolbar.displayMode = .iconOnly
            toolbar.allowsUserCustomization = false
            toolbar.autosavesConfiguration = false
            toolbar.isVisible = true
            return
        }

        let toolbar = NSToolbar(identifier: windowToolbarIdentifier)
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        window.toolbar = toolbar
    }
}
