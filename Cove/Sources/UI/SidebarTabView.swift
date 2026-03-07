import SwiftUI

struct SidebarTabView: View {
    @ObservedObject var tabManager: TabManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var tabOrder: [UUID] {
        tabManager.tabs.map(\.id)
    }

    private var tabReorderAnimation: Animation? {
        reduceMotion ? nil : .snappy(duration: 0.16, extraBounce: 0.02)
    }

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader
            sidebarTabList
            Spacer(minLength: 0)
        }
        .frame(width: ChromeMetrics.sidebarWidth)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var sidebarHeader: some View {
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
