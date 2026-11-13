import SwiftUI

/// Back, forward and reload/stop for one tab, above the page in every layout.
struct NavigationControls: View {
    @ObservedObject var session: TabSession

    var body: some View {
        HStack(spacing: ChromeMetrics.navigationSpacing) {
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
                Image(systemName: session.isLoading ? ChromeSymbols.Navigation.stop : ChromeSymbols.Navigation.reload)
            }
            .help(session.isLoading ? "Stop" : "Reload")
        }
        .buttonStyle(ChromeButtonStyle())
    }

}
