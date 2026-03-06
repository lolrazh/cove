import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
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
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.titlebarSeparatorStyle = .none
        window.isOpaque = true
        window.backgroundColor = .windowBackgroundColor
    }
}
