import SwiftUI

/// Menu items for the page itself. Each goes through the window's
/// `TabManager`, as the Command Bar's commands do.
struct PageToolsCommands: Commands {
    @FocusedObject private var tabManager: TabManager?

    var body: some Commands {
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
