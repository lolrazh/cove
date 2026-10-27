import SwiftUI

/// Arc's sidebar: a header with the window controls and navigation, the URL
/// pill, then Favorites, Pinned, a Clear line, and Today, with the media
/// player and a footer.
struct SidebarTabView: View {
    @ObservedObject var tabManager: TabManager
    @ObservedObject var activeTab: TabSession
    let downloadManager: DownloadManager
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

    private var tabOrder: [UUID] {
        tabManager.tabs.map(\.id)
    }

    private var tabAnimation: Animation? {
        reduceMotion ? nil : ChromeMotion.tab
    }

    var body: some View {
        VStack(spacing: 0) {
            sections
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
        }
        .padding(.leading, headerLeadingInset)
        .padding(.trailing, ChromeMetrics.sidebarInset)
        .frame(height: headerHeight)
    }

    // MARK: - Sections

    private var sectionList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: ChromeMetrics.sidebarSectionSpacing) {
                if !tabManager.favorites.isEmpty {
                    SidebarFavoritesGrid(tabs: tabManager.favorites, activeTabID: tabManager.activeTabID) {
                        tabManager.selectTab($0)
                    }
                }

                if !tabManager.pinned.isEmpty {
                    tabRows(tabManager.pinned)
                }

                SidebarClearLine {
                    tabManager.clearTodayTabs()
                }

                today
            }
            .padding(.horizontal, ChromeMetrics.sidebarInset)
            .padding(.vertical, ChromeMetrics.sidebarSectionSpacing)
            .acceptsTabDrops(dragging: $draggedTabID)
            .animation(tabAnimation, value: tabOrder)
        }
    }

    /// New Tab on top, then today's tabs newest first, so a new tab appears
    /// right under the row that made it.
    private var today: some View {
        VStack(spacing: 2) {
            SidebarNewTabItem {
                tabManager.newTab()
            }

            tabRows(tabManager.tabs.reversed())
        }
    }

    private func tabRows(_ tabs: [TabSession]) -> some View {
        VStack(spacing: 2) {
            ForEach(tabs) { tab in
                ChromeTabItem(
                    tab: tab,
                    tabManager: tabManager,
                    presentation: .sidebar,
                    isActive: tab.id == tabManager.activeTabID,
                    canClose: tabManager.tabs.count > 1
                )
                .reorderableTab(tab, in: tabManager, dragging: $draggedTabID)
                .transition(.tabSlot(.vertical))
            }
        }
    }

    // MARK: - Footer

    /// Library (downloads for now) leading, the space dots centered. The new
    /// space button arrives with Spaces.
    private var footer: some View {
        HStack {
            DownloadsStatusButton(downloadManager: downloadManager, popoverEdge: .top)
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

/// Arc's Favorites: a grid of large tiles showing only the favicon.
private struct SidebarFavoritesGrid: View {
    let tabs: [TabSession]
    let activeTabID: UUID?
    let onSelect: (UUID) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(tabs) { tab in
                SidebarFavoriteTile(tab: tab, isActive: tab.id == activeTabID) {
                    onSelect(tab.id)
                }
            }
        }
    }
}

private struct SidebarFavoriteTile: View {
    @ObservedObject var tab: TabSession
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        FaviconView(image: tab.favicon, size: 20)
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background {
                if isActive {
                    ConcentricRectangle.chrome(minimum: ChromeRadius.tile)
                        .fill(ChromePalette.raised)
                        .chromeShadow(.raised)
                }
            }
            .chromeHoverSurface(restingFill: !isActive, minimumRadius: ChromeRadius.tile)
            .help(tab.title)
            .onTapGesture(perform: action)
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
