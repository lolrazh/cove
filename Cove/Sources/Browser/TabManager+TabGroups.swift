import Foundation

extension TabManager {
    func group(for tabID: UUID) -> TabGroup<UUID>? {
        tabGroups.first { $0.contains(tabID) }
    }

    func groupTitle(_ group: TabGroup<UUID>) -> String {
        if let name = group.customName, !name.isEmpty { return name }
        if let opener = group.pinnedOpenerID.flatMap(tab) { return opener.title }
        return TabGroupName.title(for: group.members.compactMap(tab).map { (title: $0.title, url: $0.currentURL) })
    }

    @discardableResult
    func createGroup(tabIDs: [UUID]) -> UUID? {
        let members = expandedGroupSelection(tabIDs)
        guard !members.isEmpty else { return nil }
        ungroupTabs(members)
        let group = TabGroup(members: members)
        tabGroups.append(group)
        arrangeTabGroups()
        return group.id
    }

    func moveTabs(_ tabIDs: [UUID], toGroup id: UUID) {
        guard var target = tabGroups.first(where: { $0.id == id }) else { return }
        let moving = Set(expandedGroupSelection(tabIDs))
        guard !moving.isEmpty else { return }
        let kept = Set(target.members).union(moving)
        target.members = tabs.map(\.id).filter(kept.contains)
        tabGroups = tabGroups.filter { $0.id != id }.compactMap { $0.keeping { !moving.contains($0) } }
        tabGroups.append(target)
        arrangeTabGroups()
    }

    func ungroupTabs(_ tabIDs: [UUID]) {
        let removed = Set(expandedGroupSelection(tabIDs))
        tabGroups = tabGroups.compactMap { $0.keeping { !removed.contains($0) } }
        arrangeTabGroups()
    }

    /// Removes only the group; its live pages stay in their current order.
    func removeGroup(_ id: UUID) { tabGroups.removeAll { $0.id == id } }

    func renameGroup(_ id: UUID, to name: String) {
        guard let index = tabGroups.firstIndex(where: { $0.id == id }) else { return }
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        tabGroups[index].customName = name.isEmpty ? nil : name
        tabGroups[index].isAutomatic = false
    }

    func setGroupSymbol(_ id: UUID, to symbol: String?) {
        guard let index = tabGroups.firstIndex(where: { $0.id == id }) else { return }
        tabGroups[index].symbolName = symbol
        tabGroups[index].isAutomatic = false
    }

    func toggleGroupCollapsed(_ id: UUID) {
        guard let index = tabGroups.firstIndex(where: { $0.id == id }) else { return }
        tabGroups[index].isCollapsed.toggle()
    }

    func closeGroup(_ id: UUID) {
        guard let group = tabGroups.first(where: { $0.id == id }) else { return }
        closeTabs(group.members)
    }

    private func expandedGroupSelection(_ ids: [UUID]) -> [UUID] {
        let expanded = Set(ids.flatMap(splitGroup))
        return tabs.map(\.id).filter(expanded.contains)
    }

    static func prunedGroups(_ groups: [TabGroup<UUID>], tabIDs: [UUID]) -> [TabGroup<UUID>] {
        let available = Set(tabIDs)
        var assigned: Set<UUID> = []
        var groupIDs: Set<UUID> = []
        return groups.compactMap { group in
            guard groupIDs.insert(group.id).inserted,
                  var kept = group.keeping({ available.contains($0) && !assigned.contains($0) }) else { return nil }
            let members = Set(kept.members)
            kept.members = tabIDs.filter(members.contains)
            assigned.formUnion(kept.members)
            return kept
        }
    }

