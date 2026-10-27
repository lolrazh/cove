import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// A tab dragged inside Cove, declared in Info.plist. It carries nothing:
    /// the list being dragged in knows which tab it is.
    static let coveTab = UTType(exportedAs: "com.cove.browser.tab")
}

extension View {
    /// Lets a tab be dragged to a new place in its list. While dragging, the
    /// tab takes the place of each tab it passes over and the others make
    /// room, as in Arc, so dropping only ends the drag. The list holds the
    /// dragged tab's ID; sections that take tabs from other lists, like Pinned,
    /// accept the same drag with delegates of their own.
    func reorderableTab(_ tab: TabSession, in tabManager: TabManager, dragging draggedTabID: Binding<UUID?>) -> some View {
        onDrag {
            draggedTabID.wrappedValue = tab.id
            let item = NSItemProvider()
            item.registerDataRepresentation(forTypeIdentifier: UTType.coveTab.identifier, visibility: .ownProcess) { load in
                load(Data(), nil)
                return nil
            }
            return item
        }
        .onDrop(of: [.coveTab], delegate: TabDropDelegate(target: tab.id, tabManager: tabManager, draggedTabID: draggedTabID))
    }

    /// Takes a dragged tab dropped between tabs, so it settles where it is
    /// instead of flying back to where it started.
    func acceptsTabDrops(dragging draggedTabID: Binding<UUID?>) -> some View {
        onDrop(of: [.coveTab], isTargeted: nil) { _ in
            draggedTabID.wrappedValue = nil
            return true
        }
    }
}

private struct TabDropDelegate: DropDelegate {
    let target: UUID
    let tabManager: TabManager
    @Binding var draggedTabID: UUID?

    func dropEntered(info: DropInfo) {
        guard let draggedTabID, draggedTabID != target else { return }
        tabManager.moveTab(draggedTabID, onto: target)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedTabID = nil
        return true
    }
}
