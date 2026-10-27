import SwiftUI

/// The hovered link's address in the page's bottom-leading corner, as in Arc
/// and Safari. Fades in a beat after the pointer settles on a link and leaves
/// as soon as it moves off, so a sweep across a list doesn't flicker.
struct LinkPreview: View {
    let url: URL?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack {
            if let url {
                Text(url.absoluteString)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background {
                        ConcentricRectangle.chrome()
                            .fill(.regularMaterial)
                            .chromeShadow(.floating)
                    }
                    .frame(maxWidth: 480, alignment: .leading)
                    .transition(.opacity.animation(ChromeMotion.fade.delay(0.1)))
            }
        }
        .padding(ChromeMetrics.cardInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .animation(ChromeMotion.fade, value: url)
        .allowsHitTesting(false)
    }
}
