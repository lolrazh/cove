import SwiftUI

struct BrowserViewCommands: Commands {
    @FocusedObject private var tabManager: TabManager?

    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Divider()

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
