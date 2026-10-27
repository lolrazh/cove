import SwiftUI

/// Marks a private window, in the sidebar header and the toolbar, alongside
/// the frame's private tint.
struct PrivateBadge: View {
    var body: some View {
        Label("Private", systemImage: ChromeSymbols.Navigation.privateBrowsing)
            .font(.callout.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(ChromePalette.resting, in: .capsule)
            .help("Private window: pages you visit aren't saved to history, and its tabs don't come back")
    }
}
