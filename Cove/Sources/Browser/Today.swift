import Foundation

/// Something in Today: a tab, or a note or easel kept there like one. Generic
/// over the tab, like the sidebar's tree, so the rules are tested on plain
/// values.
enum TodayItem<Tab: Identifiable>: Identifiable where Tab.ID == UUID {
    case tab(Tab)
    case document(UUID)

    var id: UUID {
        switch self {
        case .tab(let tab): tab.id
        case .document(let id): id
        }
    }

    var tab: Tab? {
        if case .tab(let tab) = self { tab } else { nil }
    }

    var documentID: UUID? {
        if case .document(let id) = self { id } else { nil }
    }

    /// Today as it was saved: its tabs, with its documents back in their places.
    static func restoring(tabs: [Tab], documents: [TodayDocumentPlace]) -> [TodayItem] {
        var today = tabs.map(TodayItem.tab)
        for place in documents.sorted(by: { $0.index < $1.index }) {
            today.insert(.document(place.id), at: min(max(place.index, 0), today.count))
        }
        return today
    }
}

/// A note or easel in a saved Today, and its place there among the tabs.
struct TodayDocumentPlace: Codable, Equatable {
    let id: UUID
    let index: Int
}

/// One entry in Today as the sidebar and the strip show it: a tab on its own,
/// a document, or the tabs of a split together, in the split's order.
enum TabEntry<Tab: Identifiable>: Identifiable where Tab.ID == UUID {
    case tab(Tab)
    case document(UUID)
    case split(TabSplit<UUID>, [Tab])

    var id: UUID {
        switch self {
        case .tab(let tab): tab.id
        case .document(let id): id
        case .split(let split, _): split.id
        }
    }
}

extension Array {
    /// Today's documents and their places, to save beside its tabs.
    func documentPlaces<Tab>() -> [TodayDocumentPlace] where Element == TodayItem<Tab> {
        indices.compactMap { index in self[index].documentID.map { TodayDocumentPlace(id: $0, index: index) } }
    }

    /// Today as entries: a split shows once, where the first of its tabs is,
    /// and a tab in no split or a document shows on its own.
    func entries<Tab>(splits: [TabSplit<UUID>]) -> [TabEntry<Tab>] where Element == TodayItem<Tab> {
        var shown: Set<UUID> = []
        return compactMap { item in
            guard let tab = item.tab else { return item.documentID.map(TabEntry.document) }
            guard let split = splits.first(where: { $0.contains(tab.id) }) else { return .tab(tab) }
            guard shown.insert(split.id).inserted else { return nil }
            let tabs = split.panes.compactMap { id in lazy.compactMap(\.tab).first { $0.id == id } }
            return .split(split, tabs)
        }
    }
}
