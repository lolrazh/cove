import Foundation

/// A page kept in the sidebar for good: Arc's pinned tab, a bookmark with a
/// live tab behind it.
struct Pin: Identifiable, Codable, Hashable {
    let id: UUID
    /// The address pinned: what the tab returns to when it's closed.
    var url: String
    /// The pinned page's title, as last seen there.
    var title: String
}

extension SidebarItem where Tab == Pin {
    /// A bookmark from another browser, as a pin or a folder of them.
    init(_ bookmark: ImportedBookmark) {
        switch bookmark {
        case .page(let title, let url):
            self = .tab(Pin(id: UUID(), url: url.absoluteString, title: title))
        case .folder(let title, let children):
            self = .folder(SidebarFolder(name: title, contents: SidebarTree(children.map(Self.init))))
        }
    }
}

/// The sidebar's durable sections: Favorites, a row of pins, and Pinned, a
/// tree of pins and folders. Pure, so the moves can be tested. With Spaces,
/// each space will own a Pinned tree while Favorites stay shared.
struct Pins: Codable, Equatable {
    enum Section {
        case favorites
        case pinned
    }

    var favorites: [Pin] = []
    var pinned = SidebarTree<Pin>()

    var all: [Pin] { favorites + pinned.tabs }

    func pin(_ id: UUID) -> Pin? {
        all.first { $0.id == id }
    }

    /// Which section holds the pin or folder.
    func section(of id: UUID) -> Section? {
        if favorites.contains(where: { $0.id == id }) { return .favorites }
        if pinned.contains(id) { return .pinned }
        return nil
    }

    mutating func add(_ pin: Pin, to section: Section, at position: SidebarPosition = .end) {
        insert(.tab(pin), into: section, at: position)
    }

    @discardableResult
    mutating func remove(_ id: UUID) -> Pin? {
        if let index = favorites.firstIndex(where: { $0.id == id }) {
            return favorites.remove(at: index)
        }
        guard pinned.tab(id) != nil, case .tab(let pin) = pinned.remove(id) else { return nil }
        return pin
    }

    mutating func update(_ id: UUID, _ change: (inout Pin) -> Void) {
        if let index = favorites.firstIndex(where: { $0.id == id }) {
            change(&favorites[index])
        } else {
            pinned.update(tab: id, change)
        }
    }

    /// Moves a pin or folder, within a section or between them. Folders stay
    /// in Pinned; an impossible move changes nothing.
    mutating func move(_ id: UUID, to section: Section, at position: SidebarPosition) {
        let before = self
        let item: SidebarItem<Pin>?
        if let index = favorites.firstIndex(where: { $0.id == id }) {
            item = .tab(favorites.remove(at: index))
        } else {
            item = pinned.remove(id)
        }
        guard let item, insert(item, into: section, at: position) else {
            self = before
            return
        }
    }

    /// Drag and drop: the dragged item takes the place of the one under it.
    /// Favorites come before Pinned, so a drop from the other section lands
    /// on the side the drag came from.
    mutating func move(_ id: UUID, onto target: UUID) {
        guard id != target, let from = section(of: id), let to = section(of: target) else { return }
        switch (from, to) {
        case (.favorites, .favorites): favorites.move(id, onto: target)
        case (.pinned, .pinned): pinned.move(id, onto: target)
        case (.favorites, .pinned): move(id, to: .pinned, at: .after(target))
        case (.pinned, .favorites): move(id, to: .favorites, at: .before(target))
        }
    }

    // MARK: - Folders

    mutating func addFolder(_ folder: SidebarFolder<Pin>, at position: SidebarPosition = .end) {
        pinned.insert(.folder(folder), at: position)
    }

    mutating func updateFolder(_ id: UUID, _ change: (inout SidebarFolder<Pin>) -> Void) {
        pinned.update(folder: id, change)
    }

    /// Removes a folder and returns the pins it held, nested folders included.
    mutating func removeFolder(_ id: UUID) -> [Pin] {
        guard case .folder(let folder) = pinned.remove(id) else { return [] }
        return folder.contents.tabs
    }

    // MARK: - Placing

    /// Places an item in a section. In Favorites, which has no folders, "into"
    /// a folder means the end of the row.
    private mutating func insert(_ item: SidebarItem<Pin>, into section: Section, at position: SidebarPosition) -> Bool {
        switch section {
        case .pinned:
            return pinned.insert(item, at: position)
        case .favorites:
            guard case .tab(let pin) = item else { return false }
            switch position {
            case .before(let anchor), .after(let anchor):
                guard let index = favorites.firstIndex(where: { $0.id == anchor }) else { return false }
                favorites.insert(pin, at: index + (position == .after(anchor) ? 1 : 0))
            case .into, .end:
                favorites.append(pin)
            }
            return true
        }
    }
}
