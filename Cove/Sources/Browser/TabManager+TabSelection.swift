import AppKit

/// Selection is independent of the page on screen. Modifier clicks must not
/// wake a page or change the address bar while the user collects tabs.
struct TabSelection {
    var ids: Set<UUID> = []
    var anchorID: UUID?

    mutating func click(_ id: UUID, in order: [UUID], activeID: UUID?, modifiers: NSEvent.ModifierFlags) -> Bool {
        guard order.contains(id) else {
            ids.removeAll()
            anchorID = nil
            return false
        }
        if modifiers.contains(.shift) {
            let anchor = anchorID.flatMap { order.contains($0) ? $0 : nil }
                ?? activeID.flatMap { order.contains($0) ? $0 : nil } ?? id
            if let start = order.firstIndex(of: anchor), let end = order.firstIndex(of: id) {
                let range = Set(order[min(start, end)...max(start, end)])
                ids = modifiers.contains(.command) ? ids.union(range) : range
                anchorID = anchor
            }
            return true
        }
        if modifiers.contains(.command) {
            if ids.isEmpty, let activeID, order.contains(activeID) { ids.insert(activeID) }
            if !ids.insert(id).inserted { ids.remove(id) }
            anchorID = id
            return true
        }
        ids.removeAll()
        anchorID = id
        return false
    }
}

extension TabManager {
    /// Returns true for a selection-only click. The caller can leave page focus alone.
    @discardableResult
    func selectTabForInteraction(_ id: UUID, modifiers: NSEvent.ModifierFlags) -> Bool {
        let order = tabsInDisplayOrder.filter { tab in
            guard section(of: tab.id) == .today else { return false }
            guard tabLayout == .sidebar, let group = group(for: tab.id), group.isCollapsed else { return true }
            return tab.id == activeTabID
        }.map(\.id)
        var selection = TabSelection(ids: selectedTabIDs, anchorID: tabSelectionAnchorID)
        let selectionOnly = selection.click(id, in: order, activeID: activeTabID, modifiers: modifiers)
        selectedTabIDs = selection.ids
        tabSelectionAnchorID = selection.anchorID
        if !selectionOnly { selectTab(id) }
        return selectionOnly
    }

    func clearTabSelection() {
        selectedTabIDs.removeAll()
        tabSelectionAnchorID = nil
    }

    /// Right-clicking an unrelated row acts on that row, without changing the page.
    func selectionTabIDs(for id: UUID) -> [UUID] {
        guard selectedTabIDs.contains(id) else { return tab(id) == nil ? [] : [id] }
        return tabsInDisplayOrder.map(\.id).filter(selectedTabIDs.contains)
    }

    func closeSelectedTabs(from id: UUID) {
        let ids = selectionTabIDs(for: id)
        if ids.count == 1, let id = ids.first {
            closeTab(id)
        } else {
            closeTabs(ids)
        }
        clearTabSelection()
    }

    /// Move the selected rows in one order change. A split remains one unit.
    func moveTabSelection(_ id: UUID, onto target: UUID) {
        let selected = selectionTabIDs(for: id)
        guard selected.count > 1, section(of: target) == .today,
              selected.allSatisfy({ section(of: $0) == .today }) else {
            moveTab(id, onto: target)
            return
        }
        let moving = Set(selected.flatMap(splitGroup))
        let targets = splitGroup(of: target)
        guard moving.isDisjoint(with: targets) else { return }
        today.move(tabs.map(\.id).filter(moving.contains), onto: targets)
    }
}
