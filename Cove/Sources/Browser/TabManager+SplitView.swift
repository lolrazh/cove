import Foundation

/// Arc's Split View: up to four Today tabs side by side. The active tab is the
/// focused pane, so everything that acts on the active tab acts on it; the
/// split itself is the entry the sidebar and the strip show as selected.
extension TabManager {
    /// Where a tab joins the split.
    enum SplitPlacement {
        /// Beside the focused pane, after it.
        case afterFocused
        /// First or last, as when a tab is dropped on the page's edge.
        case leading
        case trailing
    }

    func split(containing id: UUID) -> TabSplit<UUID>? {
        splits.first { $0.contains(id) }
    }

    /// The split on screen: the one holding the active tab.
    var activeSplit: TabSplit<UUID>? {
        activeTabID.flatMap(split)
    }

    /// The tabs on screen: the split's panes, or the active tab alone.
    var shownTabs: [TabSession] {
        activeSplit.map { $0.panes.compactMap(tab) } ?? activeTab.map { [$0] } ?? []
    }

    func isShown(_ id: UUID) -> Bool {
        id == activeTabID || activeSplit?.contains(id) == true
    }

    /// A tab and the rest of its split, which move together: in Today's order.
    func splitGroup(of id: UUID) -> [UUID] {
        guard let split = split(containing: id) else { return [id] }
        return tabs.map(\.id).filter(split.contains)
    }

    /// Whether the active tab can take another pane: it's in Today and its
    /// split, if any, has room.
    var canAddSplitPane: Bool {
        guard let activeTabID, section(of: activeTabID) == .today else { return false }
        return !(activeSplit?.isFull ?? false)
    }

    /// Whether a tab can join the split on screen: another Today tab, not
    /// already in it.
    func canOpenInSplitView(_ id: UUID) -> Bool {
        canAddSplitPane && !isShown(id) && section(of: id) == .today
    }

    /// ⌃⇧= and Add Split View: a new pane beside the focused one, chosen in
    /// the Command Bar, or a start page, as Settings says new tabs open.
    func addSplitView() {
        guard canAddSplitPane else { return }
        if settings.newTabPreference == .commandBar {
            commandBar.present(.splitView)
        } else {
            openNewTabInSplitView { addTab() }
        }
    }

    /// The Command Bar's choice in Split View mode: a page in a new pane.
    func addTabInSplitView(url: String) {
        openNewTabInSplitView { addTab(url: url) }
    }

    /// Open in Split View, and a tab dropped on the page's edge: the tab joins
    /// the split on screen, or makes one with the active tab, and is focused.
    /// A tab leaves any split it was in.
    func openInSplitView(_ id: UUID, at placement: SplitPlacement = .afterFocused) {
        guard let focusedID = activeTabID, canOpenInSplitView(id) else { return }
        var split = activeSplit ?? TabSplit(panes: [focusedID])
        let index = switch placement {
        case .afterFocused: (split.panes.firstIndex(of: focusedID) ?? 0) + 1
        case .leading: 0
        case .trailing: split.panes.count
        }
        split.insert(id, at: index)

        splits = splits.compactMap { $0.id == split.id ? split : $0.removing(id) }
        if !splits.contains(where: { $0.id == split.id }) {
            splits.append(split)
        }
        today.gather(split.panes)
        selectTab(id)
    }

    /// Separate Split View: the tabs stay in Today, each on its own; the
    /// focused one stays selected.
    func separateSplit(_ id: UUID) {
        splits.removeAll { $0.id == id }
    }

    func moveSplitDivider(_ id: UUID, divider: Int, to position: Double) {
        guard let index = splits.firstIndex(where: { $0.id == id }) else { return }
        splits[index].moveDivider(divider, to: position)
    }

    /// Rotate Split View: side by side, or stacked.
    func rotateSplit(_ id: UUID) {
        guard let index = splits.firstIndex(where: { $0.id == id }) else { return }
        splits[index].axis = splits[index].axis == .horizontal ? .vertical : .horizontal
    }

    /// Drops the splits of tabs that left Today; a split left with one tab
    /// is gone.
    func pruneSplits() {
        let ids = Set(tabs.map(\.id))
        let pruned = splits.compactMap { $0.keeping(ids.contains) }
        if pruned != splits {
            splits = pruned
        }
    }

    /// Opens a tab with `open`, which selects it, then puts it in a pane
    /// beside the tab that was active.
    private func openNewTabInSplitView(_ open: () -> Void) {
        guard let anchorID = activeTabID else { return }
        open()
        guard let openedID = activeTabID, openedID != anchorID else { return }
        selectTab(anchorID)
        openInSplitView(openedID)
    }
}
