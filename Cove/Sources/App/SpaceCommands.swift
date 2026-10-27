import SwiftUI

/// The Spaces menu: the next and previous space (⌘⌥→, ⌘⌥←), every space by
/// name with ⌃1–9, New Space and Edit Space. Empty in a private window.
struct SpaceCommands: Commands {
    @FocusedObject private var tabManager: TabManager?

    var body: some Commands {
        CommandMenu("Spaces") {
            Button("Next Space") {
                tabManager?.switchToAdjacentSpace(1)
            }
            .keyboardShortcut(.rightArrow, modifiers: [.command, .option])
            .disabled(tabManager?.adjacentSpace(1) == nil)

            Button("Previous Space") {
                tabManager?.switchToAdjacentSpace(-1)
            }
            .keyboardShortcut(.leftArrow, modifiers: [.command, .option])
            .disabled(tabManager?.adjacentSpace(-1) == nil)

            if let tabManager, !tabManager.isPrivate {
                Divider()
                SpaceMenuItems(tabManager: tabManager, showsShortcuts: true)
            }
        }
    }
}
