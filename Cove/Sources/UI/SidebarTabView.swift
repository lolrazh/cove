import SwiftUI

/// The sidebar: a header with the window controls and profile name, then
/// Pinned, and Today, with the media
/// player and a footer. The Library takes the place of all above the media
/// player while it's open.
struct SidebarTabView: View {
    @ObservedObject var tabManager: TabManager
    /// Height of the row that holds the traffic lights. Set so the row's center
    /// lands on the traffic lights' centerline wherever the sidebar is placed.
    let headerHeight: CGFloat
    /// Where the header's controls start: just past the traffic lights.
    let headerLeadingInset: CGFloat
    let acceptsProfileSwipes: Bool

    var body: some View {
        VStack(spacing: 0) {
            SidebarContent(library: tabManager.library, headerHeight: headerHeight, headerLeadingInset: headerLeadingInset) {
                sections
            }
            MediaPlayer(tabManager: tabManager, style: .card)
                .padding(.horizontal, ChromeMetrics.sidebarInset)
            footer
        }
    }

    // MARK: - Header

    /// The header floats over the top of the scroll view instead of sitting in a
    /// row above it. macOS extends a scroll view up under the titlebar, and a row
    /// above it would sit behind that extension and never get clicks.
    private var sections: some View {
        ProfilePager(tabManager: tabManager, isEnabled: acceptsProfileSwipes) { page in
            SidebarSections(tabManager: tabManager, page: page)
                .contentMargins(.top, headerHeight, for: .scrollContent)
                .scrollEdgeEffectHidden(true, for: .top)
        }
        .mask {
            VStack(spacing: 0) {
                Color.clear.frame(height: headerHeight)
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                    .frame(height: ChromeMetrics.sidebarSectionSpacing)
                Color.black
            }
        }
        .overlay(alignment: .top) { navigationRow }
    }

    /// The profile name shares the header with the native window controls.
    /// Navigation and extension actions live above the page.
    private var navigationRow: some View {
        HStack(spacing: 4) {
            if tabManager.isPrivate {
                PrivateBadge()
            } else if let profile = tabManager.activeProfile {
                SidebarProfileTitle(profile: profile, tabManager: tabManager)
                    .anchorPreference(key: ProfileEditorAnchor.self, value: .bounds) {
                        acceptsProfileSwipes ? $0 : nil
                    }
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, headerLeadingInset)
        .padding(.trailing, ChromeMetrics.sidebarInset)
        .frame(height: headerHeight)
    }

    // MARK: - Footer

    /// The Library leading, the profiles centered, New Profile trailing. A
    /// private window has no profiles.
    private var footer: some View {
        HStack {
            LibraryButton(library: tabManager.library)
            Spacer()
            if !tabManager.isPrivate {
                Button(action: tabManager.newProfile) {
                    Image(systemName: ChromeSymbols.Profiles.newProfile)
                }
                .buttonStyle(ChromeButtonStyle(restingOpacity: 0.6))
                .accessibilityLabel("New Profile")
                .help("New Profile")
            }
        }
        .overlay {
            SidebarProfileIcons(tabManager: tabManager)
                .padding(.horizontal, ChromeMetrics.iconButtonSize + 4)
        }
        .padding(.horizontal, ChromeMetrics.sidebarInset)
        .frame(height: ChromeMetrics.sidebarFooterHeight)
    }
}

private struct SidebarSections: View {
    @ObservedObject var tabManager: TabManager
    let page: ProfileSidebarPage

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Everything shown, in order, so moves between and within sections
    /// animate alike; folding a folder moves its tabs out of the order.
    private var sidebarOrder: [UUID] {
        page.pinned.visibleTabs.map(\.id)
            + page.today.map(\.id)
            + page.pinned.documents
            + page.pinned.folders.map(\.id)
            + page.splits.map(\.id)
    }

    private var tabAnimation: Animation? {
        reduceMotion ? nil : ChromeMotion.sidebarTab
    }

