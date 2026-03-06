import SwiftUI

enum ChromeTabPresentation {
    case horizontal
    case sidebar
}

struct ChromeTabItem: View {
    @ObservedObject var tab: Tab
    let presentation: ChromeTabPresentation
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let canClose: Bool

    @State private var isHovered = false

    private var showClose: Bool {
        canClose && (isActive || isHovered)
    }

    var body: some View {
        HStack(spacing: presentation == .horizontal ? 8 : 10) {
            FaviconView(image: tab.viewModel.favicon, size: 14)

            Text(tabTitle)
                .font(.system(size: presentation == .horizontal ? 11.5 : 12, weight: isActive ? .medium : .regular))
                .lineLimit(1)
                .frame(
                    maxWidth: presentation == .horizontal ? 170 : .infinity,
                    alignment: .leading
                )

            closeButton
        }
        .padding(.horizontal, presentation == .horizontal ? 10 : 12)
        .padding(.vertical, presentation == .horizontal ? 7 : 8)
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
        let title = tab.viewModel.pageTitle
        return title.isEmpty ? "New Tab" : title
    }
}
