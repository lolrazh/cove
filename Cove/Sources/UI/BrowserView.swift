import SwiftUI

struct BrowserView: View {
    @StateObject private var tabManager = TabManager()
    @ObservedObject private var settings = BrowserSettingsStore.shared
    @State private var isHoveringTopChrome = false
    @State private var topTabsHideTask: Task<Void, Never>?

    var body: some View {
        Group {
            if let activeTab = tabManager.activeTab {
                chromeShell(for: activeTab)
            }
        }
        .animation(ChromeMotion.shell, value: tabManager.tabLayout)
        .background(ChromePalette.window)
        .background {
            WindowChromeAccessor(
                controlsStyle: windowChromeControlsStyle
            )
            .allowsHitTesting(false)
        }
        .frame(minWidth: 900, minHeight: 640)
        .focusedSceneValue(\.browserCommandContext, browserCommandContext)
    }

    @ViewBuilder
    private func chromeShell(for activeTab: Tab) -> some View {
        if tabManager.tabLayout == .horizontal {
            horizontalShell(for: activeTab)
        } else {
            sidebarShell(for: activeTab)
        }
    }

    private func horizontalShell(for activeTab: Tab) -> some View {
        VStack(spacing: 0) {
            if showsTopStrip {
                diaTopStrip
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            horizontalContentColumn(for: activeTab)
        }
        .padding(ChromeMetrics.windowInset)
        .chromeWindowSurface()
        .overlay(alignment: .top) {
            if showsTopRevealArea {
                topTabsRevealArea
            }
        }
    }

    private func sidebarShell(for activeTab: Tab) -> some View {
        HStack(spacing: ChromeMetrics.shellStripBottomSpacing) {
            if showsIntegratedSidebarRail {
                SidebarTabView(
                    tabManager: tabManager,
                    presentation: .integrated
                )
            }

            sidebarMainPanel(for: activeTab)
        }
        .padding(ChromeMetrics.windowInset)
        .chromeWindowSurface()
    }

    private var diaTopStrip: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: ChromeMetrics.shellControlsReservedWidth)

