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
        HStack(spacing: presentation == .horizontal ? 8 : 10) {
            FaviconView(image: tab.favicon, size: 14)

            Text(tabTitle)
                .font(.system(size: presentation == .horizontal ? 11.5 : 12, weight: titleWeight))
                .foregroundStyle(presentation == .horizontal && !isActive ? .secondary : .primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(
                    maxWidth: titleMaxWidth,
                    alignment: .leading
                )

            closeButton
        }
        .padding(.horizontal, presentation == .horizontal ? 10 : 12)
        .padding(.vertical, presentation == .horizontal ? 7 : 8)
        .frame(width: presentation == .horizontal ? horizontalWidth : nil, alignment: .leading)
        .frame(maxWidth: presentation == .sidebar ? .infinity : nil, alignment: .leading)
        .chromeInteractiveSurface(isSelected: isActive, cornerRadius: ChromeMetrics.tabCornerRadius, showsBorder: isActive)
        .onHover { isHovered = $0 }
        .onTapGesture(perform: onSelect)
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: ChromeSymbols.Tabs.close)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(ChromeButtonStyle(kind: .tabAccessory))
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
