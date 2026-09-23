import AppKit

/// Turns favicon bytes into the image Cove draws.
enum FaviconImage {
    private static let size = NSSize(width: 32, height: 32)

    /// Renders the icon at a fixed size, and marks single-color icons as
    /// templates so they're tinted like text. Sites like GitHub ship a black
    /// glyph on transparency, which vanishes on a dark tab; as a template it
    /// turns white in dark mode and follows appearance changes by itself.
    nonisolated static func make(from data: Data) -> NSImage? {
        guard let source = NSImage(data: data), source.isValid,
              let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(size.width) * 2,
                pixelsHigh: Int(size.height) * 2,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
              ) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSGraphicsContext.current?.imageInterpolation = .high
        source.draw(
            in: NSRect(x: 0, y: 0, width: bitmap.pixelsWide, height: bitmap.pixelsHigh),
            from: .zero,
            operation: .copy,
            fraction: 1
        )
        NSGraphicsContext.restoreGraphicsState()

        bitmap.size = size
        let image = NSImage(size: size)
        image.addRepresentation(bitmap)
        image.isTemplate = isSingleTone(bitmap)
        return image
    }

    /// True when nearly every visible pixel is the same neutral tone: all
    /// near-black or all near-white, with no color. Icons drawn on their own
    /// background square have both tones and stay as they are.
    private nonisolated static func isSingleTone(_ bitmap: NSBitmapImageRep) -> Bool {
        var visible = 0, dark = 0, light = 0, colored = 0

        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                guard let color = bitmap.colorAt(x: x, y: y), color.alphaComponent > 0.2 else { continue }
                visible += 1

                let brightest = max(color.redComponent, color.greenComponent, color.blueComponent)
                let dimmest = min(color.redComponent, color.greenComponent, color.blueComponent)

                if brightest - dimmest > 0.15 {
                    colored += 1
                } else if brightest < 0.35 {
                    dark += 1
                } else if dimmest > 0.85 {
                    light += 1
                }
            }
        }

        guard visible > 0 else { return false }
        let total = Double(visible)
        let oneTone = Double(dark) / total > 0.9 || Double(light) / total > 0.9
        return oneTone && Double(colored) / total < 0.02
    }
}
