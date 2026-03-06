import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
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

    private func configureWindow(_ window: NSWindow) {
        window.tabbingMode = .disallowed
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.titlebarSeparatorStyle = .none
        window.isOpaque = true
        window.backgroundColor = .windowBackgroundColor
    }
}
