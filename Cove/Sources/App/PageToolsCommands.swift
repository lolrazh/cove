import SwiftUI

/// Menu items for the page itself. Each goes through the window's
/// `TabManager`, as the Command Bar's commands do.
struct PageToolsCommands: Commands {
    @FocusedObject private var tabManager: TabManager?

    var body: some Commands {
        CommandGroup(after: .saveItem) {
            Group {
                Button("Save Page As…") {
                    tabManager?.savePage()
                }
                .keyboardShortcut("s", modifiers: [.command, .option])

                Divider()

                Button("Print…") {
                    tabManager?.printPage()
                }
                .keyboardShortcut("p", modifiers: .command)
            }
            .disabled(tabManager == nil)
        }

        CommandGroup(after: .textEditing) {
            Menu("Find") {
                Button("Find on Page…") {
                    find(.showFindInterface) { $0.findInPage() }
                }
                .keyboardShortcut("f", modifiers: .command)

                Button("Find Next") {
                    find(.nextMatch) { $0.findNext() }
                }
                .keyboardShortcut("g", modifiers: .command)

                Button("Find Previous") {
                    find(.previousMatch) { $0.findPrevious() }
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
            }
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

                Divider()

                Button("Picture in Picture") {
                    tabManager?.togglePictureInPicture()
                }

                Button("View Source") {
                    tabManager?.viewSource()
                }
                .keyboardShortcut("u", modifiers: [.command, .option])
            }
            .disabled(tabManager == nil)

            Divider()
        }
    }

    /// Finds in the page in a browser window. Elsewhere, like the source
    /// window, the key view's own find bar takes the action.
    private func find(_ action: NSTextFinder.Action, inPage: (TabManager) -> Void) {
        if let tabManager {
            inPage(tabManager)
        } else {
            let sender = NSMenuItem()
            sender.tag = action.rawValue
            NSApp.sendAction(#selector(NSResponder.performTextFinderAction(_:)), to: nil, from: sender)
        }
    }
}
