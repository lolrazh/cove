import SwiftUI

/// Arc's sidebar: a header with the window controls and navigation, the URL
/// pill, then Favorites, Pinned, a Clear line, and Today, with the media
/// player and a footer. The Library takes the place of all above the media
/// player while it's open.
struct SidebarTabView: View {
    @ObservedObject var tabManager: TabManager
    @ObservedObject var activeTab: TabSession
    /// Height of the row that holds the traffic lights. Set so the row's center
    /// lands on the traffic lights' centerline wherever the sidebar is placed.
    let headerHeight: CGFloat
    /// Where the header's controls start: just past the traffic lights.
    let headerLeadingInset: CGFloat
    /// Whether this sidebar's URL pill presents site controls: the one on
    /// screen does, docked or floating.
    let presentsSiteControls: Bool
    let onToggleDocked: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draggedTabID: UUID?

    /// Everything shown, in order, so moves between and within sections
    /// animate alike; folding a folder moves its tabs out of the order.
    private var sidebarOrder: [UUID] {
        (tabManager.favorites + tabManager.pinned.visibleTabs + tabManager.tabs).map(\.id)
            + tabManager.pinned.folders.map(\.id)
    }

    private var tabAnimation: Animation? {
        reduceMotion ? nil : ChromeMotion.tab
    }

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
        sectionList
            .contentMargins(.top, headerHeight + ChromeMetrics.sidebarRowHeight, for: .scrollContent)
            .scrollEdgeEffectHidden(true, for: .top)
            .overlay(alignment: .top) {
                header
            }
    }

    private var header: some View {
        VStack(spacing: 0) {
            navigationRow

            SidebarAddressPill(tabManager: tabManager, session: activeTab, presentsSiteControls: presentsSiteControls)
                .padding(.horizontal, ChromeMetrics.sidebarInset)
        }
        .background { headerBacking }
    }

    /// Rows scroll up under the header. This hides them behind it and fades
    /// them out over the gap below the pill instead of cutting them off.
    private var headerBacking: some View {
        Rectangle()
            .fill(ChromePalette.shell)
            .padding(.bottom, -ChromeMetrics.sidebarSectionSpacing)
            .mask {
                VStack(spacing: 0) {
                    Color.black
                    LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: ChromeMetrics.sidebarSectionSpacing)
                }
            }
            .allowsHitTesting(false)
    }

    /// Arc's header row: traffic lights, the dock toggle, then navigation.
    private var navigationRow: some View {
        HStack(spacing: 4) {
            Button(action: onToggleDocked) {
                Image(systemName: ChromeSymbols.Tabs.sidebarLayout)
            }
            .buttonStyle(ChromeButtonStyle())
            .help(tabManager.hideTabs ? "Keep sidebar open" : "Hide sidebar")

            NavigationControls(session: activeTab)

            Spacer(minLength: 0)

            if tabManager.isPrivate {
                // The header has no room for the word beside the controls.
                PrivateBadge()
                    .labelStyle(.iconOnly)
            }
        }
        .padding(.leading, headerLeadingInset)
        .padding(.trailing, ChromeMetrics.sidebarInset)
        .frame(height: headerHeight)
    }

    // MARK: - Sections

    private var sectionList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: ChromeMetrics.sidebarSectionSpacing) {
                favorites
                pinned

                SidebarClearLine {
                    tabManager.clearTodayTabs()
                }

                today
            }
            .padding(.horizontal, ChromeMetrics.sidebarInset)
            .padding(.vertical, ChromeMetrics.sidebarSectionSpacing)
            .acceptsTabDrops(dragging: $draggedTabID)
            .animation(tabAnimation, value: sidebarOrder)
            .animation(tabAnimation, value: draggedTabID != nil)
        }
    }

    /// An empty section shows only while a tab is being dragged, as somewhere
    /// to drop it.
    @ViewBuilder
    private var favorites: some View {
        if !tabManager.favorites.isEmpty {
            SidebarFavoritesGrid(tabs: tabManager.favorites, tabManager: tabManager, draggedTabID: $draggedTabID)
                .acceptsTabDrops(toEndOf: .favorites, in: tabManager, dragging: $draggedTabID)
        } else if draggedTabID != nil {
            SidebarDropZone(title: "Favorites")
                .acceptsTabDrops(toEndOf: .favorites, in: tabManager, dragging: $draggedTabID)
        }
    }

    @ViewBuilder
    private var pinned: some View {
        if !tabManager.pinned.isEmpty {
            SidebarPinnedList(items: tabManager.pinned.items, tabManager: tabManager, draggedTabID: $draggedTabID)
                .acceptsTabDrops(toEndOf: .pinned, in: tabManager, dragging: $draggedTabID)
        } else if draggedTabID != nil {
            SidebarDropZone(title: "Pinned")
                .acceptsTabDrops(toEndOf: .pinned, in: tabManager, dragging: $draggedTabID)
        }
    }

    /// New Tab on top, then today's tabs newest first, so a new tab appears
    /// right under the row that made it.
    private var today: some View {
        VStack(spacing: 2) {
            SidebarNewTabItem {
                tabManager.newTab()
            }

            ForEach(tabManager.tabs.reversed()) { tab in
                SidebarTabRow(tab: tab, tabManager: tabManager, draggedTabID: $draggedTabID)
            }
        }
    }

    // MARK: - Footer

    /// The Library leading, the space dots centered. The new space button
    /// arrives with Spaces.
    private var footer: some View {
        HStack {
            LibraryButton(library: tabManager.library)
            Spacer()
        }
        .overlay {
            Circle()
                .fill(.secondary)
                .frame(width: 6, height: 6)
                .help("Space")
        }
        .padding(.horizontal, ChromeMetrics.sidebarInset)
        .frame(height: ChromeMetrics.sidebarFooterHeight)
    }
}

