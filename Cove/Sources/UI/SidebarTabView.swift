import SwiftUI

struct SidebarTabView: View {
    @ObservedObject var tabManager: TabManager
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

    private var showsOverlay: Bool {
        !settings.hideTabs || tabManager.isSidebarVisible
    }

    var body: some View {
        ZStack(alignment: .leading) {
            if showsOverlay {
                sidebarContent
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

    private var sidebarContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Tabs")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Button(action: { tabManager.addTab() }) {
                    Image(systemName: ChromeSymbols.Tabs.add)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(ChromeButtonStyle(kind: .toolbar))
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

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
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
                .animation(tabReorderAnimation, value: tabOrder)
            }

            Spacer()
        }
        .frame(width: ChromeMetrics.sidebarWidth)
        .chromePanelSurface(.sidebar, cornerRadius: ChromeMetrics.panelCornerRadius, showsShadow: true)
        .onHover { hovering in
            handleSidebarHover(hovering)
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
            tabManager.isSidebarVisible = true
            return
        }

        if hovering {
            tabManager.isSidebarVisible = true
        } else {
            hideTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(750))
                guard !Task.isCancelled,
                      !isHoveringSidebar,
                      tabManager.tabLayout == .sidebar,
                      settings.hideTabs else { return }

                withAnimation(ChromeMotion.shell) {
                    tabManager.isSidebarVisible = false
                }
            }
        }
    }

    private func revealSidebar() {
        hideTask?.cancel()
        withAnimation(ChromeMotion.shell) {
            tabManager.isSidebarVisible = true
        }
    }
}
