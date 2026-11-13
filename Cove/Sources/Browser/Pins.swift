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

/// Pinned tabs and optional folders in one profile.
struct Pins: Codable, Equatable {
    var pinned = SidebarTree<Pin>()
    var all: [Pin] { pinned.tabs }
    func pin(_ id: UUID) -> Pin? { pinned.tab(id) }
    func contains(_ id: UUID) -> Bool { pinned.contains(id) }

    mutating func add(_ pin: Pin, at position: SidebarPosition = .end) {
        pinned.insert(.tab(pin), at: position)
    }
    @discardableResult mutating func remove(_ id: UUID) -> Pin? {
        guard pinned.tab(id) != nil, case .tab(let pin) = pinned.remove(id) else { return nil }
        return pin
    }
    mutating func update(_ id: UUID, _ change: (inout Pin) -> Void) { pinned.update(tab: id, change) }
    mutating func move(_ id: UUID, at position: SidebarPosition) {
        let before = pinned
        guard let item = pinned.remove(id), pinned.insert(item, at: position) else { pinned = before; return }
    }
    mutating func move(_ id: UUID, onto target: UUID) { pinned.move(id, onto: target) }
    mutating func addDocument(_ id: UUID, at position: SidebarPosition = .end) { pinned.insert(.document(id), at: position) }
    mutating func removeDocument(_ id: UUID) { if pinned.documents.contains(id) { pinned.remove(id) } }
    mutating func addFolder(_ folder: SidebarFolder<Pin>, at position: SidebarPosition = .end) { pinned.insert(.folder(folder), at: position) }
    mutating func updateFolder(_ id: UUID, _ change: (inout SidebarFolder<Pin>) -> Void) { pinned.update(folder: id, change) }
    mutating func removeFolder(_ id: UUID) -> [Pin] {
        guard case .folder(let folder) = pinned.remove(id) else { return [] }
        return folder.contents.tabs
    }
}

/// Each profile owns its pins. Nothing is moved to another profile on deletion.
struct PinLayout: Codable, Equatable {
    private(set) var pinned: [UUID: SidebarTree<Pin>] = [:]
    subscript(profile: UUID) -> Pins {
        get { Pins(pinned: pinned[profile] ?? SidebarTree()) }
        set { pinned[profile] = newValue.pinned.isEmpty ? nil : newValue.pinned }
    }
    var all: [Pin] { pinned.values.flatMap(\.tabs) }
    func pin(_ id: UUID) -> Pin? { all.first { $0.id == id } }
    mutating func update(_ id: UUID, _ change: (inout Pin) -> Void) {
        for profile in pinned.keys { pinned[profile]?.update(tab: id, change) }
    }
    mutating func prune(to profiles: Profiles) { pinned = pinned.filter { profiles.profile($0.key) != nil } }
}