/// A tab's row in Pinned or Today.
private struct SidebarTabRow: View {
    let tab: TabSession
    @ObservedObject var tabManager: TabManager
    @Binding var draggedTabID: UUID?

    var body: some View {
        ChromeTabItem(
            tab: tab,
            tabManager: tabManager,
            presentation: .sidebar,
            isActive: tab.id == tabManager.activeTabID,
            canClose: tabManager.canCloseTab(tab.id)
        )
        .reorderableTab(tab.id, in: tabManager, dragging: $draggedTabID)
        .transition(.tabSlot(.vertical))
    }
}

// MARK: - Favorites

/// Arc's Favorites: a grid of tiles showing only the favicon, as many to a
/// row as the sidebar's width allows.
private struct SidebarFavoritesGrid: View {
    let tabs: [TabSession]
    @ObservedObject var tabManager: TabManager
    @Binding var draggedTabID: UUID?

    private let columns = [GridItem(
        .adaptive(minimum: ChromeMetrics.favoriteTileRange.lowerBound, maximum: ChromeMetrics.favoriteTileRange.upperBound),
        spacing: 6
    )]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(tabs) { tab in
                SidebarFavoriteTile(tab: tab, isActive: tab.id == tabManager.activeTabID) {
                    tabManager.selectTab(tab.id)
                }
                .contextMenu {
                    TabActions(tab: tab, tabManager: tabManager, placement: .tab(rename: {}))
                }
                .reorderableTab(tab.id, in: tabManager, dragging: $draggedTabID)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
    }
}

private struct SidebarFavoriteTile: View {
    @ObservedObject var tab: TabSession
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        FaviconView(image: tab.favicon, size: 16)
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background {
                if isActive {
                    ConcentricRectangle.chrome(minimum: ChromeRadius.tab)
                        .fill(ChromePalette.raised)
                        .chromeShadow(.raised)
                }
            }
            .chromeHoverSurface(restingFill: !isActive, minimumRadius: ChromeRadius.tab)
            .opacity(tab.isAsleep ? 0.7 : 1)
            .animation(ChromeMotion.fade, value: tab.isAsleep)
            .help(tab.title)
            .onTapGesture(perform: action)
    }
}

// MARK: - Pinned

/// The Pinned section: tabs and folders, folders holding lists of their own.
private struct SidebarPinnedList: View {
    let items: [SidebarItem<TabSession>]
    @ObservedObject var tabManager: TabManager
    @Binding var draggedTabID: UUID?

    var body: some View {
        VStack(spacing: 2) {
            ForEach(items) { item in
                switch item {
                case .tab(let tab):
                    SidebarTabRow(tab: tab, tabManager: tabManager, draggedTabID: $draggedTabID)
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
    @FocusState private var isNameFieldFocused: Bool

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
        .animation(ChromeMotion.tab, value: folder.isCollapsed)
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
        .draggableTab(folder.id, dragging: $draggedTabID)
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
            TextField("Folder Name", text: $draftName)
                .textFieldStyle(.plain)
                .focused($isNameFieldFocused)
                .onAppear { isNameFieldFocused = true }
                .onSubmit(finishRenaming)
                .onExitCommand { isRenaming = false }
                .onChange(of: isNameFieldFocused) { _, isFocused in
                    if !isFocused { finishRenaming() }
                }
        } else {
            Text(folder.name)
                .foregroundStyle(isHovered ? .primary : .secondary)
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

/// The line between Pinned and Today. Hovering it offers Clear, which closes
/// everything in Today.
private struct SidebarClearLine: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Rectangle()
            .fill(.separator)
            .frame(height: 1)
            .overlay {
                Button(action: action) {
                    Label("Clear", systemImage: ChromeSymbols.Tabs.clear)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .background(ChromePalette.shell)
                }
                .buttonStyle(.plain)
                .opacity(isHovered ? 1 : 0)
            }
            .frame(height: ChromeMetrics.sidebarSectionSpacing * 2)
            .contentShape(Rectangle())
            .animation(ChromeMotion.hover, value: isHovered)
            .onHover { isHovered = $0 }
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
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .frame(height: ChromeMetrics.sidebarRowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .chromeHoverSurface(minimumRadius: ChromeRadius.tab)
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
