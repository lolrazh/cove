import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    weak var externalURLRouter: ExternalURLRouter?

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Cove has its own in-app tab model, so AppKit's window tabbing
        // only creates confusing parallel behavior in the Window menu.
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        externalURLRouter?.enqueue(urls)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
