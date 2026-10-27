import Foundation

/// Arc's Split View: two to four tabs side by side along one axis, each pane
/// with its share of the length. Generic over the pane, so the live split
/// (tab IDs) and the saved one (places in the saved Today) share one shape,
/// and the layout rules are tested on plain values.
struct TabSplit<Pane: Hashable & Codable>: Identifiable, Hashable, Codable {
    static var maxPanes: Int { 4 }
    /// The smallest share a divider can leave a pane.
    static var minFraction: Double { 0.15 }

    var id = UUID()
    private(set) var panes: [Pane]
    /// Each pane's share of the split's length, in order, summing to 1.
    private(set) var fractions: [Double]
    var axis: SplitAxis

    /// Equal shares, unless saved ones that fit are given.
    init(id: UUID = UUID(), panes: [Pane], fractions: [Double]? = nil, axis: SplitAxis = .horizontal) {
        self.id = id
        self.panes = panes
        self.fractions = fractions.flatMap { $0.count == panes.count ? $0 : nil } ?? Self.equalShares(panes.count)
        self.axis = axis
    }

    var isFull: Bool {
        panes.count >= Self.maxPanes
    }

    func contains(_ pane: Pane) -> Bool {
        panes.contains(pane)
    }

    /// Adds a pane at a place, clamped to the ends. Every pane gets an equal
    /// share again, as when Arc adds a pane. A full split, or one already
    /// holding the pane, stays as it is.
    mutating func insert(_ pane: Pane, at index: Int) {
        guard !isFull, !contains(pane) else { return }
        panes.insert(pane, at: min(max(index, 0), panes.count))
        fractions = Self.equalShares(panes.count)
    }

    /// The split without a pane; the others grow in proportion to fill its
    /// place. Nil once one pane is left: a split of one is no split.
    func removing(_ pane: Pane) -> TabSplit? {
        keeping { $0 != pane }
    }

    /// The split with only the panes that pass, grown to fill the space, or
    /// nil if fewer than two are left.
    func keeping(_ isKept: (Pane) -> Bool) -> TabSplit? {
        let kept = panes.indices.filter { isKept(panes[$0]) }
        guard kept.count >= 2 else { return nil }
        guard kept.count < panes.count else { return self }
        var split = self
        split.panes = kept.map { panes[$0] }
        let total = kept.map { fractions[$0] }.reduce(0, +)
        split.fractions = kept.map { fractions[$0] / total }
        return split
    }

    /// The pane that takes over when this one goes: the next, else the one
    /// before.
    func neighbor(of pane: Pane) -> Pane? {
        guard let index = panes.firstIndex(of: pane), panes.count > 1 else { return nil }
        return panes.indices.contains(index + 1) ? panes[index + 1] : panes[index - 1]
    }

    /// Where each divider sits, from 0 to 1 along the axis: after the first
    /// pane, after the second, and so on.
    var dividers: [Double] {
        fractions.dropLast().reduce(into: []) { positions, fraction in
            positions.append((positions.last ?? 0) + fraction)
        }
    }

    /// Drags the divider after pane `index` to `position` along the axis,
    /// moving length between the two panes beside it. Neither goes below the
    /// smallest share; the other panes stay as they are.
    mutating func moveDivider(_ index: Int, to position: Double) {
        guard fractions.indices.contains(index + 1) else { return }
        let start = index == 0 ? 0 : dividers[index - 1]
        let pair = fractions[index] + fractions[index + 1]
        let first = min(max(position - start, Self.minFraction), pair - Self.minFraction)
        fractions[index] = first
        fractions[index + 1] = pair - first
    }

    /// The same split over other panes, as for saving: nil if a pane has no
    /// counterpart or fewer than two are left.
    func map<Other>(_ transform: (Pane) -> Other?) -> TabSplit<Other>? {
        let mapped = panes.compactMap(transform)
        guard mapped.count == panes.count, mapped.count >= 2 else { return nil }
        return TabSplit<Other>(id: id, panes: mapped, fractions: fractions, axis: axis)
    }

    private static func equalShares(_ count: Int) -> [Double] {
        Array(repeating: 1 / Double(max(count, 1)), count: count)
    }
}

enum SplitAxis: String, Codable {
    /// Panes side by side, left to right.
    case horizontal
    /// Panes stacked, top to bottom.
    case vertical
}

/// One entry in Today as the sidebar and the strip show it: a tab on its own,
/// or the tabs of a split together, in the split's order.
enum TabEntry<Tab: Identifiable>: Identifiable where Tab.ID == UUID {
    case tab(Tab)
    case split(TabSplit<UUID>, [Tab])

    var id: UUID {
        switch self {
        case .tab(let tab): tab.id
        case .split(let split, _): split.id
        }
    }
}

extension Array where Element: Identifiable, Element.ID == UUID {
    /// The tabs as entries: a split shows once, where the first of its tabs
    /// is, and a tab in no split shows on its own.
    func entries(splits: [TabSplit<UUID>]) -> [TabEntry<Element>] {
        var shown: Set<UUID> = []
        return compactMap { tab in
            guard let split = splits.first(where: { $0.contains(tab.id) }) else { return .tab(tab) }
            guard shown.insert(split.id).inserted else { return nil }
            let tabs = split.panes.compactMap { id in first { $0.id == id } }
            return .split(split, tabs)
        }
    }
}
