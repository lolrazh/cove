import SwiftUI
import Combine

/// A group owns only its sidebar frame. Its pages keep their existing identity.
struct SidebarTabGroup<Rows: View>: View {
    let group: TabGroup<UUID>
    let tabs: [TabSession]
    @ObservedObject var tabManager: TabManager
    @ViewBuilder let rows: () -> Rows

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDropTarget = false

    var body: some View {
        VStack(spacing: ChromeMetrics.sidebarRowSpacing) {
            if let representative = tabs.first {
                TabGroupHeader(group: group, representative: representative, tabs: tabs, tabManager: tabManager)
            }
            rows()
                .padding(.leading, 12)
                .environment(\.isInTabGroup, true)
        }
        .padding(4)
        .background {
            if let representative = tabs.first {
                TabGroupSurface(tab: representative)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(ChromePalette.onTheme.opacity(isDropTarget ? 0.6 : 0), lineWidth: 2)
                .allowsHitTesting(false)
        }
        .containerShape(RoundedRectangle(cornerRadius: 14))
        .acceptsTabGroupDrops(into: group.id, in: tabManager, dragging: $tabManager.draggedTabID, isTargeted: $isDropTarget)
        .animation(reduceMotion ? nil : ChromeMotion.hover, value: isDropTarget)
    }
}

private struct TabGroupSurface: View {
    @ObservedObject var tab: TabSession

    var body: some View {
        FaviconColorSurface(image: tab.favicon, isActive: true, cornerRadius: 14,
                            fillOpacity: 0.26, edgeWidth: 1)
    }
}

private struct TabGroupHeader: View {
    let group: TabGroup<UUID>
    @ObservedObject var representative: TabSession
    let tabs: [TabSession]
    @ObservedObject var tabManager: TabManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isRenaming = false
    @State private var draftName = ""
    @State private var automaticTitle = ""
    @State private var isHovered = false

    var body: some View {
        Group {
            if isRenaming {
                header
            } else {
                Button { tabManager.toggleGroupCollapsed(group.id) } label: { header }
                    .buttonStyle(.plain)
                    .highPriorityGesture(TapGesture().modifiers(.command).onEnded { toggleGroupSelection() })
            }
        }
        .onHover { isHovered = $0 }
        .animation(reduceMotion ? nil : ChromeMotion.hover, value: isHovered)
        .contextMenu { groupMenu }
        .onReceive(Publishers.MergeMany(tabs.map { $0.$pageTitle })) { _ in
            automaticTitle = TabGroupName.title(for: tabs.map { (title: $0.title, url: $0.currentURL) })
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            if let symbol = group.symbolName {
                Image(systemName: symbol).frame(width: 16, height: 16)
            } else {
                FaviconView(image: representative.favicon, size: 16)
            }
            if isRenaming {
                RenameField(prompt: "Group Name", text: $draftName, onCommit: finishRenaming) { isRenaming = false }
            } else {
                Text(title)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .rotationEffect(.degrees(group.isCollapsed ? 0 : 90))
                .opacity(0.55)
        }
        .font(.callout.weight(.semibold))
        .foregroundStyle(ChromePalette.onTheme)
        .padding(.horizontal, 8)
        .frame(height: ChromeMetrics.sidebarRowHeight)
        .background(ChromePalette.hover.opacity(isHovered || allSelected ? 1 : 0), in: .rect(cornerRadius: 10))
        .contentShape(Rectangle())
        .accessibilityElement(children: isRenaming ? .contain : .combine)
        .accessibilityLabel(title)
        .accessibilityValue("\(tabsCount) \(tabsCount == 1 ? "tab" : "tabs"), \(group.isCollapsed ? "collapsed" : "expanded")")
    }

    @ViewBuilder
    private var groupMenu: some View {
        Button(group.isCollapsed ? "Expand Group" : "Collapse Group") { tabManager.toggleGroupCollapsed(group.id) }
        Button("Rename Group…", action: beginRenaming)
        if group.customName != nil {
            Button("Use Automatic Name") { tabManager.renameGroup(group.id, to: "") }
        }
        Menu("Group Icon") {
            Button("Website Icon") { tabManager.setGroupSymbol(group.id, to: nil) }
            ForEach(Self.symbols, id: \.symbol) { option in
                Button(option.title, systemImage: option.symbol) { tabManager.setGroupSymbol(group.id, to: option.symbol) }
            }
        }
        Divider()
        Button("New Tab in Group") {
            tabManager.addTab()
            if let id = tabManager.activeTabID { tabManager.moveTabs([id], toGroup: group.id) }
        }
        Button("Select Tabs in Group") {
            if group.isCollapsed { tabManager.toggleGroupCollapsed(group.id) }
            tabManager.selectedTabIDs = Set(group.members)
            tabManager.tabSelectionAnchorID = group.members.first
        }
        if allSelected && tabManager.selectedTabIDs.count > group.members.count {
            Button("Group Selected Tabs") {
                _ = tabManager.createGroup(tabIDs: Array(tabManager.selectedTabIDs))
            }
            Button("Close Selected Tabs") {
                tabManager.closeTabs(Array(tabManager.selectedTabIDs))
            }
        }
        Button("Ungroup Tabs") { tabManager.removeGroup(group.id) }
        Divider()
        Button("Close Group") { tabManager.closeGroup(group.id) }
    }

    private var title: String {
        group.customName ?? (automaticTitle.isEmpty ? TabGroupName.title(for: tabs.map { (title: $0.title, url: $0.currentURL) }) : automaticTitle)
    }
    private var allSelected: Bool { Set(group.members).isSubset(of: tabManager.selectedTabIDs) }
    private var tabsCount: Int { group.members.count }

    private func toggleGroupSelection() {
        if allSelected {
            tabManager.selectedTabIDs.subtract(group.members)
        } else {
            tabManager.selectedTabIDs.formUnion(group.members)
        }
        tabManager.tabSelectionAnchorID = group.members.first
    }
    private static var symbols: [(title: String, symbol: String)] {
        [("Work", "briefcase"), ("Reading", "book"), ("Research", "magnifyingglass"),
         ("Code", "chevron.left.forwardslash.chevron.right"), ("Travel", "airplane"), ("Ideas", "lightbulb")]
    }

    private func beginRenaming() {
        draftName = title
        isRenaming = true
    }

    private func finishRenaming() {
        guard isRenaming else { return }
        isRenaming = false
        tabManager.renameGroup(group.id, to: draftName)
    }
}
