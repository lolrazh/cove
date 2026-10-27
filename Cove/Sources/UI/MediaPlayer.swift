import SwiftUI

/// Arc's media player: when a tab in the background plays audio or video, its
/// controls, without going back to it. A card above the sidebar's footer, or
/// a compact control in the navigation bar in top-tab mode.
struct MediaPlayer: View {
    enum Style {
        /// Title, site, skip back and forward, play or pause, and mute.
        case card
        /// The favicon, to open the tab, and play or pause; the rest in its help.
        case compact
    }

    @ObservedObject var tabManager: TabManager
    let style: Style

    var body: some View {
        Group {
            if let tab = tabManager.mediaTab {
                MediaPlayerControls(tab: tab, style: style) {
                    tabManager.selectTab(tab.id)
                }
                .id(tab.id)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(ChromeMotion.tab, value: tabManager.mediaTab?.id)
    }
}

private struct MediaPlayerControls: View {
    @ObservedObject var tab: TabSession
    let style: MediaPlayer.Style
    let openTab: () -> Void

    @State private var isHovered = false

    var body: some View {
        if let nowPlaying = tab.nowPlaying {
            switch style {
            case .card: card(nowPlaying)
            case .compact: compact(nowPlaying)
            }
        }
    }

    // MARK: - Card

    private func card(_ nowPlaying: NowPlaying) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                FaviconView(image: tab.favicon, size: 16)

                VStack(alignment: .leading, spacing: 0) {
                    Text(title(nowPlaying))
                        .font(.callout.weight(.medium))
                    Text(subtitle(nowPlaying))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

                closeButton
            }
            .padding(.leading, 6)
            .contentShape(Rectangle())
            .onTapGesture(perform: openTab)
            .help("Show Tab")

            HStack(spacing: 0) {
                skipButton(nowPlaying, forward: false)
                playButton(nowPlaying)
                skipButton(nowPlaying, forward: true)
                Spacer(minLength: 0)
                muteButton
            }
        }
        .padding(ChromeMetrics.tabAccessoryInset)
        .containerShape(RoundedRectangle(cornerRadius: ChromeRadius.tab, style: .continuous))
        .background {
            ConcentricRectangle.chrome(minimum: ChromeRadius.tab)
                .fill(ChromePalette.raised)
                .chromeShadow(.raised)
        }
        .onHover { isHovered = $0 }
        .animation(ChromeMotion.hover, value: isHovered)
    }

    /// Shows on hover. Pauses the media and puts the player away.
    private var closeButton: some View {
        Button { tab.media?.closePlayer() } label: {
            Image(systemName: ChromeSymbols.Media.close)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(ChromeButtonStyle(size: .accessory()))
        .help("Close Player")
        .opacity(isHovered ? 1 : 0)
        .allowsHitTesting(isHovered)
    }

    private var muteButton: some View {
        Button(action: tab.toggleMuted) {
            Image(systemName: tab.isMuted ? ChromeSymbols.Tabs.muted : ChromeSymbols.Tabs.playingAudio)
                .foregroundStyle(.secondary)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(controlStyle)
        .help(tab.isMuted ? "Unmute Tab" : "Mute Tab")
    }

    // MARK: - Compact

    private func compact(_ nowPlaying: NowPlaying) -> some View {
        HStack(spacing: 0) {
            Button(action: openTab) {
                FaviconView(image: tab.favicon, size: 16)
            }
            .help("Show Tab: \(title(nowPlaying)), \(subtitle(nowPlaying))")

            playButton(nowPlaying)
        }
        .buttonStyle(controlStyle)
    }

    // MARK: - Controls

    private func playButton(_ nowPlaying: NowPlaying) -> some View {
        control(nowPlaying.isPlaying ? .pause : .play)
    }

    private func skipButton(_ nowPlaying: NowPlaying, forward: Bool) -> some View {
        control(nowPlaying.skipAction(forward: forward))
    }

    private func control(_ action: MediaAction) -> some View {
        Button { tab.media?.perform(action) } label: {
            Image(systemName: action.symbol)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(controlStyle)
        .help(action.help)
    }

    private var controlStyle: ChromeButtonStyle {
        ChromeButtonStyle(size: .accessory(side: ChromeMetrics.iconButtonSize))
    }

    // MARK: - Text

    private func title(_ nowPlaying: NowPlaying) -> String {
        nowPlaying.title.isEmpty ? tab.title : nowPlaying.title
    }

    /// The artist if the page names one, or else the site.
    private func subtitle(_ nowPlaying: NowPlaying) -> String {
        guard nowPlaying.artist.isEmpty else { return nowPlaying.artist }
        guard let host = URL(string: tab.currentURL)?.host() else { return tab.currentURL }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}

private extension MediaAction {
    var symbol: String {
        switch self {
        case .play: ChromeSymbols.Media.play
        case .pause: ChromeSymbols.Media.pause
        case .previousTrack: ChromeSymbols.Media.previousTrack
        case .nextTrack: ChromeSymbols.Media.nextTrack
        case .seekBackward: ChromeSymbols.Media.seekBackward
        case .seekForward: ChromeSymbols.Media.seekForward
        }
    }

    var help: String {
        switch self {
        case .play: "Play"
        case .pause: "Pause"
        case .previousTrack: "Previous Track"
        case .nextTrack: "Next Track"
        case .seekBackward: "Back 10 Seconds"
        case .seekForward: "Forward 10 Seconds"
        }
    }
}
