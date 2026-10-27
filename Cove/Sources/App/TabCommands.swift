import SwiftUI

/// The Tab menu: switching between tabs and acting on the active one. The same
/// actions are in each tab's context menu, for any tab.
struct TabCommands: Commands {
    @FocusedObject private var tabManager: TabManager?

    var body: some Commands {
        CommandMenu("Tab") {
            switching
                .disabled(tabManager == nil)

            if let tabManager, let document = tabManager.activeDocument {
                Divider()
                DocumentActions(document: document, tabManager: tabManager)
            } else if let tabManager, let tab = tabManager.activeTab {
                Divider()
                TabActions(tab: tab, tabManager: tabManager, placement: .menuBar)
            }
        }
    }

    private var switching: some View {
        Group {
            Button("Show Next Tab") {
                tabManager?.selectAdjacentTab(1)
            }
            .keyboardShortcut(.tab, modifiers: .control)

            Button("Show Previous Tab") {
                tabManager?.selectAdjacentTab(-1)
            }
            .keyboardShortcut(.tab, modifiers: [.control, .shift])

            Menu("Go to Tab") {
                ForEach(1..<9) { number in
                    Button("Tab \(number)") {
                        tabManager?.selectTab(forShortcut: number)
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(number)")), modifiers: .command)
                }

                Button("Last Tab") {
                    tabManager?.selectTab(forShortcut: 9)
                }
                .keyboardShortcut("9", modifiers: .command)
            }
        }
    }
}
