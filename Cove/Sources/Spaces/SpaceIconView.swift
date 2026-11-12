import SwiftUI

/// A shared, quiet marker for spaces. Stored legacy symbols do not affect it.
struct SpaceIconView: View {
    var diameter: CGFloat = 7

    var body: some View {
        Circle()
            .frame(width: diameter, height: diameter)
            .accessibilityHidden(true)
    }
}
