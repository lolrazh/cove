import SwiftUI

/// Little Cove's contents: a compact bar beside the traffic lights (the
/// page's site and Open in Cove) over the page in a card.
struct LittleCoveView: View {
    @ObservedObject var tab: TabSession
    let appServices: AppServices
    let onOpenInCove: () -> Void

    var body: some View {
        WindowChromeHost(showsTrafficLights: true, onAttach: { _ in }) {
            LittleCoveContent(tab: tab, appServices: appServices, onOpenInCove: onOpenInCove)
        }
        .background(ChromePalette.shell)
        .environment(\.chromeTheme, appServices.settingsStore.theme)
    }
}

private struct LittleCoveContent: View {
    @ObservedObject var tab: TabSession
    let appServices: AppServices
    let onOpenInCove: () -> Void

    @Environment(\.trafficLightInset) private var trafficLightInset

    var body: some View {
        VStack(spacing: 0) {
            bar
            PageView(tab: tab, appServices: appServices)
                .chromeCard()
                .padding([.horizontal, .bottom], ChromeMetrics.cardInset)
        }
    }

    private var bar: some View {
        HStack(spacing: 8) {
            FaviconView(image: tab.favicon, size: 16)
            Text(site)
                .font(.callout.weight(.medium))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 8)

            Button(action: onOpenInCove) {
                Label("Open in Cove", systemImage: ChromeSymbols.Tabs.openInCove)
                    .labelStyle(.titleAndIcon)
                    .font(.callout)
                    .padding(.horizontal, 6)
            }
            .buttonStyle(ChromeButtonStyle(size: .titlebar))
            .disabled(tab.isNewTabPage)
            .help("Move this page into your browser window")
        }
        .padding(.leading, trafficLightInset + ChromeMetrics.trafficLightTrailingGap)
        .padding(.trailing, ChromeMetrics.gutter)
        .padding(.bottom, ChromeMetrics.tabBottomInset)
        .frame(height: ChromeMetrics.titlebarHeight, alignment: .bottom)
    }

    /// The page's domain, or the window's name on the start page.
    private var site: String {
        guard let url = URL(string: tab.currentURL), !tab.currentURL.isEmpty else { return "Little Cove" }
        return Site(url)?.domain ?? tab.currentURL
    }
}
