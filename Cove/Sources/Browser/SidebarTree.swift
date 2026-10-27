import Foundation

/// Where an item goes in a sidebar tree: beside another item, inside a
/// folder, or at the end of the top level.
enum SidebarPosition: Equatable {
    case before(UUID)
    case after(UUID)
    /// The end of this folder's contents.
    case into(UUID)
    case end
}

/// A tree of tabs and folders, as the Pinned section holds them. Generic over
/// the tab so the saved form (pins) and the live form (tab sessions) share one
/// shape, and the moves can be tested on plain values.
struct SidebarTree<Tab: Identifiable> where Tab.ID == UUID {
    var items: [SidebarItem<Tab>] = []

    init(_ items: [SidebarItem<Tab>] = []) {
        self.items = items
    }

    var isEmpty: Bool { items.isEmpty }

    /// Every tab, folders flattened, in the order they're shown.
    var tabs: [Tab] {
        items.flatMap { item in
            switch item {
            case .tab(let tab): [tab]
            case .folder(let folder): folder.contents.tabs
            }
        }
    }

    /// The tabs on screen: those in collapsed folders are left out.
    var visibleTabs: [Tab] {
        items.flatMap { item in
            switch item {
            case .tab(let tab): [tab]
            case .folder(let folder): folder.isCollapsed ? [] : folder.contents.visibleTabs
            }
        }
    }

    /// Every folder, nested ones after their parents.
    var folders: [SidebarFolder<Tab>] {
        items.flatMap { item -> [SidebarFolder<Tab>] in
            guard case .folder(let folder) = item else { return [] }
            return [folder] + folder.contents.folders
        }
    }

    /// Every item's ID, folders before their contents, in the order shown.
    var ids: [UUID] {
        items.flatMap { item in
            switch item {
            case .tab(let tab): [tab.id]
            case .folder(let folder): [folder.id] + folder.contents.ids
            }
        }
    }

    func contains(_ id: UUID) -> Bool {
        ids.contains(id)
    }

    func tab(_ id: UUID) -> Tab? {
        tabs.first { $0.id == id }
    }

    func folder(_ id: UUID) -> SidebarFolder<Tab>? {
        folders.first { $0.id == id }
    }

    /// The same tree with each tab replaced, so a saved tree becomes a live one
    /// and back.
    func map<T>(_ transform: (Tab) -> T) -> SidebarTree<T> {
        SidebarTree<T>(items.map { item in
            switch item {
            case .tab(let tab): .tab(transform(tab))
            case .folder(let folder):
                .folder(SidebarFolder(
                    id: folder.id,
                    name: folder.name,
                    isCollapsed: folder.isCollapsed,
                    contents: folder.contents.map(transform)
                ))
            }
        })
    }

    // MARK: - Changes

    /// Takes the item with `id` out, wherever it is.
    @discardableResult
    mutating func remove(_ id: UUID) -> SidebarItem<Tab>? {
        if let index = items.firstIndex(where: { $0.id == id }) {
            return items.remove(at: index)
        }
        for index in items.indices {
            if case .folder(var folder) = items[index], let removed = folder.contents.remove(id) {
                items[index] = .folder(folder)
                return removed
            }
        }
        return nil
    }

    /// Puts an item at a position. False when the position names nothing in
    /// the tree, or would put a folder inside itself.
    @discardableResult
    mutating func insert(_ item: SidebarItem<Tab>, at position: SidebarPosition) -> Bool {
        if case .folder(let folder) = item, let anchor = position.anchor, anchor == folder.id || folder.contents.contains(anchor) {
            return false
        }

        switch position {
        case .end:
            items.append(item)
            return true
        case .into(let folderID):
            return update(folder: folderID) { $0.contents.items.append(item) }
        case .before(let anchor), .after(let anchor):
            if let index = items.firstIndex(where: { $0.id == anchor }) {
                items.insert(item, at: position.isAfter ? index + 1 : index)
                return true
            }
            for index in items.indices {
                if case .folder(var folder) = items[index], folder.contents.insert(item, at: position) {
                    items[index] = .folder(folder)
                    return true
                }
            }
            return false
        }
    }

    /// Moves an item to a position. An impossible move leaves the tree alone.
    mutating func move(_ id: UUID, to position: SidebarPosition) {
        guard position.anchor != id else { return }
        let before = self
        guard let item = remove(id), insert(item, at: position) else {
            self = before
            return
        }
    }

    /// Drag and drop: the dragged item takes the place of the one under it,
    /// which shifts toward where the dragged item came from.
    mutating func move(_ id: UUID, onto target: UUID) {
        let ids = ids
        guard let from = ids.firstIndex(of: id), let to = ids.firstIndex(of: target) else { return }
        move(id, to: from < to ? .after(target) : .before(target))
    }

    /// Changes a tab in place. False when there's no such tab.
    @discardableResult
    mutating func update(tab id: UUID, _ change: (inout Tab) -> Void) -> Bool {
        for index in items.indices {
            switch items[index] {
            case .tab(var tab) where tab.id == id:
                change(&tab)
                items[index] = .tab(tab)
                return true
            case .folder(var folder):
                guard folder.contents.update(tab: id, change) else { continue }
                items[index] = .folder(folder)
                return true
            default:
                continue
            }
        }
        return false
    }

    /// Changes a folder in place. False when there's no such folder.
    @discardableResult
    mutating func update(folder id: UUID, _ change: (inout SidebarFolder<Tab>) -> Void) -> Bool {
        for index in items.indices {
            guard case .folder(var folder) = items[index] else { continue }
            if folder.id == id {
                change(&folder)
                items[index] = .folder(folder)
                return true
            }
            if folder.contents.update(folder: id, change) {
                items[index] = .folder(folder)
                return true
            }
        }
        return false
    }
}

enum SidebarItem<Tab: Identifiable>: Identifiable where Tab.ID == UUID {
    case tab(Tab)
    case folder(SidebarFolder<Tab>)

    var id: UUID {
        switch self {
        case .tab(let tab): tab.id
        case .folder(let folder): folder.id
        }
    }
}

/// A folder in the Pinned section; it holds tabs and other folders.
struct SidebarFolder<Tab: Identifiable>: Identifiable where Tab.ID == UUID {
    let id: UUID
    var name: String
    var isCollapsed: Bool
    var contents: SidebarTree<Tab>

    init(id: UUID = UUID(), name: String, isCollapsed: Bool = false, contents: SidebarTree<Tab> = SidebarTree()) {
        self.id = id
        self.name = name
        self.isCollapsed = isCollapsed
        self.contents = contents
    }
}

private extension SidebarPosition {
    var anchor: UUID? {
        switch self {
        case .before(let id), .after(let id), .into(let id): id
        case .end: nil
        }
    }

    var isAfter: Bool {
        if case .after = self { true } else { false }
    }
}

extension SidebarTree: Codable where Tab: Codable {}
extension SidebarItem: Codable where Tab: Codable {}
extension SidebarFolder: Codable where Tab: Codable {}

extension SidebarTree: Equatable where Tab: Equatable {}
extension SidebarItem: Equatable where Tab: Equatable {}
extension SidebarFolder: Equatable where Tab: Equatable {}
