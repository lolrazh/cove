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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var tab: TabSession
    let tabManager: TabManager
    let isActive: Bool
    @State private var isRenaming = false
    @State private var draftTitle = ""
    @State private var isHovered = false

    var body: some View {
        Button { tabManager.selectTab(tab.id) } label: {
            FaviconView(image: tab.favicon, size: 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    PinnedTileSurface(image: tab.favicon, isActive: isActive)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(ChromePalette.hover)
                        .opacity(isHovered ? 0.35 : 0)
                        .allowsHitTesting(false)
                }
                .contentShape(.rect(cornerRadius: 10))
                .geometryGroup()
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(reduceMotion ? nil : ChromeMotion.hover, value: isHovered)
        .animation(reduceMotion ? nil : ChromeMotion.hover, value: isActive)
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

/// The favicon stays crisp above one shared color field for the fill and rim.
private struct PinnedTileSurface: View {
    let image: NSImage?
    let isActive: Bool
    @State private var colorField: NSImage?

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(ChromePalette.resting)
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .fill(ChromePalette.raised)
                    .opacity(isActive ? 1 : 0)
            }
            .overlay {
                if isActive {
                    if let colorField {
                        Image(nsImage: colorField)
                            .resizable()
                            .interpolation(.high)
                            .opacity(0.40)
                    }
                }
            }
            .clipShape(.rect(cornerRadius: 10))
            .overlay {
                if isActive {
                    let rim = RoundedRectangle(cornerRadius: 10)
                    // Keep the edge readable for monochrome or missing icons.
                    rim.strokeBorder(ChromePalette.onTheme, lineWidth: 2)
                        .opacity(0.24)
                    if let colorField {
                        Image(nsImage: colorField)
                            .resizable()
                            .interpolation(.high)
                            .saturation(1.2)
                            .mask(rim.strokeBorder(lineWidth: 2))
                    }
                }
            }
            .onChange(of: image, initial: true) { _, image in
                colorField = image.flatMap(PinColorField.make)
            }
            .allowsHitTesting(false)
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
