import SwiftUI

/// The browser frame: a shell holding the tabs, and a content card holding the
/// navigation bar and the page.
///
/// Four arrangements, one layout. Nothing is inserted into or removed from the
/// stacks when switching between them; pieces only change size or slide, so mode
/// switches animate cleanly and never shift view identity mid-animation.
///
///   top tabs         the tab row is titlebar-height, tabs sit beside the traffic lights
///   top, hidden      the tab row collapses to a gutter; hovering the top edge reopens it
///   sidebar          the sidebar is docked left and pushes the card over
///   sidebar, hidden  the docked sidebar collapses; hovering the left edge floats it over the page
struct BrowserShellView<Content: View>: View {
    private let appServices: AppServices
    @ObservedObject var tabManager: TabManager
    @ObservedObject var activeTab: TabSession
    @Binding var areTabsVisible: Bool
    let content: Content

    @Environment(\.trafficLightInset) private var trafficLightInset
    @State private var isHoveringChrome = false
    @State private var hideTask: Task<Void, Never>?

    init(
        appServices: AppServices,
        tabManager: TabManager,
        activeTab: TabSession,
        areTabsVisible: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) {
        self.appServices = appServices
        self._tabManager = ObservedObject(wrappedValue: tabManager)
        self._activeTab = ObservedObject(wrappedValue: activeTab)
        self._areTabsVisible = areTabsVisible
        self.content = content()
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            dockedSidebar

            VStack(spacing: 0) {
                tabRow
                contentCard
                    .padding(.leading, showsDockedSidebar ? 0 : ChromeMetrics.gutter)
                    .padding([.trailing, .bottom], ChromeMetrics.gutter)
            }
        }
        .background(ChromePalette.shell)
        .overlay(alignment: .topLeading) {
            floatingSidebar
        }
        .overlay(alignment: .top) {
            if isTopRowHidden {
                revealEdge.frame(height: ChromeMetrics.revealEdge)
            }
        }
        .overlay(alignment: .leading) {
            if isSidebarHidden {
                revealEdge.frame(width: ChromeMetrics.revealEdge)
            }
        }
        .animation(ChromeMotion.shell, value: tabManager.tabLayout)
        .animation(ChromeMotion.shell, value: tabManager.hideTabs)
        .animation(ChromeMotion.shell, value: areTabsVisible)
        .onChange(of: tabManager.hideTabs) { _, _ in
            hideTask?.cancel()
        }
    }

    // MARK: - Tabs

    /// Top tabs, beside the traffic lights. Collapses to a gutter in sidebar mode
    /// and when top tabs are hidden.
    private var tabRow: some View {
        TabStripView(tabManager: tabManager)
            .padding(.leading, tabRowLeadingInset)
            .padding(.trailing, ChromeMetrics.gutter)
            .padding(.bottom, ChromeMetrics.tabBottomInset)
            .frame(height: ChromeMetrics.titlebarHeight, alignment: .bottom)
            .frame(height: showsTopRow ? ChromeMetrics.titlebarHeight : ChromeMetrics.gutter, alignment: .bottom)
            .opacity(showsTopRow ? 1 : 0)
            .clipped()
            .allowsHitTesting(showsTopRow)
            .onHover(perform: chromeHover)
    }

    private var tabRowLeadingInset: CGFloat {
        max(ChromeMetrics.gutter, trafficLightInset + ChromeMetrics.trafficLightTrailingGap)
    }

    /// The sidebar in its docked position. Its width animates to zero rather than
    /// the view being removed, so the card slides instead of jumping.
    private var dockedSidebar: some View {
        SidebarTabView(
            tabManager: tabManager,
            headerHeight: ChromeMetrics.titlebarHeight,
            onToggleDocked: toggleDocked
        )
        .frame(width: ChromeMetrics.sidebarWidth)
        .frame(width: showsDockedSidebar ? ChromeMetrics.sidebarWidth : 0, alignment: .trailing)
        .opacity(showsDockedSidebar ? 1 : 0)
        .clipped()
        .allowsHitTesting(showsDockedSidebar)
        .onHover(perform: chromeHover)
    }

    /// The sidebar floating over the page while hidden-tabs mode is revealed.
    /// Inset by a gutter on every side, so its corners follow the window's.
    private var floatingSidebar: some View {
        SidebarTabView(
            tabManager: tabManager,
            headerHeight: ChromeMetrics.floatingSidebarHeaderHeight,
            onToggleDocked: toggleDocked
        )
        .frame(width: ChromeMetrics.sidebarWidth)
        .frame(maxHeight: .infinity)
        // Elevation comes from the shadow alone; no outline.
        .background {
            ConcentricRectangle.chrome()
                .fill(ChromePalette.shell)
                .shadow(color: .black.opacity(0.18), radius: 16, y: 4)
        }
        .padding(ChromeMetrics.gutter)
        .onHover(perform: chromeHover)
        .offset(x: showsFloatingSidebar ? 0 : -(ChromeMetrics.sidebarWidth + ChromeMetrics.gutter * 4))
        .allowsHitTesting(showsFloatingSidebar)
    }

    // MARK: - Content Card

    private var contentCard: some View {
        VStack(spacing: 0) {
            NavigationBar(
                session: activeTab,
                downloadManager: appServices.downloadManager
            )
            .id(activeTab.id)

            Divider()

            ZStack(alignment: .top) {
                content
                contentLoadingIndicator
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ChromePalette.content)
        .clipShape(.chrome())
        // A concentric clip also becomes the hit area, and resolves in the
        // wrong place: without this the card swallows clicks meant for the tabs.
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var contentLoadingIndicator: some View {
        if activeTab.isLoading {
            ProgressView(value: activeTab.estimatedProgress)
                .progressViewStyle(.linear)
                .tint(.accentColor)
                .labelsHidden()
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Visibility

    private var showsTopRow: Bool {
        tabManager.tabLayout == .horizontal && (!tabManager.hideTabs || areTabsVisible)
    }

    private var showsDockedSidebar: Bool {
        tabManager.tabLayout == .sidebar && !tabManager.hideTabs
    }

    private var showsFloatingSidebar: Bool {
        tabManager.tabLayout == .sidebar && tabManager.hideTabs && areTabsVisible
    }

    private var isTopRowHidden: Bool {
        tabManager.tabLayout == .horizontal && tabManager.hideTabs && !areTabsVisible
    }

    private var isSidebarHidden: Bool {
        tabManager.tabLayout == .sidebar && tabManager.hideTabs && !areTabsVisible
    }

    // MARK: - Hide / Reveal

    private var revealEdge: some View {
        Color.clear
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering { reveal() }
            }
    }

    private func reveal() {
        hideTask?.cancel()
        areTabsVisible = true
        // Hide again unless the pointer actually moves onto the tabs. Without this
        // the tabs stay stuck open if the pointer leaves through the window edge.
        scheduleHide(after: .milliseconds(1200))
    }

    private func chromeHover(_ hovering: Bool) {
        isHoveringChrome = hovering
        if hovering {
            hideTask?.cancel()
        } else {
            scheduleHide(after: .milliseconds(600))
        }
    }

    private func scheduleHide(after delay: Duration) {
        hideTask?.cancel()
        guard tabManager.hideTabs else { return }

        hideTask = Task { @MainActor in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, !isHoveringChrome, tabManager.hideTabs else { return }
            areTabsVisible = false
        }
    }

    private func toggleDocked() {
        tabManager.setHideTabs(!tabManager.hideTabs)
    }
}
