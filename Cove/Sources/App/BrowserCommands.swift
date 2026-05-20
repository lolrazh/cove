import SwiftUI

struct BrowserViewCommands: Commands {
    @FocusedObject private var tabManager: TabManager?

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Tab") {
                tabManager?.addTab()
            }
            .keyboardShortcut("t", modifiers: .command)
            .disabled(tabManager == nil)
        }

        CommandMenu("Browser") {
            Button("Open Location") {
                tabManager?.focusAddressBar()
            }
            .keyboardShortcut("l", modifiers: .command)
            .disabled(tabManager == nil)

            Button("Close Tab") {
                tabManager?.closeActiveTab()
            }
            .keyboardShortcut("w", modifiers: .command)
            .disabled(tabManager == nil)

            Divider()

            Button("Back") {
                tabManager?.goBack()
            }
            .keyboardShortcut("[", modifiers: .command)
            .disabled(tabManager == nil)

            Button("Forward") {
                tabManager?.goForward()
            }
            .keyboardShortcut("]", modifiers: .command)
            .disabled(tabManager == nil)

            Button("Reload Page") {
                tabManager?.reloadOrStop()
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(tabManager == nil)

            Divider()

            browserLayoutCommands
        }

        CommandGroup(after: .toolbar) {
            Divider()
            browserLayoutCommands
        }
    }

    private var browserLayoutCommands: some View {
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
            .disabled(tabManager == nil)
        }
    }
}
