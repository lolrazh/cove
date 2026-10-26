import SwiftUI

/// Back, forward and reload/stop for one tab. The navigation bar shows them in
/// top-tab mode; the sidebar header shows them in sidebar mode.
struct NavigationControls: View {
    @ObservedObject var session: TabSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            Button(action: session.goBack) {
                Image(systemName: ChromeSymbols.Navigation.back)
            }
            .disabled(!session.canGoBack)
            .help("Back")

            Button(action: session.goForward) {
                Image(systemName: ChromeSymbols.Navigation.forward)
            }
            .disabled(!session.canGoForward)
            .help("Forward")

            Button {
                session.isLoading ? session.stopLoading() : session.reload()
            } label: {
                reloadIcon
            }
            .help(session.isLoading ? "Stop" : "Reload")
        }
        .buttonStyle(ChromeButtonStyle())
    }

    private var reloadIcon: some View {
        let icon = Image(systemName: session.isLoading ? ChromeSymbols.Navigation.stop : ChromeSymbols.Navigation.reload)

        return Group {
            if reduceMotion {
                icon
            } else {
                icon.symbolEffect(.bounce, value: session.isLoading)
            }
        }
    }
}
