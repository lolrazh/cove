import SwiftUI

struct BrowserShellView<Content: View>: View {
    @ObservedObject var tabManager: TabManager
    @ObservedObject var activeTab: Tab
    let content: Content

    @ObservedObject private var settings = BrowserSettingsStore.shared
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

    var body: some View {
        shellLayout
            .background {
                if tabManager.tabLayout == .horizontal {
                    TitlebarTabStripAccessory(
                        tabManager: tabManager,
                        isVisible: showsChromeStrip
                    )
                }
            }
    }

    // MARK: - Shell Layout

    @ViewBuilder
    private var shellLayout: some View {
        switch tabManager.tabLayout {
        case .horizontal:
            horizontalShell
        case .sidebar:
            verticalShell
        }
    }

    // MARK: - Horizontal Shell (Top Tabs)

    private var horizontalShell: some View {
        VStack(spacing: 0) {
            topChromeSlot
            contentPanel
        }
        .padding(.horizontal, ChromeMetrics.shellGutter)
        .padding(.bottom, ChromeMetrics.shellGutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .chromePanelSurface(
            .browserShell,
            cornerRadius: ChromeMetrics.windowCornerRadius,
            borderWidth: ChromeMetrics.windowBorderWidth
        )
        .overlay(alignment: .top) {
            if isHorizontalImmersive {
                topRevealArea
            }
        }
    }

    private var topChromeSlot: some View {
        ZStack(alignment: .leading) {
            if showsChromeStrip {
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
        showsChromeStrip ? ChromeMetrics.topBandHeight : ChromeMetrics.shellGutter
    }

    private var isHorizontalImmersive: Bool {
        settings.hideTabs && !tabManager.areTabsVisible
    }

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

    // MARK: - Vertical Shell (Sidebar Tabs)

    private var verticalShell: some View {
        HStack(spacing: ChromeMetrics.shellGutter) {
            if showsIntegratedSidebar {
                SidebarTabView(tabManager: tabManager, presentation: .integrated)
            }
            contentPanel
        }
        .padding(ChromeMetrics.shellGutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .chromePanelSurface(
            .browserShell,
            cornerRadius: ChromeMetrics.windowCornerRadius,
            borderWidth: ChromeMetrics.windowBorderWidth
        )
        .overlay(alignment: .leading) {
            if showsOverlaySidebar {
                SidebarTabView(tabManager: tabManager)
                    .zIndex(1)
            }
        }
    }

    private var showsIntegratedSidebar: Bool {
        tabManager.tabLayout == .sidebar && !settings.hideTabs
    }

    private var showsOverlaySidebar: Bool {
        tabManager.tabLayout == .sidebar && settings.hideTabs
    }

    // MARK: - Shared Content Panel

    private var contentPanel: some View {
        VStack(spacing: ChromeMetrics.mainPanelSectionSpacing) {
            NavigationBar(
                viewModel: activeTab.viewModel,
                onNavigate: { _ in activeTab.isNewTabPage = false }
            )
            .id(activeTab.id)
            .padding(.horizontal, ChromeMetrics.topNavigationHorizontalPadding)
            .padding(.vertical, ChromeMetrics.topNavigationVerticalPadding)
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

    // MARK: - Chrome Visibility

    var showsChromeStrip: Bool {
        !settings.hideTabs || tabManager.areTabsVisible
    }

    // MARK: - Unified Hide/Reveal

    private func handleChromeHover(_ hovering: Bool) {
        guard tabManager.tabLayout == .horizontal else { return }

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
