import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// A tab dragged inside Cove, declared in Info.plist. It carries nothing:
    /// the list being dragged in knows which tab it is.
    static let coveTab = UTType(exportedAs: "com.cove.browser.tab")
}

extension View {
    /// Lets a tab or folder be dragged. The list holds the dragged item's ID.
    func draggableTab(_ id: UUID, dragging draggedTabID: Binding<UUID?>) -> some View {
        onDrag {
            draggedTabID.wrappedValue = id
            let item = NSItemProvider()
            item.registerDataRepresentation(forTypeIdentifier: UTType.coveTab.identifier, visibility: .ownProcess) { load in
                load(Data(), nil)
                return nil
            }
            return item
        }
    }

    /// Lets a tab be dragged to a new place, in its list or another: while
    /// dragging, the tab takes the place of each tab it passes over and the
    /// others make room, as in Arc, so dropping only ends the drag.
    func reorderableTab(_ id: UUID, in tabManager: TabManager, dragging draggedTabID: Binding<UUID?>) -> some View {
        draggableTab(id, dragging: draggedTabID)
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

    /// Lets a section take a tab dropped on its empty space, at its end.
    func acceptsTabDrops(toEndOf section: Pins.Section, in tabManager: TabManager, dragging draggedTabID: Binding<UUID?>) -> some View {
        onDrop(of: [.coveTab], delegate: SectionDropDelegate(section: section, tabManager: tabManager, draggedTabID: draggedTabID))
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

/// A drop in a section's empty space moves the tab there, unless it's there
/// already after passing over the section's tabs, when the drop just ends.
private struct SectionDropDelegate: DropDelegate {
    let section: Pins.Section
    let tabManager: TabManager
    @Binding var draggedTabID: UUID?

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        if let draggedTabID, tabManager.section(of: draggedTabID) != TabManager.TabSection(section) {
            tabManager.moveTab(draggedTabID, toEndOf: section)
        }
        draggedTabID = nil
        return true
    }
}

private extension TabManager.TabSection {
    init(_ section: Pins.Section) {
        self = switch section {
        case .favorites: .favorites
        case .pinned: .pinned
        }
    }
}
