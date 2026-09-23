import SwiftUI

struct SidebarTabView: View {
    @ObservedObject var tabManager: TabManager
    /// Height of the row that holds the traffic lights. Set so the row's center
    /// lands on the traffic lights' centerline wherever the sidebar is placed.
    let headerHeight: CGFloat
    let onToggleDocked: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var tabOrder: [UUID] {
        tabManager.tabs.map(\.id)
    }

    private var tabReorderAnimation: Animation? {
        reduceMotion ? nil : .snappy(duration: 0.16, extraBounce: 0.02)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            tabList
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    /// The traffic lights sit on the leading side of this row; it only draws the
    /// dock toggle on the trailing side.
    private var header: some View {
        HStack {
            Spacer()

            Button(action: onToggleDocked) {
                Image(systemName: ChromeSymbols.Tabs.sidebarLayout)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(ChromeButtonStyle())
            .help(tabManager.hideTabs ? "Keep sidebar open" : "Hide sidebar")
        }
        .padding(.horizontal, ChromeMetrics.gutter)
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
                .font(.system(size: 12, weight: .medium))
                .frame(width: 16, height: 16)

            Text("New Tab")
                .font(.system(size: 12))

            Spacer(minLength: 0)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .frame(height: ChromeMetrics.sidebarRowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .chromeHoverSurface()
        .onTapGesture(perform: action)
    }
}