    // MARK: - Sections

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: ChromeMetrics.sidebarSectionSpacing) {
                    pinned

                    today
                }
                .padding(.horizontal, ChromeMetrics.sidebarInset)
                .padding(.vertical, ChromeMetrics.sidebarSectionSpacing)
                .acceptsTabDrops(dragging: $tabManager.draggedTabID)
                .animation(tabAnimation, value: sidebarOrder)
                .animation(tabAnimation, value: tabManager.draggedTabID != nil)
            }
            .onChange(of: page.selection) { _, selection in
                guard let selection else { return }
                let row = page.splits.first { $0.contains(selection) }?.id ?? selection
                // With no anchor, move only far enough to reveal the row.
                // Keep finger-driven reordering in control of its own scroll.
                guard tabManager.draggedTabID == nil else { return }
                proxy.scrollTo(row)
            }
        }
        .environment(\.sidebarSelection, page.selection)
    }

    /// An empty section shows only while a tab is being dragged, as somewhere
    /// to drop it; never in a private window, which keeps no pins.
    @ViewBuilder
    private var pinned: some View {
        if !page.pinned.isEmpty {
            let tabs = page.pinned.items.compactMap(\.tab)
            let otherItems = page.pinned.items.filter { $0.tab == nil }
            VStack(spacing: ChromeMetrics.sidebarSectionSpacing) {
                if !tabs.isEmpty {
                    SidebarPinnedGrid(tabs: tabs, tabManager: tabManager)
                }
                if !otherItems.isEmpty {
                    SidebarPinnedList(items: otherItems, tabManager: tabManager, draggedTabID: $tabManager.draggedTabID)
                }
            }
            .acceptsTabDrops(toEndOf: .pinned, in: tabManager, dragging: $tabManager.draggedTabID)
        } else if showsDropZones {
            SidebarDropZone(title: "Pinned")
                .acceptsTabDrops(toEndOf: .pinned, in: tabManager, dragging: $tabManager.draggedTabID)
        }
    }

    private var showsDropZones: Bool {
        tabManager.draggedTabID != nil && !tabManager.isPrivate
    }

    /// Today's tabs keep their stored order, so new tabs open downward.
    /// A split's tabs share one row.
    private var today: some View {
        VStack(spacing: ChromeMetrics.sidebarRowSpacing) {
            ForEach(page.today.entries(splits: page.splits)) { entry in
                switch entry {
                case .tab(let tab):
                    SidebarTabRow(tab: tab, tabManager: tabManager, draggedTabID: $tabManager.draggedTabID)
                case .document(let id):
                    SidebarDocumentRow(id: id, tabManager: tabManager, draggedTabID: $tabManager.draggedTabID)
                case .split(_, let tabs):
                    SidebarSplitRow(tabs: tabs, tabManager: tabManager, draggedTabID: $tabManager.draggedTabID)
                }
            }

            SidebarNewTabItem {
                tabManager.newTab()
            }
            .contextMenu {
                if tabManager.documentStore != nil {
                    Button("New Note") { tabManager.newDocument(.note) }
                    Button("New Easel") { tabManager.newDocument(.easel) }
                }
            }
        }
    }

}

extension EnvironmentValues {
    @Entry var sidebarSelection: UUID? = nil
}

/// A tab's row in Pinned or Today.
private struct SidebarTabRow: View {
    @Environment(\.sidebarSelection) private var selection
    let tab: TabSession
    @ObservedObject var tabManager: TabManager
    @Binding var draggedTabID: UUID?

    var body: some View {
        ChromeTabItem(
            tab: tab,
            tabManager: tabManager,
            presentation: .sidebar,
            isActive: selection == tab.id,
            canClose: tabManager.canCloseTab(tab.id)
        )
        .reorderableTab(tab.id, in: tabManager, dragging: $draggedTabID)
        // The selected row covers siblings while they make room beneath it.
        .zIndex(selection == tab.id ? 1 : 0)
        .transition(.tabSlot(.vertical))
    }
}

/// A note's row in Pinned or Today.
private struct SidebarDocumentRow: View {
    @Environment(\.sidebarSelection) private var selection
    let id: UUID
    @ObservedObject var tabManager: TabManager
    @Binding var draggedTabID: UUID?

    var body: some View {
        if let store = tabManager.documentStore {
            DocumentTabItem(id: id, store: store, tabManager: tabManager, presentation: .sidebar, isActive: selection == id)
                .reorderableTab(id, in: tabManager, dragging: $draggedTabID)
                .transition(.tabSlot(.vertical))
        }
    }
}

/// A split's tabs in one row, side by side as on screen, on a resting fill
/// that groups them; the focused one is raised while the split is selected.
private struct SidebarSplitRow: View {
    @Environment(\.sidebarSelection) private var selection
    let tabs: [TabSession]
    @ObservedObject var tabManager: TabManager
    @Binding var draggedTabID: UUID?

    var body: some View {
        HStack(spacing: 2) {
            ForEach(tabs) { tab in
                ChromeTabItem(
                    tab: tab,
                    tabManager: tabManager,
                    presentation: .sidebar,
                    isActive: selection == tab.id,
                    canClose: tabManager.canCloseTab(tab.id)
                )
                .reorderableTab(tab.id, in: tabManager, dragging: $draggedTabID)
            }
        }
        .background(ChromePalette.resting, in: .chrome(minimum: ChromeRadius.tab))
        .transition(.tabSlot(.vertical))
    }
}

// MARK: - Pinned

/// The Pinned section: tabs and folders, folders holding lists of their own.
private struct SidebarPinnedList: View {
    let items: [SidebarItem<TabSession>]
    @ObservedObject var tabManager: TabManager
    @Binding var draggedTabID: UUID?

    var body: some View {
        VStack(spacing: ChromeMetrics.sidebarRowSpacing) {
            ForEach(items) { item in
                switch item {
                case .tab(let tab):
                    SidebarTabRow(tab: tab, tabManager: tabManager, draggedTabID: $draggedTabID)
                case .document(let id):
                    SidebarDocumentRow(id: id, tabManager: tabManager, draggedTabID: $draggedTabID)
                case .folder(let folder):
                    SidebarFolderRow(folder: folder, tabManager: tabManager, draggedTabID: $draggedTabID)
                        .transition(.tabSlot(.vertical))

                    if !folder.isCollapsed {
                        SidebarPinnedList(items: folder.contents.items, tabManager: tabManager, draggedTabID: $draggedTabID)
                            .padding(.leading, ChromeMetrics.sidebarFolderIndent)
                    }
                }
            }
        }
    }
}

