import AppKit

/// A tiny, opaque color field for a pin's fill and rim. Normalize by alpha so
/// transparent holes contribute no black and do not become gaps in the rim.
enum PinColorField {
    private static let side = 16
    private static let weights = (-15...15).map { exp(-Double($0 * $0) / (2 * 4.5 * 4.5)) }

    @MainActor
    static func make(from image: NSImage) -> NSImage? {
        guard !image.isTemplate,
              let source = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let field = make(from: source) else { return nil }
        return NSImage(cgImage: field, size: NSSize(width: side, height: side))
    }

    static func make(from image: CGImage) -> CGImage? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8,
                                      bytesPerRow: side * 4, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                                        | CGBitmapInfo.byteOrder32Big.rawValue),
              let data = context.data else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
        let bytes = data.assumingMemoryBound(to: UInt8.self)
        let pixels: [SIMD4<Double>] = stride(from: 0, to: side * side * 4, by: 4).map { i in
            let alpha = Double(bytes[i + 3]) / 255
            guard alpha > 0 else { return .zero }
            return SIMD4(linear(Double(bytes[i]) / 255 / alpha) * alpha,
                         linear(Double(bytes[i + 1]) / 255 / alpha) * alpha,
                         linear(Double(bytes[i + 2]) / 255 / alpha) * alpha, alpha)
        }
        guard pixels.contains(where: { $0.w > 0 }) else { return nil }

        // Two short passes give the same Gaussian as a full 2D convolution.
        let horizontal: [SIMD4<Double>] = (0..<(side * side)).map { i in
            var sum = SIMD4<Double>.zero
            for x in 0..<side {
                sum += pixels[(i / side) * side + x] * weights[x - i % side + 15]
            }
            return sum
        }
        for y in 0..<side {
            for x in 0..<side {
                var sum = SIMD4<Double>.zero
                for sourceY in 0..<side {
                    sum += horizontal[sourceY * side + x] * weights[sourceY - y + 15]
                }
                // Every Gaussian weight is positive. Any visible source pixel
                // supplies color even across a fully transparent part of a logo.
                let i = (y * side + x) * 4
                bytes[i] = UInt8((encoded(sum.x / sum.w) * 255).rounded())
                bytes[i + 1] = UInt8((encoded(sum.y / sum.w) * 255).rounded())
                bytes[i + 2] = UInt8((encoded(sum.z / sum.w) * 255).rounded())
                bytes[i + 3] = 255
            }
        }
        return context.makeImage()
    }

    // Blend light, not gamma-encoded bytes, to avoid muddy seams between hues.
    private static func linear(_ value: Double) -> Double {
        value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }

    private static func encoded(_ value: Double) -> Double {
        let value = min(1, max(0, value))
        return value <= 0.0031308 ? value * 12.92 : 1.055 * pow(value, 1 / 2.4) - 0.055
    }
}
