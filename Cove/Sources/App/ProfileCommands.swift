import SwiftUI

/// The Profiles menu: the next and previous profile (⌘⌥→, ⌘⌥←), every profile by
/// name with ⌃1–9, New Profile and Edit Profile. Empty in a private window.
struct ProfileCommands: Commands {
    @FocusedObject private var tabManager: TabManager?

    var body: some Commands {
        CommandMenu("Profiles") {
            Button("Next Profile") {
                tabManager?.switchToAdjacentProfile(1)
            }
            .keyboardShortcut(.rightArrow, modifiers: [.command, .option])
            .disabled(tabManager?.adjacentProfile(1) == nil)

            Button("Previous Profile") {
                tabManager?.switchToAdjacentProfile(-1)
            }
            .keyboardShortcut(.leftArrow, modifiers: [.command, .option])
            .disabled(tabManager?.adjacentProfile(-1) == nil)

            if let tabManager, !tabManager.isPrivate {
                Divider()
                ProfileMenuItems(tabManager: tabManager, showsShortcuts: true)
            }
        }
    }
}
