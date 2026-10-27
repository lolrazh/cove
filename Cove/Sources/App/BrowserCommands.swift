import SwiftUI

struct BrowserViewCommands: Commands {
    @FocusedObject private var tabManager: TabManager?
    @Environment(\.openWindow) private var openWindow
    let appServices: AppServices

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Tab") {
                tabManager?.newTab()
            }
            .keyboardShortcut("t", modifiers: .command)
            .disabled(tabManager == nil)

            Button("New Window") {
                openWindow(id: BrowserView.windowID)
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("New Private Window") {
                openWindow(id: BrowserView.privateWindowID)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
        }

        // Replaces File > Close, which also claimed Command-W and, coming
        // first in the menu bar, closed the whole window instead of the tab.
        CommandGroup(replacing: .saveItem) {
            Button("Close Tab") {
                tabManager?.closeActiveTab()
            }
            .keyboardShortcut("w", modifiers: .command)
            .disabled(tabManager == nil)

            Button("Close Window") {
                NSApp.keyWindow?.performClose(nil)
            }
            .keyboardShortcut("w", modifiers: [.command, .shift])
        }

        CommandMenu("History") {
            HistoryMenu(
                tabManager: tabManager,
                historyStore: appServices.historyStore,
                recentlyClosed: tabManager?.recentlyClosed ?? appServices.recentlyClosedTabs,
                faviconStore: appServices.faviconStore,
                onShowAllHistory: { openWindow(id: HistoryWindow.windowID) }
            )
        }

        CommandMenu("Browser") {
            Button("Open Location") {
                tabManager?.editCurrentURL()
            }
            .keyboardShortcut("l", modifiers: .command)
            .disabled(tabManager == nil)

            Button("Reload Page") {
                tabManager?.reloadOrStop()
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(tabManager == nil)

            Button("Copy URL") {
                tabManager?.copyURL()
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .disabled(tabManager == nil)

            Divider()

            browserLayoutCommands(hideTabsShortcut: nil)
        }

        CommandGroup(after: .toolbar) {
            Divider()
            browserLayoutCommands(hideTabsShortcut: KeyboardShortcut("s", modifiers: .command))
        }
    }

    /// In the Browser and View menus. ⌘S, Arc's sidebar toggle, goes on one
    /// of them only, so it isn't claimed twice.
    private func browserLayoutCommands(hideTabsShortcut: KeyboardShortcut?) -> some View {
        Group {
            Toggle(
                "Show Tabs in Sidebar",
                isOn: Binding(
                    get: { tabManager?.tabLayout == .sidebar },
                    set: { show in
                        withAnimation(ChromeMotion.shell) {
                            tabManager?.setLayout(show ? .sidebar : .horizontal)
                        }
                    }
                )
            )
            .disabled(tabManager == nil)

            Toggle(
                "Hide Tabs",
                isOn: Binding(
                    get: { tabManager?.hideTabs ?? false },
                    set: { hide in
                        withAnimation(ChromeMotion.shell) {
                            tabManager?.setHideTabs(hide)
                        }
                    }
                )
            )
            .keyboardShortcut(hideTabsShortcut)
            .disabled(tabManager == nil)
        }
    }
}
