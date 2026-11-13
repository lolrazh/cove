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
///   sidebar          the sidebar is docked left; navigation stays in the card
///   sidebar, hidden  the docked sidebar collapses; hovering the left edge floats it over the page
struct BrowserShellView<Content: View>: View {
    private let appServices: AppServices
    @ObservedObject private var settings: BrowserSettingsStore
    @ObservedObject var tabManager: TabManager
    let activeTab: TabSession
    @Binding var areTabsVisible: Bool
    let content: Content

    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.trafficLightInset) private var trafficLightInset
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPointerOverTabs = false

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
        self.activeTab = activeTab
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
        .background { ChromeAmbientBackground() }
        .overlay(alignment: .top) {
            floatingTabRow
        }
        .overlay(alignment: .topLeading) {
            floatingSidebar
        }
        .overlay {
            CommandBarOverlay(model: tabManager.commandBar, onOpenLittleCove: appServices.externalURLRouter.openLittleCove)
        }
        .backgroundPreferenceValue(ProfileEditorAnchor.self) { anchor in
            GeometryReader { geometry in
                ProfileEditorPopover(
                    store: appServices.profileStore,
                    profileID: $tabManager.profileToEdit,
                    anchor: anchor.map { geometry[$0] } ?? CGRect(
                        x: tabRowLeadingInset, y: 0, width: ChromeMetrics.tabHeight,
                        height: showsTopRow ? ChromeMetrics.titlebarHeight : ChromeMetrics.cardInset
                    ),
                    canPresent: isTopMode || anchor != nil
                )
            }
        }
        .contentShape(Rectangle())
        .onContinuousHover(perform: trackPointer)
        .animation(reduceMotion ? nil : ChromeMotion.shell, value: tabManager.tabLayout)
        .animation(reduceMotion ? nil : ChromeMotion.shell, value: tabManager.hideTabs)
        .onChange(of: tabManager.activeTabID) { _, _ in
            tabManager.commandBar.dismiss()
        }
        .onChange(of: tabManager.activeDocumentID) { _, _ in
            tabManager.commandBar.dismiss()
        }
        // The Library opens in the sidebar, so a hidden one comes out for it.
        .onReceive(tabManager.library.$isPresented) { isPresented in
            guard isSidebarHideable else { return }
            areTabsVisible = isPresented || isPointerOverTabs
        }
        .onReceive(tabManager.library.$downloadsPresented) { isPresented in
            if isPresented && tabManager.hideTabs { areTabsVisible = true }
            if !isPresented { hideIfOutside() }
        }
        .onChange(of: tabManager.isShowingSiteControls) { _, isPresented in
            if !isPresented { hideIfOutside() }
        }
        .onChange(of: tabManager.profileToEdit) { _, id in
            if id != nil && isSidebarHideable { areTabsVisible = true }
            if id == nil { hideIfOutside() }
        }
    }

    // MARK: - Tabs

    /// The titlebar band: top tabs beside the traffic lights.
    private func tabStrip(isVisible: Bool) -> some View {
        HStack(spacing: 4) {
            TabStripView(tabManager: tabManager)
            DownloadsButton(library: tabManager.library, manager: tabManager.services.downloadManager,
                            colorScheme: systemColorScheme, isVisible: isVisible)
                .id(tabManager.activeProfileID)
        }
            .environment(\.colorScheme, .light)
            .padding(.leading, tabRowLeadingInset)
            .padding(.trailing, ChromeMetrics.gutter)
            .padding(.bottom, ChromeMetrics.tabBottomInset)
            .frame(height: ChromeMetrics.titlebarHeight, alignment: .bottom)
    }

    /// The band in its docked position, above the card. Collapses to the card
    /// inset in sidebar mode and when top tabs are hidden.
    private var tabRow: some View {
        tabStrip(isVisible: showsTopRow)
            .frame(height: showsTopRow ? ChromeMetrics.titlebarHeight : ChromeMetrics.cardInset, alignment: .bottom)
            .opacity(showsTopRow ? 1 : 0)
            .clipped()
            .allowsHitTesting(showsTopRow)
            .accessibilityHidden(!showsTopRow)
    }

    /// The band floating over the page while hidden top tabs are revealed. It
    /// is flush with the window's top, so only its bottom corners show.
    private var floatingTabRow: some View {
        tabStrip(isVisible: showsFloatingTopRow)
            .chromeFloatingSurface(minimumRadius: ChromeRadius.tab)
            .chromeSlide(
                isShown: showsFloatingTopRow,
                from: CGSize(width: 0, height: -(ChromeMetrics.titlebarHeight + ChromeMetrics.gutter * 4))
            )
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
            headerHeight: ChromeMetrics.titlebarHeight,
            headerLeadingInset: headerLeadingInset(sidebarOrigin: 0),
            acceptsProfileSwipes: showsDockedSidebar,
            popoverColorScheme: systemColorScheme
        )
        .environment(\.colorScheme, .light)
        .frame(width: sidebarWidth)
        .overlay(alignment: .trailing) {
            resizeHandle
        }
        .frame(width: showsDockedSidebar ? sidebarWidth : 0, alignment: .trailing)
        .opacity(showsDockedSidebar ? 1 : 0)
        .clipped()
        .allowsHitTesting(showsDockedSidebar)
        .accessibilityHidden(!showsDockedSidebar)
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
            headerHeight: ChromeMetrics.floatingSidebarHeaderHeight,
            headerLeadingInset: headerLeadingInset(sidebarOrigin: ChromeMetrics.gutter),
            acceptsProfileSwipes: showsFloatingSidebar,
            popoverColorScheme: systemColorScheme
        )
        .environment(\.colorScheme, .light)
        .frame(width: sidebarWidth)
        .frame(maxHeight: .infinity)
        .background { ChromeAmbientBackground() }
        // Clip the header backing too, not just the surface behind it.
        .clipShape(RoundedRectangle(cornerRadius: ChromeRadius.tab, style: .continuous))
        .chromeShadow(.floating)
        .padding(ChromeMetrics.gutter)
        .chromeSlide(
            isShown: showsFloatingSidebar,
            from: CGSize(width: -(sidebarWidth + ChromeMetrics.gutter * 4), height: 0)
        )
    }

    // MARK: - Content Card

    private var contentCard: some View {
        VStack(spacing: 0) {
            navigationBar

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay { ToastOverlay(center: tabManager.toasts) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .chromeCard()
    }

    /// Navigation stays with the page in every tab layout, including while
    /// the sidebar is hidden. The sidebar toggle is always within reach.
    private var navigationBar: some View {
        NavigationBar(
            session: activeTab,
            tabManager: tabManager,
            presentsSiteControls: true
        )
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

    private var isSidebarHideable: Bool {
        tabManager.tabLayout == .sidebar && tabManager.hideTabs
    }

    // One stable hover region covers the edge and the revealed tabs. There is
    // no gap between tracking areas, delayed task, or stale hide callback.
    private func trackPointer(_ phase: HoverPhase) {
        guard tabManager.hideTabs else { return }
        switch phase {
        case .active(let point):
            let extent = areTabsVisible
                ? (isTopMode ? ChromeMetrics.titlebarHeight : sidebarWidth + ChromeMetrics.gutter * 2)
                : (isTopMode ? ChromeMetrics.revealEdge : ChromeMetrics.sidebarRevealWidth)
            isPointerOverTabs = (isTopMode ? point.y : point.x) <= extent
        case .ended:
            isPointerOverTabs = false
        }
        if isPointerOverTabs {
            if !areTabsVisible { areTabsVisible = true }
        } else {
            hideIfOutside()
        }
    }

    private func hideIfOutside() {
        guard tabManager.hideTabs, areTabsVisible, !isPointerOverTabs,
              !tabManager.isShowingSiteControls, !tabManager.library.isPresented,
              !tabManager.library.downloadsPresented,
              tabManager.profileToEdit == nil else { return }
        areTabsVisible = false
    }

}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