    /// A group's first row anchors its contiguous block. Documents and loose
    /// tabs keep their relative order; no tab or document is discarded.
    static func arrangedToday(_ today: [TodayItem<TabSession>], groups: [TabGroup<UUID>]) -> [TodayItem<TabSession>] {
        var owner: [UUID: UUID] = [:]
        for group in groups {
            for member in group.members where owner[member] == nil { owner[member] = group.id }
        }
        var contents: [UUID: [TodayItem<TabSession>]] = [:]
        for item in today where item.tab != nil {
            if let groupID = owner[item.id] { contents[groupID, default: []].append(item) }
        }
        var shown: Set<UUID> = []
        return today.flatMap { item in
            guard item.tab != nil, let groupID = owner[item.id] else { return [item] }
            return shown.insert(groupID).inserted ? contents[groupID] ?? [] : []
        }
    }

    func arrangeTabGroups() {
        let arranged = Self.arrangedToday(today, groups: tabGroups)
        if arranged.map(\.id) != today.map(\.id) { today = arranged }
        pruneTabGroups()
    }

    func pruneTabGroups() {
        let pruned = Self.prunedGroups(tabGroups, tabIDs: tabs.map(\.id))
        if pruned != tabGroups { tabGroups = pruned }
    }

    /// Splits remain whole even when a pane is added from another group.
    func containSplitsInGroups() {
        var groups = tabGroups
        for split in splits {
            let focusedGroup = activeTabID.flatMap { split.contains($0) ? group(for: $0)?.id : nil }
            guard let owner = focusedGroup ?? groups.first(where: { group in split.panes.contains(where: group.contains) })?.id,
                  var target = groups.first(where: { $0.id == owner }) else { continue }
            let panes = Set(split.panes)
            let members = Set(target.members).union(panes)
            target.members = tabs.map(\.id).filter(members.contains)
            groups = groups.filter { $0.id != owner }.compactMap { $0.keeping { !panes.contains($0) } }
            groups.append(target)
        }
        if groups != tabGroups { tabGroups = groups }
    }

    static func insertLinkedTab(_ tab: TabSession, openerID: UUID?, grouping: TabGroupOpenIntent,
                                today: inout [TodayItem<TabSession>], groups: inout [TabGroup<UUID>],
                                splits: [TabSplit<UUID>], openerIsPinned: Bool) {
        let owner = openerID.flatMap { opener in groups.first { $0.contains(opener) || $0.pinnedOpenerID == opener } }
        let siblings = owner?.members ?? openerID.map { opener in
            splits.first(where: { $0.contains(opener) })?.panes ?? [opener]
        } ?? []
        let index = today.lastIndex { siblings.contains($0.id) }.map { $0 + 1 } ?? today.endIndex
        today.insert(.tab(tab), at: index)
        guard grouping != .none, let openerID else { return }
        if let owner, let groupIndex = groups.firstIndex(where: { $0.id == owner.id }) {
            groups[groupIndex].members.append(tab.id)
        } else if grouping == .backgroundLink,
                  openerIsPinned || today.contains(where: { $0.id == openerID && $0.tab != nil }) {
            let members = openerIsPinned ? [tab.id] : siblings + [tab.id]
            groups.append(TabGroup(members: members, isAutomatic: true,
                                   pinnedOpenerID: openerIsPinned ? openerID : nil))
        }
    }

    func restoreGroup(_ saved: ArchivedTabGroup?, restoredTabID: UUID) {
        guard let saved else { return }
        var recovered = tabGroups.first(where: { $0.id == saved.group.id }) ?? saved.group
        recovered.members = recovered.members.map { $0 == saved.closedTabID ? restoredTabID : $0 }
        if !recovered.contains(restoredTabID) { recovered.members.append(restoredTabID) }
        let available = Set(tabs.map(\.id))
        guard let kept = recovered.keeping(available.contains) else { return }
        // Do not reclaim a surviving tab that the user has since regrouped.
        let occupied = Set(tabGroups.filter { $0.id != kept.id }.flatMap(\.members))
        guard let restored = kept.keeping({ !occupied.contains($0) }) else { return }
        tabGroups.removeAll { $0.id == restored.id }
        tabGroups.append(restored)
        arrangeTabGroups()
    }
}
