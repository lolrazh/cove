import SwiftUI

/// The browser frame: a shell holding the tabs, and a content card holding the
/// navigation bar and the page.
///
/// Four arrangements, one layout. Nothing is inserted into or removed from the
/// stacks when switching between them; pieces only change size or slide, so mode
/// switches animate cleanly and never shift view identity mid-animation.
///
///   top tabs         the tab row is titlebar-height, tabs sit beside the traffic lights
///   top, hidden      the tab row collapses to the card inset; hovering the top edge floats it over the page
///   sidebar          the sidebar is docked left and pushes the card over
///   sidebar, hidden  the docked sidebar collapses; hovering the left edge floats it over the page
struct BrowserShellView<Content: View>: View {
    private let appServices: AppServices
    @ObservedObject private var settings: BrowserSettingsStore
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
        self._settings = ObservedObject(wrappedValue: appServices.settingsStore)
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
                    .padding(.leading, showsDockedSidebar ? 0 : ChromeMetrics.cardInset)
                    .padding([.trailing, .bottom], ChromeMetrics.cardInset)
            }
        }
        .background(ChromePalette.shell)
        .overlay(alignment: .top) {
            floatingTabRow
        }
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

    /// The titlebar band: top tabs beside the traffic lights.
    private var tabStrip: some View {
        TabStripView(tabManager: tabManager)
            .padding(.leading, tabRowLeadingInset)
            .padding(.trailing, ChromeMetrics.gutter)
            .padding(.bottom, ChromeMetrics.tabBottomInset)
            .frame(height: ChromeMetrics.titlebarHeight, alignment: .bottom)
    }

    /// The band in its docked position, above the card. Collapses to the card
    /// inset in sidebar mode and when top tabs are hidden.
    private var tabRow: some View {
        tabStrip
            .frame(height: showsTopRow ? ChromeMetrics.titlebarHeight : ChromeMetrics.cardInset, alignment: .bottom)
            .opacity(showsTopRow ? 1 : 0)
            .clipped()
            .allowsHitTesting(showsTopRow)
            .onHover(perform: chromeHover)
    }

    /// The band floating over the page while hidden top tabs are revealed. It
    /// is flush with the window's top, so only its bottom corners show.
    private var floatingTabRow: some View {
        tabStrip
            .chromeFloatingSurface(minimumRadius: ChromeRadius.tab)
            .onHover(perform: chromeHover)
            .offset(y: showsFloatingTopRow ? 0 : -(ChromeMetrics.titlebarHeight + ChromeMetrics.gutter * 4))
            .allowsHitTesting(showsFloatingTopRow)
    }

    private var tabRowLeadingInset: CGFloat {
        max(ChromeMetrics.gutter, trafficLightInset + ChromeMetrics.trafficLightTrailingGap)
    }

    /// Where the sidebar header's controls start, past the traffic lights, for
    /// a sidebar whose leading edge sits `sidebarOrigin` in from the window's.
    private func headerLeadingInset(sidebarOrigin: CGFloat) -> CGFloat {
        max(ChromeMetrics.sidebarInset, trafficLightInset - sidebarOrigin + ChromeMetrics.trafficLightTrailingGap)
    }

    /// The sidebar in its docked position. Its width animates to zero rather than
    /// the view being removed, so the card slides instead of jumping.
    private var dockedSidebar: some View {
        SidebarTabView(
            tabManager: tabManager,
            activeTab: activeTab,
            downloadManager: appServices.downloadManager,
            headerHeight: ChromeMetrics.titlebarHeight,
            headerLeadingInset: headerLeadingInset(sidebarOrigin: 0),
            onToggleDocked: toggleDocked
        )
        .frame(width: sidebarWidth)
        .overlay(alignment: .trailing) {
            resizeHandle
        }
        .frame(width: showsDockedSidebar ? sidebarWidth : 0, alignment: .trailing)
        .opacity(showsDockedSidebar ? 1 : 0)
        .clipped()
        .allowsHitTesting(showsDockedSidebar)
        .onHover(perform: chromeHover)
    }

    private var sidebarWidth: CGFloat {
        CGFloat(settings.sidebarWidth).clamped(to: ChromeMetrics.sidebarWidthRange)
    }

    /// Drag the sidebar's trailing edge to resize it. The handle covers the
    /// gap between the sidebar's rows and the card, so it never sits over
    /// either.
    private var resizeHandle: some View {
        Color.clear
            .frame(width: ChromeMetrics.sidebarInset)
            .contentShape(Rectangle())
            .pointerStyle(.columnResize)
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { drag in
                        let width = drag.location.x + ChromeMetrics.sidebarInset / 2
                        settings.setSidebarWidth(width.clamped(to: ChromeMetrics.sidebarWidthRange))
                    }
            )
    }

    /// The sidebar floating over the page while hidden-tabs mode is revealed.
    /// Inset by a gutter on every side, so its corners follow the window's.
    private var floatingSidebar: some View {
        SidebarTabView(
            tabManager: tabManager,
            activeTab: activeTab,
            downloadManager: appServices.downloadManager,
            headerHeight: ChromeMetrics.floatingSidebarHeaderHeight,
            headerLeadingInset: headerLeadingInset(sidebarOrigin: ChromeMetrics.gutter),
            onToggleDocked: toggleDocked
        )
        .frame(width: sidebarWidth)
        .frame(maxHeight: .infinity)
        .chromeFloatingSurface()
        .padding(ChromeMetrics.gutter)
        .onHover(perform: chromeHover)
        .offset(x: showsFloatingSidebar ? 0 : -(sidebarWidth + ChromeMetrics.gutter * 4))
        .allowsHitTesting(showsFloatingSidebar)
    }

    // MARK: - Content Card

    private var contentCard: some View {
        VStack(spacing: 0) {
            navigationBar

            ZStack(alignment: .top) {
                content
                contentLoadingIndicator
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay { LinkPreview(url: activeTab.hoveredLink) }
            .overlay { ToastOverlay(center: tabManager.toasts) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(.chrome())
        // A concentric clip also becomes the hit area, and resolves in the
        // wrong place: without this the card swallows clicks meant for the tabs.
        .contentShape(Rectangle())
        // The shadow sits behind the clip, or the clip would cut it off.
        .background {
            ConcentricRectangle.chrome()
                .fill(ChromePalette.content)
                .chromeShadow(.card)
        }
    }

    /// The toolbar above the page, in top-tab mode only. In sidebar mode its
    /// controls live in the sidebar and the card holds just the page; the bar
    /// collapses rather than leaving, so the mode switch animates.
    private var navigationBar: some View {
        VStack(spacing: 0) {
            NavigationBar(
                session: activeTab,
                downloadManager: appServices.downloadManager,
                onEditAddress: tabManager.editCurrentURL
            )

            Divider()
        }
        .frame(height: isTopMode ? nil : 0, alignment: .bottom)
        .opacity(isTopMode ? 1 : 0)
        .clipped()
        .allowsHitTesting(isTopMode)
    }

    private var contentLoadingIndicator: some View {
        PageProgressBar(progress: activeTab.estimatedProgress, isLoading: activeTab.isLoading)
            .id(activeTab.id)
    }

    // MARK: - Visibility

    private var isTopMode: Bool {
        tabManager.tabLayout == .horizontal
    }

    private var showsTopRow: Bool {
        isTopMode && !tabManager.hideTabs
    }

    private var showsFloatingTopRow: Bool {
        isTopMode && tabManager.hideTabs && areTabsVisible
    }

    private var showsDockedSidebar: Bool {
        tabManager.tabLayout == .sidebar && !tabManager.hideTabs
    }

    private var showsFloatingSidebar: Bool {
        isSidebarHideable && areTabsVisible
    }

    private var isTopRowHidden: Bool {
        isTopMode && tabManager.hideTabs && !areTabsVisible
    }

    private var isSidebarHideable: Bool {
        tabManager.tabLayout == .sidebar && tabManager.hideTabs
    }

    private var isSidebarHidden: Bool {
        isSidebarHideable && !areTabsVisible
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

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
