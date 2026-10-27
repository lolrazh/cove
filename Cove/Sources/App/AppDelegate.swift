import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Cove has its own in-app tab model, so AppKit's window tabbing
        // only creates confusing parallel behavior in the Window menu.
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    /// SwiftUI opens the first browser window, which reopens the rest of the
    /// session, only when AppKit asks for an untitled window, and AppKit asks
    /// only when Cove launches frontmost. Launched behind another app or
    /// while the screen is locked, Cove would show no window until ⌘N, so it
    /// asks itself. Links that launch Cove have opened a window by now.
    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async {
            guard !NSApp.windows.contains(where: \.isVisible) else { return }
            _ = NSApp.delegate?.applicationOpenUntitledFile?(NSApp)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
