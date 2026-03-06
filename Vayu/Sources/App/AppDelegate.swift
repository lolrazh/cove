import AppKit
import os.log

private let log = Logger(subsystem: "com.vayu.browser", category: "AppDelegate")

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        log.info("applicationDidFinishLaunching")

        // Ensure no transparent titlebar material (anti-Liquid Glass)
        for window in NSApplication.shared.windows {
            configureWindow(window)
        }

        // Pre-compile content blocking rules
        Task {
            log.info("Starting content blocker load")
            await ContentBlockerManager.shared.load()
            log.info("Content blocker load finished")
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
        window.isOpaque = true
        window.backgroundColor = .windowBackgroundColor
    }
}