/// A folder's row: click to fold or unfold, double-click to rename, drop a
/// tab on it to file the tab inside.
private struct SidebarFolderRow: View {
    let folder: SidebarFolder<TabSession>
    @ObservedObject var tabManager: TabManager
    @Binding var draggedTabID: UUID?

    @State private var isHovered = false
    @State private var isDropTarget = false
    @State private var isRenaming = false
    @State private var draftName = ""

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: ChromeSymbols.Tabs.folder)
                .foregroundStyle(.secondary)
                .frame(width: 16, height: 16)

            nameView
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: ChromeSymbols.Tabs.collapsed)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .rotationEffect(.degrees(folder.isCollapsed ? 0 : 90))
                .padding(.trailing, 4)
        }
        .font(.callout)
        .padding(.leading, 8)
        .padding(.trailing, ChromeMetrics.tabAccessoryInset)
        .frame(height: ChromeMetrics.sidebarRowHeight)
        .frame(maxWidth: .infinity)
        .background {
            if isDropTarget || isHovered {
                ConcentricRectangle.chrome(minimum: ChromeRadius.tab).fill(ChromePalette.hover)
            }
        }
        .contentShape(Rectangle())
        .animation(ChromeMotion.hover, value: isHovered)
        .animation(ChromeMotion.hover, value: isDropTarget)
        .animation(ChromeMotion.sidebarTab, value: folder.isCollapsed)
        .onHover { isHovered = $0 }
        .onTapGesture { tabManager.toggleFolderCollapsed(folder.id) }
        .simultaneousGesture(TapGesture(count: 2).onEnded(beginRenaming))
        .contextMenu {
            Button("Rename Folder…", action: beginRenaming)
            Button("New Folder") {
                tabManager.newFolder(in: folder.id)
            }
            Divider()
            Button("Delete Folder") {
                tabManager.deleteFolder(folder.id)
            }
        }
        .draggableTab(folder.id)
        .acceptsTabDrops(into: folder.id, in: tabManager, dragging: $draggedTabID, isTargeted: $isDropTarget)
        // A folder just made asks for its name.
        .onChange(of: tabManager.folderToName, initial: true) { _, id in
            guard id == folder.id else { return }
            tabManager.folderToName = nil
            beginRenaming()
        }
    }

    @ViewBuilder
    private var nameView: some View {
        if isRenaming {
            RenameField(prompt: "Folder Name", text: $draftName, onCommit: finishRenaming) { isRenaming = false }
        } else {
            Text(folder.name)
                .foregroundStyle(ChromePalette.onTheme)
                .lineLimit(1)
        }
    }

    private func beginRenaming() {
        draftName = folder.name
        isRenaming = true
    }

    private func finishRenaming() {
        guard isRenaming else { return }
        isRenaming = false
        tabManager.renameFolder(folder.id, to: draftName)
    }
}

/// Where an empty section would be, while a tab is being dragged.
private struct SidebarDropZone: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.callout)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .frame(height: ChromeMetrics.sidebarRowHeight)
            .background {
                ConcentricRectangle.chrome(minimum: ChromeRadius.tab)
                    .stroke(.tertiary, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .padding(0.5)
            }
            .contentShape(Rectangle())
            .transition(.opacity)
    }
}


private struct SidebarNewTabItem: View {
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: ChromeSymbols.Tabs.add)
                .frame(width: 16, height: 16)

            Text("New Tab")

            Spacer(minLength: 0)
        }
        .font(.callout)
        .foregroundStyle(ChromePalette.onTheme)
        .padding(.horizontal, 8)
        .frame(height: ChromeMetrics.sidebarRowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .chromeHoverSurface(minimumRadius: ChromeRadius.tab)
        .geometryGroup()
        .onTapGesture(perform: action)
    }
}

/// The tabs, or the Library pushed in from the trailing edge in their place,
/// as in Arc. Back slides the tabs in again.
private struct SidebarContent<Tabs: View>: View {
    @ObservedObject var library: LibraryModel
    let headerHeight: CGFloat
    let headerLeadingInset: CGFloat
    @ViewBuilder let tabs: Tabs

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if library.isPresented {
                SidebarLibrary(model: library, headerHeight: headerHeight, headerLeadingInset: headerLeadingInset)
                    .transition(push(from: .trailing))
            } else {
                tabs
                    .transition(push(from: .leading))
            }
        }
        .frame(maxHeight: .infinity)
        .clipped()
        .animation(reduceMotion ? ChromeMotion.fade : ChromeMotion.shell, value: library.isPresented)
    }

    private func push(from edge: Edge) -> AnyTransition {
        reduceMotion ? .opacity : .move(edge: edge).combined(with: .opacity)
    }
}