            TabStripView(tabManager: tabManager)
        }
        .frame(maxWidth: .infinity, minHeight: ChromeMetrics.shellStripHeight, maxHeight: ChromeMetrics.shellStripHeight)
        .padding(.trailing, ChromeMetrics.shellStripTrailingPadding)
        .background(ChromePalette.topStripFill)
        .colorScheme(.dark)
        .contentShape(Rectangle())
        .onHover(perform: handleTopChromeHover)
    }

    private func horizontalContentColumn(for activeTab: Tab) -> some View {
        VStack(spacing: ChromeMetrics.mainPanelSectionSpacing) {
            NavigationBar(
                viewModel: activeTab.viewModel,
                onNavigate: { _ in
                    activeTab.isNewTabPage = false
                }
            )
            .id(activeTab.id)
            .padding(.horizontal, ChromeMetrics.topNavigationHorizontalPadding)
            .padding(.vertical, ChromeMetrics.topNavigationVerticalPadding)
            .contentShape(Rectangle())
            .onHover(perform: handleTopChromeHover)

            Rectangle()
                .fill(ChromePalette.chromeStroke)
                .frame(height: ChromeMetrics.mainPanelSeparatorHeight)

            ZStack(alignment: .top) {
                activeTabContent
                contentLoadingIndicator(for: activeTab)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ChromePalette.window)
    }

    private func sidebarMainPanel(for activeTab: Tab) -> some View {
        ZStack(alignment: .leading) {
            VStack(spacing: ChromeMetrics.mainPanelSectionSpacing) {
                NavigationBar(
                    viewModel: activeTab.viewModel,
                    onNavigate: { _ in
                        activeTab.isNewTabPage = false
                    }
                )
                .id(activeTab.id)
                .padding(ChromeMetrics.mainPanelInnerPadding)

                Rectangle()
                    .fill(ChromePalette.chromeStroke)
                    .frame(height: ChromeMetrics.mainPanelSeparatorHeight)

                ZStack(alignment: .top) {
                    activeTabContent
                    contentLoadingIndicator(for: activeTab)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showsOverlaySidebarRail {
                SidebarTabView(tabManager: tabManager)
                    .zIndex(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .chromePanelSurface(.window, cornerRadius: ChromeMetrics.panelCornerRadius)
    }

    @ViewBuilder
    private func contentLoadingIndicator(for activeTab: Tab) -> some View {
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

    @ViewBuilder
    private var activeTabContent: some View {
        if !tabManager.tabs.isEmpty {
            ZStack {
                ForEach(tabManager.tabs) { tab in
                    ActiveTabView(tab: tab)
                        .opacity(tab.id == tabManager.activeTabID ? 1 : 0)
                        .allowsHitTesting(tab.id == tabManager.activeTabID)
                        .accessibilityHidden(tab.id != tabManager.activeTabID)
                        .zIndex(tab.id == tabManager.activeTabID ? 1 : 0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transaction { transaction in
                transaction.animation = nil
            }
        }
    }

    private var showsTopRevealArea: Bool {
        tabManager.tabLayout == .horizontal && settings.hideTabs && !tabManager.areTabsVisible
    }

    private var showsTopStrip: Bool {
        tabManager.tabLayout == .horizontal && tabManager.areTabsVisible
    }

    private var showsIntegratedSidebarRail: Bool {
        tabManager.tabLayout == .sidebar && !settings.hideTabs
    }

    private var showsOverlaySidebarRail: Bool {
        tabManager.tabLayout == .sidebar && settings.hideTabs
    }

    private var topTabsRevealArea: some View {
        Color.clear
            .frame(height: 12)
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    topTabsHideTask?.cancel()
                    tabManager.revealTabs()
                }
            }
    }

    private var browserCommandContext: BrowserCommandContext {
        BrowserCommandContext(
            showsTabsInSidebar: tabManager.tabLayout == .sidebar,
            hidesTabs: settings.hideTabs,
            setShowsTabsInSidebar: { showsTabsInSidebar in
                withAnimation(ChromeMotion.shell) {
                    tabManager.setLayout(showsTabsInSidebar ? .sidebar : .horizontal)
                }
            },
            setHidesTabs: { hidesTabs in
                withAnimation(ChromeMotion.shell) {
                    settings.setHideTabs(hidesTabs)
                }
            }
        )
    }

    private var windowChromeControlsStyle: WindowChromeControlsStyle {
        WindowChromeControlsStyle(
            leadingInset: ChromeMetrics.shellControlsLeadingInset,
            interButtonSpacing: ChromeMetrics.shellControlsInterButtonSpacing,
            verticalOffset: ChromeMetrics.shellControlsVerticalOffset,
            isVisible: !hidesTopChromeControls
        )
    }

    private var hidesTopChromeControls: Bool {
        tabManager.tabLayout == .horizontal && settings.hideTabs && !tabManager.areTabsVisible
    }

    private func handleTopChromeHover(_ hovering: Bool) {
        guard tabManager.tabLayout == .horizontal else { return }

        isHoveringTopChrome = hovering
        topTabsHideTask?.cancel()

        guard settings.hideTabs else {
            tabManager.areTabsVisible = true
            return
        }

        if hovering {
            guard tabManager.areTabsVisible else { return }
        } else {
            topTabsHideTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled,
                      !isHoveringTopChrome,
                      tabManager.tabLayout == .horizontal,
                      settings.hideTabs else { return }

                tabManager.hideTabsIfNeeded()
            }
        }
    }
}

struct ActiveTabView: View {
    @ObservedObject var tab: Tab

    var body: some View {
        Group {
            if tab.isNewTabPage {
                NewTabPage { input in
                    tab.isNewTabPage = false
                    tab.viewModel.loadURL(input)
                }
            } else {
                WebViewRepresentable(webView: tab.viewModel.webView)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
