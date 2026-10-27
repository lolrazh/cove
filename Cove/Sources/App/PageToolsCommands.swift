import SwiftUI

/// Menu items for the page itself. Each goes through the window's
/// `TabManager`, as the Command Bar's commands do.
struct PageToolsCommands: Commands {
    @FocusedObject private var tabManager: TabManager?

    var body: some Commands {
        CommandGroup(after: .textEditing) {
            Menu("Find") {
                Button("Find on Page…") {
                    tabManager?.findInPage()
                }
                .keyboardShortcut("f", modifiers: .command)

                Button("Find Next") {
                    tabManager?.findNext()
                }
                .keyboardShortcut("g", modifiers: .command)

                Button("Find Previous") {
                    tabManager?.findPrevious()
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
            }
            .disabled(tabManager == nil)
        }

        CommandGroup(before: .toolbar) {
            Group {
                Button("Actual Size") {
                    tabManager?.resetZoom()
                }
                .keyboardShortcut("0", modifiers: .command)

                Button("Zoom In") {
                    tabManager?.zoomIn()
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("Zoom Out") {
                    tabManager?.zoomOut()
                }
                .keyboardShortcut("-", modifiers: .command)
            }
            .disabled(tabManager == nil)

            Divider()
        }
    }
}
