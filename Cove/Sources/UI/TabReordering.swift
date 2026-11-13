import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// A tab dragged inside Cove, declared in Info.plist.
    static let coveTab = UTType(exportedAs: "com.cove.browser.tab")
}

private nonisolated struct TabDragItem: Transferable, Identifiable {
    let id: UUID

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .coveTab) { item in
            Data(item.id.uuidString.utf8)
        }
        .visibility(.ownProcess)
    }
}

extension View {
    /// Lets a tab or folder be dragged. The list holds the dragged item's ID.
    func draggableTab(_ id: UUID) -> some View {
        draggable(TabDragItem.self, item: TabDragItem(id: id))
    }

    /// Lets a tab be dragged to a new place, in its list or another: while
    /// dragging, the tab takes the place of each tab it passes over and the
    /// others make room, as in Arc, so dropping only ends the drag.
    func reorderableTab(_ id: UUID, in tabManager: TabManager, dragging draggedTabID: Binding<UUID?>) -> some View {
        draggableTab(id)
            .onDrop(of: [.coveTab], delegate: TabDropDelegate(target: id, tabManager: tabManager, draggedTabID: draggedTabID))
    }

    /// Lets a folder take what's dropped on it, showing that it will.
    func acceptsTabDrops(
        into folderID: UUID,
        in tabManager: TabManager,
        dragging draggedTabID: Binding<UUID?>,
        isTargeted: Binding<Bool>
    ) -> some View {
        onDrop(of: [.coveTab], delegate: FolderDropDelegate(
            folderID: folderID,
            tabManager: tabManager,
            draggedTabID: draggedTabID,
            isTargeted: isTargeted
        ))
    }

    /// Lets a pinned section take a tab dropped at its end.
    func acceptsPinnedTabDrops(in tabManager: TabManager, dragging draggedTabID: Binding<UUID?>) -> some View {
        onDrop(of: [.coveTab], delegate: PinnedDropDelegate(tabManager: tabManager, draggedTabID: draggedTabID))
    }

    /// Takes a dragged tab dropped between tabs, so it settles where it is
    /// instead of flying back to where it started.
    func acceptsTabDrops(dragging draggedTabID: Binding<UUID?>) -> some View {
        onDrop(of: [.coveTab], isTargeted: nil) { _ in
            draggedTabID.wrappedValue = nil
            return true
        }
        .onDragSessionUpdated { session in
            // The list remains in place while its rows move. It also receives
            // session completion for cancellation or a drop outside the list.
            switch session.phase {
            case .initial, .active:
                draggedTabID.wrappedValue = session.draggedItemIDs(for: UUID.self).first
            case .ended:
                draggedTabID.wrappedValue = nil
            default:
                break
            }
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

private struct FolderDropDelegate: DropDelegate {
    let folderID: UUID
    let tabManager: TabManager
    @Binding var draggedTabID: UUID?
    @Binding var isTargeted: Bool

    func dropEntered(info: DropInfo) {
        isTargeted = draggedTabID != nil && draggedTabID != folderID
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        isTargeted = false
        if let draggedTabID {
            tabManager.moveTab(draggedTabID, into: folderID)
        }
        draggedTabID = nil
        return true
    }
}

/// A drop in the pinned section's empty space moves the tab there, unless it's there
/// already after passing over the section's tabs, when the drop just ends.
private struct PinnedDropDelegate: DropDelegate {
    let tabManager: TabManager
    @Binding var draggedTabID: UUID?

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        if let draggedTabID, tabManager.section(of: draggedTabID) != .pinned {
            tabManager.moveTabToPins(draggedTabID)
        }
        draggedTabID = nil
        return true
    }
}
