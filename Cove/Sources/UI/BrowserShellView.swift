import SwiftUI

struct BrowserShellView<Content: View>: View {
    @ObservedObject var tabManager: TabManager
    @ObservedObject var activeTab: Tab
    let content: Content

    @ObservedObject private var settings = BrowserSettingsStore.shared
    @Environment(\.titlebarHeight) private var titlebarHeight
    @State private var isHoveringChrome = false
    @State private var chromeHideTask: Task<Void, Never>?

    init(
        tabManager: TabManager,
        activeTab: Tab,
        @ViewBuilder content: () -> Content
    ) {
        self._tabManager = ObservedObject(wrappedValue: tabManager)
        self._activeTab = ObservedObject(wrappedValue: activeTab)
        self.content = content()
    }

    // MARK: - Body

    var body: some View {
        shell
            .overlay(alignment: .topLeading) {
                TrafficLightsView(isVisible: stripVisible)
                    .padding(.leading, ChromeMetrics.shellControlsLeadingInset)
                    .padding(.top, max(0, (titlebarHeight - 12) / 2))
                    .allowsHitTesting(stripVisible)
            }
            .overlay(alignment: .top) {
                if isHorizontalImmersive {
                    topRevealArea
                }
            }
            .overlay(alignment: .leading) {
                if isSidebarImmersive {
                    sidebarRevealArea
                }
            }
            .background {
                TitlebarTabStripAccessory(
                    tabManager: tabManager,
                    isVisible: showsTopStrip
                )
            }
    }

    // MARK: - Shell (Two Layers: Dark Frame + Light Panel)

    private var shell: some View {
        HStack(spacing: 0) {
            SidebarTabView(tabManager: tabManager)
                .frame(width: showsSidebar ? ChromeMetrics.sidebarWidth : 0)
                .clipped()
                .colorScheme(.dark)
                .onHover(perform: handleChromeHover)

            VStack(spacing: 0) {
                topChromeZone
                contentPanel
            }
        }
        .padding(.horizontal, ChromeMetrics.shellGutter)
        .padding(.bottom, ChromeMetrics.shellGutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .chromePanelSurface(
            .browserShell,
            cornerRadius: ChromeMetrics.windowCornerRadius,
            borderWidth: ChromeMetrics.windowBorderWidth
        )
    }

    // MARK: - Top Chrome Zone

    private var topChromeZone: some View {
        ZStack(alignment: .leading) {
            if showsTopStrip {
                Color.clear
                    .frame(
                        maxWidth: .infinity,
                        minHeight: ChromeMetrics.topStripLaneHeight,
                        maxHeight: ChromeMetrics.topStripLaneHeight
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(
            maxWidth: .infinity,
            minHeight: topSlotHeight,
            maxHeight: topSlotHeight,
            alignment: .center
        )
        .contentShape(Rectangle())
        .colorScheme(.dark)
        .onHover(perform: handleChromeHover)
    }

    private var topSlotHeight: CGFloat {
        switch tabManager.tabLayout {
        case .horizontal:
            return isHorizontalImmersive ? ChromeMetrics.shellGutter : ChromeMetrics.topBandHeight
        case .sidebar:
            return ChromeMetrics.shellGutter
        }
    }

    // MARK: - Shared Content Panel

    private var sidebarTitlebarClearance: CGFloat {
        max(0, titlebarHeight - ChromeMetrics.shellGutter - ChromeMetrics.topNavigationVerticalPadding)
    }

    private var contentPanel: some View {
        VStack(spacing: ChromeMetrics.mainPanelSectionSpacing) {
            NavigationBar(
                viewModel: activeTab.viewModel,
                onNavigate: { _ in activeTab.isNewTabPage = false }
            )
            .id(activeTab.id)
            .padding(.horizontal, ChromeMetrics.topNavigationHorizontalPadding)
            .padding(.vertical, ChromeMetrics.topNavigationVerticalPadding)
            .padding(.top, tabManager.tabLayout == .sidebar ? sidebarTitlebarClearance : 0)
            .contentShape(Rectangle())
            .onHover(perform: handleChromeHover)

            Rectangle()
                .fill(ChromePalette.chromeStroke)
                .frame(height: ChromeMetrics.mainPanelSeparatorHeight)

            ZStack(alignment: .top) {
                content
                contentLoadingIndicator
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .chromePanelSurface(.window, cornerRadius: ChromeMetrics.panelCornerRadius)
    }

    @ViewBuilder
    private var contentLoadingIndicator: some View {
        if activeTab.viewModel.isLoading {
            ProgressView(value: activeTab.viewModel.estimatedProgress)
                .progressViewStyle(.linear)
                .tint(.accentColor)
                .labelsHidden()
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Immersive Reveal

    private var topRevealArea: some View {
        Color.clear
            .frame(height: 12)
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    chromeHideTask?.cancel()
                    tabManager.revealTabs()
                }
            }
    }

    private var sidebarRevealArea: some View {
        Color.clear
            .frame(width: 12)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    chromeHideTask?.cancel()
                    tabManager.revealTabs()
                }
            }
    }

    // MARK: - Chrome Visibility

    private var stripVisible: Bool {
        !settings.hideTabs || tabManager.areTabsVisible
    }

    var showsTopStrip: Bool {
        tabManager.tabLayout == .horizontal && (!settings.hideTabs || tabManager.areTabsVisible)
    }

    private var showsSidebar: Bool {
        tabManager.tabLayout == .sidebar && (!settings.hideTabs || tabManager.areTabsVisible)
    }

    private var isHorizontalImmersive: Bool {
        tabManager.tabLayout == .horizontal && settings.hideTabs && !tabManager.areTabsVisible
    }

    private var isSidebarImmersive: Bool {
        tabManager.tabLayout == .sidebar && settings.hideTabs && !tabManager.areTabsVisible
    }

    // MARK: - Unified Hide/Reveal

    private func handleChromeHover(_ hovering: Bool) {
        isHoveringChrome = hovering
        chromeHideTask?.cancel()

        guard settings.hideTabs else {
            tabManager.areTabsVisible = true
            return
        }

        if !hovering {
            chromeHideTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled,
                      !isHoveringChrome,
                      settings.hideTabs else { return }
                tabManager.hideTabsIfNeeded()
            }
        }
    }
}
