import SwiftUI

enum ChromeTabPresentation {
    case horizontal
    case sidebar
}

/// One tab, in the top strip or in the sidebar. Everything about a tab is shared
/// between the two; a presentation only decides the tab's height and how the
/// active tab is drawn.
struct ChromeTabItem: View {
    @ObservedObject var tab: TabSession
    let presentation: ChromeTabPresentation
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let canClose: Bool
    /// Fixed width for top tabs, which share the strip evenly. Sidebar tabs fill.
    var width: CGFloat? = nil

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            FaviconView(image: tab.favicon, size: 16)

            Text(title)
                .font(.callout)
                .foregroundStyle(isActive || isHovered ? .primary : .secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            closeButton
        }
        .padding(.leading, 8)
        .padding(.trailing, 4)
        .frame(width: width, height: height)
        .frame(maxWidth: presentation == .sidebar ? .infinity : nil)
        .background { background }
        .contentShape(Rectangle())
        .animation(ChromeMotion.hover, value: isHovered)
        .onHover { isHovered = $0 }
        .onTapGesture(perform: onSelect)
    }

    private var closeButton: some View {
        let isVisible = canClose && isHovered

        return Button(action: onClose) {
            Image(systemName: ChromeSymbols.Tabs.close)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(ChromeButtonStyle(size: .accessory()))
        .help("Close Tab")
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(isVisible)
        .animation(ChromeMotion.hover, value: isVisible)
    }

    /// The active tab is drawn in the page's color: it *is* the page you're
    /// looking at. In the top strip it also reaches down into the content card,
    /// so tab and page read as one surface. Others only show a fill on hover.
    @ViewBuilder
    private var background: some View {
        if isActive {
            switch presentation {
            case .sidebar:
                shape
                    .fill(ChromePalette.content)
                    .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
            case .horizontal:
                AttachedTabShape()
                    .fill(ChromePalette.content)
                    .padding(.horizontal, -ChromeRadius.flare)
                    .padding(.bottom, -ChromeMetrics.tabBottomInset)
            }
        } else if isHovered {
            shape.fill(ChromePalette.hover)
        }
    }

    private var shape: ConcentricRectangle {
        .chrome(minimum: ChromeRadius.tab)
    }

    private var height: CGFloat {
        switch presentation {
        case .horizontal: ChromeMetrics.tabHeight
        case .sidebar: ChromeMetrics.sidebarRowHeight
        }
    }

    private var title: String {
        tab.pageTitle.isEmpty ? "New Tab" : tab.pageTitle
    }
}
