import SwiftUI

struct SidebarTabView: View {
    @ObservedObject var tabManager: TabManager
    @ObservedObject var activeTab: TabSession
    /// Height of the row that holds the traffic lights. Set so the row's center
    /// lands on the traffic lights' centerline wherever the sidebar is placed.
    let headerHeight: CGFloat
    /// Where the header's controls start: just past the traffic lights.
    let headerLeadingInset: CGFloat
    /// Whether this sidebar's address pill is the one Command-L reaches.
    let acceptsFocusRequests: Bool
    @Binding var isEditingAddress: Bool
    let onToggleDocked: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var tabOrder: [UUID] {
        tabManager.tabs.map(\.id)
    }

    private var tabReorderAnimation: Animation? {
        reduceMotion ? nil : .snappy(duration: 0.16, extraBounce: 0.02)
    }

    /// The header floats over the top of the scroll view instead of sitting in a
    /// row above it. macOS extends a scroll view up under the titlebar, and a row
    /// above it would sit behind that extension and never get clicks.
    var body: some View {
        tabList
            .contentMargins(.top, headerHeight + ChromeMetrics.sidebarRowHeight, for: .scrollContent)
            .scrollEdgeEffectHidden(true, for: .top)
            .overlay(alignment: .top) {
                header
            }
    }

    private var header: some View {
        VStack(spacing: 0) {
            navigationRow

            SidebarAddressPill(
                session: activeTab,
                isEditing: $isEditingAddress,
                acceptsFocusRequests: acceptsFocusRequests
            )
            .id(activeTab.id)
            .padding(.horizontal, ChromeMetrics.sidebarInset)
        }
    }

    /// Arc's header row: traffic lights, the dock toggle, then navigation.
    private var navigationRow: some View {
        HStack(spacing: 4) {
            Button(action: onToggleDocked) {
                Image(systemName: ChromeSymbols.Tabs.sidebarLayout)
            }
            .buttonStyle(ChromeButtonStyle())
            .help(tabManager.hideTabs ? "Keep sidebar open" : "Hide sidebar")

            NavigationControls(session: activeTab)

            Spacer(minLength: 0)
        }
        .padding(.leading, headerLeadingInset)
        .padding(.trailing, ChromeMetrics.sidebarInset)
        .frame(height: headerHeight)
    }

    private var tabList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 2) {
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
            .padding(.horizontal, ChromeMetrics.sidebarInset)
            .padding(.top, ChromeMetrics.gutter)
            .padding(.bottom, ChromeMetrics.sidebarInset)
            .animation(tabReorderAnimation, value: tabOrder)
        }
    }
}

private struct SidebarNewTabItem: View {
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: ChromeSymbols.Tabs.add)
                .frame(width: 16, height: 16)

            Text("New Tab")

            Spacer(minLength: 0)
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .frame(height: ChromeMetrics.sidebarRowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .chromeHoverSurface(minimumRadius: ChromeRadius.tab)
        .onTapGesture(perform: action)
    }
}
