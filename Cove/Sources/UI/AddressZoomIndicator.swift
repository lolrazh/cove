import SwiftUI

/// Keeps the address still while the current page's zoom changes.
struct AddressZoomIndicator: View {
    let zoom: Double?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.chromeTheme) private var theme

    var body: some View {
        ZStack {
            if let zoom {
                HStack(spacing: 5) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10, weight: .semibold))
                    Text(zoom, format: .percent.precision(.fractionLength(0)))
                        .monospacedDigit()
                        .contentTransition(reduceMotion ? .identity : .numericText(value: zoom))
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: zoom)
                }
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 66, height: 22)
                .background(theme.tint?.opacity(0.18) ?? Color.accentColor.opacity(0.18),
                            in: RoundedRectangle(cornerRadius: 7))
                .transition(.opacity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Page zoom")
                .accessibilityValue(zoom.formatted(.percent))
            }
        }
        .frame(width: 66, height: 24)
        .clipped()
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: zoom != nil)
        .allowsHitTesting(false)
    }
}
