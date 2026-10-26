import SwiftUI

/// Loading progress as a thin line along the top edge of the page. Arc shows a
/// shimmer on the active tab instead; Cove puts it on the page so it reads in
/// every tab mode, including the two where the tabs are hidden.
///
/// The line only ever grows: a new load that resets progress snaps back
/// rather than visibly shrinking, and a finished load fills up before fading.
struct PageProgressBar: View {
    let progress: Double
    let isLoading: Bool

    @State private var shownProgress: Double = 0

    var body: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(.tint)
                .frame(width: geometry.size.width * shownProgress)
        }
        .frame(height: ChromeMetrics.progressHeight)
        .opacity(isLoading ? 1 : 0)
        .animation(isLoading ? nil : ChromeMotion.fade.delay(0.15), value: isLoading)
        .allowsHitTesting(false)
        .onChange(of: progress, initial: true) { old, new in
            withAnimation(new > old ? ChromeMotion.progress : nil) {
                shownProgress = new
            }
        }
    }
}
