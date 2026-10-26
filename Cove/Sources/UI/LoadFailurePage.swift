import SwiftUI

/// Stands in for a page that couldn't be loaded, like the start page stands in
/// for an empty tab.
struct LoadFailurePage: View {
    let failure: LoadFailure
    let onRetry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Can’t Open This Page", systemImage: ChromeSymbols.Navigation.loadFailed)
        } description: {
            Text(failure.message)
        } actions: {
            Button("Try Again", action: onRetry)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ChromePalette.content)
    }
}
