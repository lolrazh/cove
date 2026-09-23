import SwiftUI

enum ChromeTabPresentation {
    case horizontal
    case sidebar
}

struct ChromeTabItem: View {
    @ObservedObject var tab: TabSession
    let presentation: ChromeTabPresentation
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let canClose: Bool
    var horizontalWidth: CGFloat? = nil

    @State private var isHovered = false

    private var showClose: Bool {
        canClose && (isActive || isHovered)
    }

    var body: some View {
        HStack(spacing: 8) {
            FaviconView(image: tab.favicon, size: 16)

            Text(tabTitle)
                .font(.system(size: 12, weight: titleWeight))
                .foregroundStyle(presentation == .horizontal && !isActive ? .secondary : .primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(
                    maxWidth: titleMaxWidth,
                    alignment: .leading
                )

            closeButton
        }
        .padding(.leading, 10)
        .padding(.trailing, 5)
        .frame(height: presentation == .horizontal ? ChromeMetrics.tabHeight : ChromeMetrics.sidebarRowHeight)
        .frame(width: presentation == .horizontal ? horizontalWidth : nil, alignment: .leading)
        .frame(maxWidth: presentation == .sidebar ? .infinity : nil, alignment: .leading)
        .chromeHoverSurface(isSelected: isActive)
        .onHover { isHovered = $0 }
        .onTapGesture(perform: onSelect)
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: ChromeSymbols.Tabs.close)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(ChromeButtonStyle(size: .accessory))
        .opacity(showClose ? 1 : 0)
        .allowsHitTesting(showClose)
    }

    private var tabTitle: String {
        let title = tab.pageTitle
        return title.isEmpty ? "New Tab" : title
    }

    private var titleWeight: Font.Weight {
        switch presentation {
        case .horizontal:
            return .regular
        case .sidebar:
            return isActive ? .medium : .regular
        }
    }

    private var titleMaxWidth: CGFloat? {
        switch presentation {
        case .horizontal:
            return horizontalWidth == nil ? 170 : .infinity
        case .sidebar:
            return .infinity
        }
    }
}
