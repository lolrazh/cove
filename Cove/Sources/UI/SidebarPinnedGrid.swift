import SwiftUI

/// Top-level pins fill balanced rows. Folder contents keep their named rows.
struct SidebarPinnedGrid: View {
    @Environment(\.sidebarSelection) private var selection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var direction
    let tabs: [TabSession]
    @ObservedObject var tabManager: TabManager

    var body: some View {
        PinnedTileLayout(rightToLeft: direction == .rightToLeft) {
            ForEach(tabs) { tab in
                SidebarPinnedTile(tab: tab, tabManager: tabManager, isActive: selection == tab.id)
                    .reorderableTab(tab.id, in: tabManager, dragging: $tabManager.draggedTabID)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: tabs.map(\.id))
    }
}

private struct SidebarPinnedTile: View {
    @ObservedObject var tab: TabSession
    let tabManager: TabManager
    let isActive: Bool
    @State private var isRenaming = false
    @State private var draftTitle = ""

    var body: some View {
        Button { tabManager.selectTab(tab.id) } label: {
            FaviconView(image: tab.favicon, size: 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    if isActive {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(ChromePalette.raised)
                    }
                }
                .chromeHoverSurface(restingFill: !isActive, minimumRadius: 10)
                .contentShape(.rect(cornerRadius: 10))
                .geometryGroup()
        }
        .buttonStyle(.plain)
        .opacity(tab.isAsleep ? 0.7 : 1)
        .help(tab.title)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isActive ? .isSelected : [])
        .contextMenu {
            TabActions(tab: tab, tabManager: tabManager, placement: .tab(rename: {
                draftTitle = tab.title
                isRenaming = true
            }))
        }
        .alert("Rename Tab", isPresented: $isRenaming) {
            TextField("Tab Name", text: $draftTitle)
            Button("Cancel", role: .cancel) {}
            Button("Save") { tab.rename(draftTitle) }
        }
    }
}

/// One flat set of children keeps each tile's identity when it changes rows.
/// Nested row stacks would remove and recreate tiles during a 3-to-4 reflow.
struct PinnedTileLayout: Layout {
    var rightToLeft = false
    static let height: CGFloat = 40
    static let gap: CGFloat = 6

    static func rowCounts(for count: Int) -> [Int] {
        guard count > 0 else { return [] }
        let rows = (count + 2) / 3
        return (0..<rows).map { count / rows + ($0 < count % rows ? 1 : 0) }
    }

    static func frames(count: Int, width: CGFloat, rightToLeft: Bool = false) -> [CGRect] {
        rowCounts(for: count).enumerated().flatMap { row, columns in
            let gap = min(Self.gap, max(0, width) / CGFloat(columns))
            let tileWidth = max(0, (width - gap * CGFloat(columns - 1)) / CGFloat(columns))
            return (0..<columns).map { column in
                let position = rightToLeft ? columns - column - 1 : column
                return CGRect(x: CGFloat(position) * (tileWidth + gap),
                              y: CGFloat(row) * (height + Self.gap),
                              width: tileWidth, height: height)
            }
        }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = Self.rowCounts(for: subviews.count).count
        return CGSize(width: proposal.width ?? 204,
                      height: CGFloat(rows) * Self.height + CGFloat(max(0, rows - 1)) * Self.gap)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = Self.frames(count: subviews.count, width: bounds.width, rightToLeft: rightToLeft)
        for (subview, frame) in zip(subviews, frames) {
            subview.place(at: CGPoint(x: bounds.minX + frame.midX, y: bounds.minY + frame.midY),
                          anchor: .center, proposal: ProposedViewSize(frame.size))
        }
    }
}
