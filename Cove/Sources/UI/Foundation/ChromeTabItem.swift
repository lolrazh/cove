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
    let tabManager: TabManager
    let presentation: ChromeTabPresentation
    let isActive: Bool
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

            // Close together, so narrow top tabs keep room for the title.
            HStack(spacing: 0) {
                audioButton
                closeButton
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, ChromeMetrics.tabAccessoryInset)
        .frame(width: width, height: height)
        .frame(maxWidth: presentation == .sidebar ? .infinity : nil)
        // Makes the close button's ConcentricRectangle follow this tab's corners.
        .containerShape(RoundedRectangle(cornerRadius: ChromeRadius.tab, style: .continuous))
        .background { background }
        .contentShape(Rectangle())
        .animation(ChromeMotion.hover, value: isHovered)
        .animation(ChromeMotion.hover, value: showsAudioButton)
        .onHover { isHovered = $0 }
        .onTapGesture { tabManager.selectTab(tab.id) }
    }

    /// Shows while the page plays sound, and while it's muted so it can be
    /// unmuted. Clicking it toggles.
    @ViewBuilder
    private var audioButton: some View {
        if showsAudioButton {
            Button(action: tab.toggleMuted) {
                Image(systemName: tab.isMuted ? ChromeSymbols.Tabs.muted : ChromeSymbols.Tabs.playingAudio)
                    .foregroundStyle(.secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(accessoryStyle)
            .help(tab.isMuted ? "Unmute Tab" : "Mute Tab")
            .transition(.opacity)
        }
    }

    private var closeButton: some View {
        let isVisible = canClose && isHovered

        return Button { tabManager.closeTab(tab.id) } label: {
            Image(systemName: ChromeSymbols.Tabs.close)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(accessoryStyle)
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
                    .fill(ChromePalette.raised)
                    .chromeShadow(.raised)
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

    private var showsAudioButton: Bool {
        tab.isPlayingAudio || tab.isMuted
    }

    private var accessoryStyle: ChromeButtonStyle {
        ChromeButtonStyle(size: .accessory(side: height - ChromeMetrics.tabAccessoryInset * 2))
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
