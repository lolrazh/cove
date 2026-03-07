import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Cove has its own in-app tab model, so AppKit's window tabbing
        // only creates confusing parallel behavior in the Window menu.
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Pre-compile content blocking rules
        if BrowserSettingsStore.shared.contentBlockingEnabled {
            Task { await ContentBlockerManager.shared.load() }
        }
    }
}
