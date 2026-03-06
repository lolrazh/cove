import SwiftUI

private enum TopShellMode {
    case regular
    case immersive
}

struct TopBrowserShellView<Content: View>: View {
    @ObservedObject var tabManager: TabManager
    @ObservedObject var activeTab: Tab
    let content: Content

    @ObservedObject private var settings = BrowserSettingsStore.shared
    @State private var isHoveringTopChrome = false
    @State private var topTabsHideTask: Task<Void, Never>?

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
            .overlay(alignment: .top) {
                if showsTopRevealArea {
                    topTabsRevealArea
                }
            }
    }

    private var shellLayout: some View {
        VStack(spacing: 0) {
            topSlot
            mainPanel
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

    private var topSlot: some View {
        ZStack(alignment: .leading) {
            if showsTopStrip {
                HStack(spacing: 0) {
                    Color.clear
                        .frame(width: ChromeMetrics.shellControlsReservedWidth)

                    TabStripView(tabManager: tabManager)
                }
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
        .onHover(perform: handleTopChromeHover)
    }

    private var mainPanel: some View {
        panelContent
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

    private var shellMode: TopShellMode {
        settings.hideTabs && !tabManager.areTabsVisible ? .immersive : .regular
    }

    private var showsTopStrip: Bool {
        shellMode == .regular
    }

    private var showsTopRevealArea: Bool {
        shellMode == .immersive
    }

    private var topSlotHeight: CGFloat {
        showsTopStrip ? ChromeMetrics.topBandHeight : ChromeMetrics.shellGutter
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

    private func handleTopChromeHover(_ hovering: Bool) {
        isHoveringTopChrome = hovering
        topTabsHideTask?.cancel()

        guard settings.hideTabs else {
            tabManager.areTabsVisible = true
            return
        }

        if !hovering {
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

    private var panelContent: some View {
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
                content
                contentLoadingIndicator
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
