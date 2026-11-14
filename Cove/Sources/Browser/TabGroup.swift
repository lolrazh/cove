import Foundation

/// Group metadata over Today. Tabs keep one flat order and one live owner.
struct TabGroup<Member: Hashable & Codable>: Identifiable, Hashable, Codable {
    var id = UUID()
    var members: [Member]
    var customName: String? = nil
    var symbolName: String? = nil
    var isCollapsed = false
    var isAutomatic = false
    /// A pin can own a group of Today children without leaving Pinned.
    var pinnedOpenerID: UUID? = nil

    func contains(_ member: Member) -> Bool { members.contains(member) }

    func keeping(_ keep: (Member) -> Bool) -> Self? {
        var copy = self
        var seen: Set<Member> = []
        copy.members = members.filter { keep($0) && seen.insert($0).inserted }
        let minimum = isAutomatic && pinnedOpenerID == nil ? 2 : 1
        return copy.members.count >= minimum ? copy : nil
    }

    func map<Other: Hashable & Codable>(_ transform: (Member) -> Other?) -> TabGroup<Other>? {
        let mapped = members.compactMap(transform)
        return TabGroup<Other>(id: id, members: mapped, customName: customName,
                               symbolName: symbolName, isCollapsed: isCollapsed,
                               isAutomatic: isAutomatic, pinnedOpenerID: pinnedOpenerID).keeping { _ in true }
    }
}

enum TabGroupOpenIntent {
    case none
    case backgroundLink
    case foregroundLink
}

/// Kept before close can dissolve a two-tab automatic group. Stable saved tab
/// IDs reconnect surviving members after a relaunch without URL guessing.
struct ArchivedTabGroup: Codable, Hashable {
    let group: TabGroup<UUID>
    let closedTabID: UUID
}
