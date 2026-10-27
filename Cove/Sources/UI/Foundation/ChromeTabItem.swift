import SwiftUI

enum ChromeTabPresentation {
    case horizontal
    /// A pinned tab or favorite in the top strip: the favicon alone.
    case compact
    case sidebar
}

/// One tab, in the top strip or in the sidebar. Everything about a tab is shared
/// between the two, its context menu and renaming included; a presentation
/// only decides the tab's height and how the active tab is drawn.
struct ChromeTabItem: View {
    @ObservedObject var tab: TabSession
    let tabManager: TabManager
    let presentation: ChromeTabPresentation
    let isActive: Bool
    let canClose: Bool
    /// Fixed width for top tabs, which share the strip evenly. Sidebar tabs fill.
    var width: CGFloat? = nil

    @State private var isHovered = false
    @State private var isRenaming = false
    @State private var draftTitle = ""
    @FocusState private var isTitleFieldFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            if presentation == .compact {
                // The favicon, or the sound control while there's sound.
                if showsAudioButton {
                    audioButton
                } else {
                    FaviconView(image: tab.favicon, size: 16)
                }
            } else {
                FaviconView(image: tab.favicon, size: 16)

                titleView
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Close together, so narrow top tabs keep room for the title.
                HStack(spacing: 0) {
                    backToPinButton
                    audioButton
                    closeButton
                }
            }
        }
        // A sleeping tab fades a little, as in Arc, until hovered: it's still
        // there, it just has to wake.
        .opacity(tab.isAsleep && !isHovered ? Self.asleepOpacity : 1)
        .padding(.leading, presentation == .compact ? 0 : 8)
        .padding(.trailing, presentation == .compact ? 0 : ChromeMetrics.tabAccessoryInset)
        .frame(width: width, height: height)
        .frame(maxWidth: presentation == .sidebar ? .infinity : nil)
        // Makes the close button's ConcentricRectangle follow this tab's corners.
        .containerShape(RoundedRectangle(cornerRadius: ChromeRadius.tab, style: .continuous))
        .background { background }
        .contentShape(Rectangle())
        .animation(ChromeMotion.hover, value: isHovered)
        .animation(ChromeMotion.hover, value: showsAudioButton)
        .animation(ChromeMotion.hover, value: tab.isAwayFromPin)
        .animation(ChromeMotion.fade, value: tab.isAsleep)
        .onHover { isHovered = $0 }
        .onTapGesture { tabManager.selectTab(tab.id) }
        // Alongside the single click, so selecting a tab never waits to see
        // whether a second click follows.
        .simultaneousGesture(TapGesture(count: 2).onEnded(beginRenaming))
        .help(presentation == .compact ? title : "")
        .contextMenu {
            TabActions(tab: tab, tabManager: tabManager, placement: .tab(rename: beginRenaming))
        }
    }

    // MARK: - Title

    @ViewBuilder
    private var titleView: some View {
        if isRenaming {
            TextField("Tab Name", text: $draftTitle)
                .textFieldStyle(.plain)
                .font(.callout)
                .focused($isTitleFieldFocused)
                .onAppear { isTitleFieldFocused = true }
                .onSubmit(finishRenaming)
                .onExitCommand { isRenaming = false }
                .onChange(of: isTitleFieldFocused) { _, isFocused in
                    if !isFocused { finishRenaming() }
                }
        } else {
            Text(title)
                .font(.callout)
                .foregroundStyle(isActive || isHovered ? .primary : .secondary)
                .lineLimit(1)
        }
    }

    private func beginRenaming() {
        draftTitle = tab.title
        isRenaming = true
    }

    /// Return or clicking away keeps the new name; Escape leaves before this.
    private func finishRenaming() {
        guard isRenaming else { return }
        isRenaming = false
        tab.rename(draftTitle)
    }

    // MARK: - Accessories

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

    /// A pinned tab that has wandered offers the way back to its pinned page.
    @ViewBuilder
    private var backToPinButton: some View {
        if tab.isAwayFromPin {
            Button(action: tab.returnToPin) {
                Image(systemName: ChromeSymbols.Tabs.backToPin)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(accessoryStyle)
            .help("Back to \(pinnedHost)")
            .transition(.opacity)
        }
    }

    private var pinnedHost: String {
        tab.pinnedURL.flatMap(URL.init).flatMap(\.host) ?? "pinned page"
    }

    private static let asleepOpacity = 0.55

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
            case .horizontal, .compact:
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
        case .horizontal, .compact: ChromeMetrics.tabHeight
        case .sidebar: ChromeMetrics.sidebarRowHeight
        }
    }

    private var title: String {
        tab.title.isEmpty ? "New Tab" : tab.title
    }
}
