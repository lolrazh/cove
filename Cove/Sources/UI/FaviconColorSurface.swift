import SwiftUI

/// The favicon stays crisp above one shared color field for the fill and rim.
struct FaviconColorSurface: View {
    let image: NSImage?
    let isActive: Bool
    var cornerRadius: CGFloat = 10
    var fillOpacity: Double = 0.40
    var edgeWidth: CGFloat = 2
    @State private var colorField: NSImage?

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(ChromePalette.resting)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(ChromePalette.raised)
                    .opacity(isActive ? 1 : 0)
            }
            .overlay {
                if isActive {
                    if let colorField {
                        Image(nsImage: colorField)
                            .resizable()
                            .interpolation(.high)
                            .opacity(fillOpacity)
                    }
                }
            }
            .clipShape(.rect(cornerRadius: cornerRadius))
            .overlay {
                if isActive {
                    let rim = RoundedRectangle(cornerRadius: cornerRadius)
                    // Keep the edge readable for monochrome or missing icons.
                    rim.strokeBorder(ChromePalette.onTheme, lineWidth: edgeWidth)
                        .opacity(0.24)
                    if let colorField {
                        Image(nsImage: colorField)
                            .resizable()
                            .interpolation(.high)
                            .saturation(1.2)
                            .mask(rim.strokeBorder(lineWidth: edgeWidth))
                    }
                }
            }
            .onChange(of: image, initial: true) { _, image in
                colorField = image.flatMap(PinColorField.make)
            }
            .allowsHitTesting(false)
    }
}

