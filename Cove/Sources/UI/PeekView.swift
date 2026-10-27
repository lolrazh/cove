import SwiftUI

/// The Peek over the page: the page dimmed behind a card holding the peeked
/// page, with its site, Open as Tab and Close. Escape or a click on the
/// dimmed page closes it.
struct PeekOverlay: View {
    @ObservedObject var tabManager: TabManager
    let appServices: AppServices

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if let peek = tabManager.peek {
                Color.black.opacity(0.25)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: tabManager.closePeek)
                    .transition(.opacity)

                PeekCard(tab: peek.tab, appServices: appServices, onExpand: tabManager.expandPeek, onClose: tabManager.closePeek)
                    .padding(.horizontal, 48)
                    .padding(.vertical, 28)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.94).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? ChromeMotion.fade : ChromeMotion.appear, value: tabManager.peek?.tab.id)
    }
}

private struct PeekCard: View {
    @ObservedObject var tab: TabSession
    let appServices: AppServices
    let onExpand: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            bar
            PageView(tab: tab, appServices: appServices)
        }
        .clipShape(.chrome(minimum: ChromeRadius.tile))
        .contentShape(Rectangle())
        .background {
            ConcentricRectangle.chrome(minimum: ChromeRadius.tile)
                .fill(ChromePalette.content)
                .chromeShadow(.panel)
        }
    }

    private var bar: some View {
        HStack(spacing: 8) {
            FaviconView(image: tab.favicon, size: 16)
            Text(Site(URL(string: tab.currentURL))?.domain ?? tab.currentURL)
                .font(.callout.weight(.medium))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 8)

            Button(action: onExpand) {
                Image(systemName: ChromeSymbols.Tabs.expandPeek)
            }
            .help("Open as Tab")

            Button(action: onClose) {
                Image(systemName: ChromeSymbols.Tabs.close)
            }
            .keyboardShortcut(.cancelAction)
            .help("Close")
        }
        .buttonStyle(ChromeButtonStyle(size: .accessory(side: 26)))
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .frame(height: 38)
        .background(ChromePalette.shell)
    }
}
