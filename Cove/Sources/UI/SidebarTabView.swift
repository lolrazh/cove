import SwiftUI

enum SidebarTabPresentation: Equatable {
    case overlay
    case integrated
}

struct SidebarTabView: View {
    @ObservedObject var tabManager: TabManager
    var presentation: SidebarTabPresentation = .overlay
    @ObservedObject private var settings = BrowserSettingsStore.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isHoveringSidebar = false
    @State private var hideTask: Task<Void, Never>?

    private var tabOrder: [UUID] {
        tabManager.tabs.map(\.id)
    }

    private var tabReorderAnimation: Animation? {
        reduceMotion ? nil : .snappy(duration: 0.16, extraBounce: 0.02)
    }

    private var showsOverlayContent: Bool {
        tabManager.areTabsVisible || !settings.hideTabs
    }

    @ViewBuilder
    var body: some View {
        if presentation == .integrated {
            integratedSidebarContent
        } else {
            overlaySidebar
        }
    }

    private var overlaySidebar: some View {
        ZStack(alignment: .leading) {
            if showsOverlayContent {
                overlaySidebarContent
                    .padding(.leading, 10)
                    .padding(.vertical, 10)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            } else if settings.hideTabs {
                revealHandle
                    .padding(.leading, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var overlaySidebarContent: some View {
        VStack(spacing: 0) {
            overlayHeader
            sidebarTabList
            Spacer()
        }
        .frame(width: ChromeMetrics.sidebarWidth)
        .chromePanelSurface(.sidebar, cornerRadius: ChromeMetrics.panelCornerRadius, showsShadow: true)
        .onHover { hovering in
            handleSidebarHover(hovering)
        }
    }

    private var integratedSidebarContent: some View {
        VStack(spacing: 0) {
            integratedHeader
            sidebarTabList
            Spacer(minLength: 0)
        }
        .frame(width: ChromeMetrics.sidebarWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .background {
            VisualEffectMaterialBackground(material: .sidebar, blendingMode: .withinWindow)
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(ChromePalette.chromeStroke)
                .frame(width: ChromeMetrics.mainPanelSeparatorHeight)
        }
    }

    private var overlayHeader: some View {
        HStack {
            Spacer()

            DownloadsStatusButton()
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var integratedHeader: some View {
        HStack {
            Spacer()

            DownloadsStatusButton()
        }
        .padding(.horizontal, 12)
        .frame(height: ChromeMetrics.shellStripHeight + 18, alignment: .bottom)
        .padding(.bottom, 8)
    }

    private var sidebarTabList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 4) {
                ForEach(tabManager.tabs) { tab in
                    ChromeTabItem(
                        tab: tab,
                        presentation: .sidebar,
                        isActive: tab.id == tabManager.activeTabID,
                        onSelect: { tabManager.selectTab(tab.id) },
                        onClose: { tabManager.closeTab(tab.id) },
                        canClose: tabManager.tabs.count > 1
                    )
                }

                SidebarNewTabItem {
                    tabManager.addTab()
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
            .animation(tabReorderAnimation, value: tabOrder)
        }
    }

    private var revealHandle: some View {
        VStack {
            Spacer()

            Capsule()
                .fill(ChromePalette.handleFill)
                .frame(width: 4, height: 48)
                .padding(.horizontal, 4)

            Spacer()
        }
        .frame(width: ChromeMetrics.sidebarRevealHandleWidth)
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering {
                revealSidebar()
            }
        }
    }

    private func handleSidebarHover(_ hovering: Bool) {
        isHoveringSidebar = hovering
        hideTask?.cancel()

        guard settings.hideTabs else {
            tabManager.areTabsVisible = true
            return
        }

        if hovering {
            tabManager.areTabsVisible = true
        } else {
            hideTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(750))
                guard !Task.isCancelled,
                      !isHoveringSidebar,
                      tabManager.tabLayout == .sidebar,
                      settings.hideTabs else { return }

                tabManager.hideTabsIfNeeded()
            }
        }
    }

    private func revealSidebar() {
        hideTask?.cancel()
        tabManager.revealTabs()
    }
}

private struct SidebarNewTabItem: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: ChromeSymbols.Tabs.add)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 14, height: 14)

            Text("New Tab")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .chromeInteractiveSurface(cornerRadius: ChromeMetrics.tabCornerRadius, showsBorder: isHovered)
        .onHover { isHovered = $0 }
        .onTapGesture(perform: action)
    }
}
