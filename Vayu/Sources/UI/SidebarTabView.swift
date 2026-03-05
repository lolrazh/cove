import SwiftUI

struct SidebarTabView: View {
    @ObservedObject var tabManager: TabManager

    @State private var isHoveringSidebar = false

    private let collapsedWidth: CGFloat = 0
    private let expandedWidth: CGFloat = 200

    private var sidebarWidth: CGFloat {
        tabManager.isSidebarVisible ? expandedWidth : collapsedWidth
    }

    var body: some View {
        HStack(spacing: 0) {
            if tabManager.isSidebarVisible {
                sidebarContent
                    .frame(width: expandedWidth)
                    .transition(.move(edge: .leading))
            }

            // Hover edge to reveal sidebar when collapsed
            if !tabManager.isSidebarVisible {
                Color.clear
                    .frame(width: 6)
                    .onHover { hovering in
                        if hovering {
                            withAnimation(.easeOut(duration: 0.2)) {
                                tabManager.isSidebarVisible = true
                            }
                        }
                    }
            }
        }
        .onHover { isHoveringSidebar = $0 }
        .onChange(of: isHoveringSidebar) { _, hovering in
            if !hovering && tabManager.tabLayout == .sidebar {
                // Auto-hide after a delay when mouse leaves
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    if !self.isHoveringSidebar {
                        withAnimation(.easeIn(duration: 0.2)) {
                            tabManager.isSidebarVisible = false
                        }
                    }
                }
            }
        }
    }

    private var sidebarContent: some View {
        VStack(spacing: 0) {
            // Tab list
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 2) {
                    ForEach(tabManager.tabs) { tab in
                        SidebarTabItem(
                            tab: tab,
                            isActive: tab.id == tabManager.activeTabID,
                            onSelect: { tabManager.selectTab(tab.id) },
                            onClose: { tabManager.closeTab(tab.id) },
                            canClose: tabManager.tabs.count > 1
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
            }

            Spacer()

            // Bottom controls
            HStack {
                Button(action: { tabManager.addTab() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Spacer()

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        tabManager.toggleLayout()
                    }
                }) {
                    Image(systemName: "rectangle.topthird.inset.filled")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Switch to horizontal tabs")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(Color.primary.opacity(0.03))
    }
}

struct SidebarTabItem: View {
    @ObservedObject var tab: Tab
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let canClose: Bool

    @State private var isHovering = false

    private var showClose: Bool {
        canClose && (isHovering || isActive)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(tabTitle)
                .font(.system(size: 12, weight: isActive ? .medium : .regular))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(showClose ? 1 : 0)
            .allowsHitTesting(showClose)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive ? Color.primary.opacity(0.08) : (isHovering ? Color.primary.opacity(0.04) : Color.clear))
        )
        .animation(.easeInOut(duration: 0.15), value: isActive)
        .animation(.easeInOut(duration: 0.12), value: isHovering)
        .onHover { isHovering = $0 }
        .onTapGesture(perform: onSelect)
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        ))
    }

    private var tabTitle: String {
        let title = tab.viewModel.pageTitle
        return title.isEmpty ? "New Tab" : title
    }
}
