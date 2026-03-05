import SwiftUI

struct TabStripView: View {
    @ObservedObject var tabManager: TabManager

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(tabManager.tabs) { tab in
                        TabItemView(
                            tab: tab,
                            isActive: tab.id == tabManager.activeTabID,
                            onSelect: { tabManager.selectTab(tab.id) },
                            onClose: { tabManager.closeTab(tab.id) },
                            canClose: tabManager.tabs.count > 1
                        )
                    }
                }
                .padding(.horizontal, 4)
            }

            // New tab button
            Button(action: { tabManager.addTab() }) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(.trailing, 8)
        }
        .frame(height: 36)
        .background(Color.primary.opacity(0.03))
    }
}

struct TabItemView: View {
    @ObservedObject var tab: Tab
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let canClose: Bool

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6) {
            Text(tabTitle)
                .font(.system(size: 11.5, weight: isActive ? .medium : .regular))
                .lineLimit(1)
                .frame(maxWidth: 160, alignment: .leading)

            if canClose && (isHovering || isActive) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive ? Color.primary.opacity(0.08) : Color.clear)
        )
        .onHover { isHovering = $0 }
        .onTapGesture(perform: onSelect)
    }

    private var tabTitle: String {
        let title = tab.viewModel.pageTitle
        return title.isEmpty ? "New Tab" : title
    }
}
