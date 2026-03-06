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
    @State private var titlebarHeight: CGFloat = 0
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
            .padding(.top, -titlebarHeight)
            .background {
                WindowChromeAccessor(
                    controlsStyle: windowChromeControlsStyle,
                    titlebarHeight: $titlebarHeight
                )
                .allowsHitTesting(false)
            }
            .overlay(alignment: .top) {
                if showsTopRevealArea {
                    topTabsRevealArea
                }
            }
    }

    private var shellLayout: some View {
        VStack(spacing: shellMode == .regular ? ChromeMetrics.shellStripBottomSpacing : 0) {
            if showsTopStrip {
                topStrip
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            mainPanel
                .padding(.horizontal, mainPanelInsets.leading)
                .padding(.top, mainPanelInsets.top)
                .padding(.trailing, mainPanelInsets.trailing)
                .padding(.bottom, mainPanelInsets.bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .chromePanelSurface(
            .browserShell,
            cornerRadius: ChromeMetrics.windowCornerRadius,
            borderWidth: ChromeMetrics.windowBorderWidth
        )
    }

    private var topStrip: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: ChromeMetrics.shellControlsReservedWidth)

            TabStripView(tabManager: tabManager)
        }
        .frame(maxWidth: .infinity, minHeight: ChromeMetrics.shellStripHeight, maxHeight: ChromeMetrics.shellStripHeight)
        .padding(.trailing, ChromeMetrics.shellStripTrailingPadding)
        .contentShape(Rectangle())
        .colorScheme(.dark)
        .onHover(perform: handleTopChromeHover)
    }

    private var mainPanel: some View {
        panelContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .modifier(MainPanelSurfaceModifier(isImmersive: shellMode == .immersive))
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

    private var mainPanelInsets: EdgeInsets {
        switch shellMode {
        case .regular:
            return EdgeInsets(
                top: 0,
                leading: ChromeMetrics.topMainPanelInset,
                bottom: ChromeMetrics.topMainPanelInset,
                trailing: ChromeMetrics.topMainPanelInset
            )
        case .immersive:
            return EdgeInsets(
                top: 0,
                leading: 0,
                bottom: 0,
                trailing: 0
            )
        }
    }

    private var windowChromeControlsStyle: WindowChromeControlsStyle {
        WindowChromeControlsStyle(
            leadingInset: ChromeMetrics.shellControlsLeadingInset,
            interButtonSpacing: ChromeMetrics.shellControlsInterButtonSpacing,
            verticalOffset: ChromeMetrics.shellControlsVerticalOffset,
            isVisible: showsTopStrip
        )
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

private struct MainPanelSurfaceModifier: ViewModifier {
    let isImmersive: Bool

    func body(content: Content) -> some View {
        if isImmersive {
            content
                .background(ChromePalette.window)
        } else {
            content
                .chromePanelSurface(.window, cornerRadius: ChromeMetrics.panelCornerRadius)
        }
    }
}
