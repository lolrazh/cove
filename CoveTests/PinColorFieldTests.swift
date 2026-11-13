import AppKit
import Testing
@testable import Cove

@MainActor
struct PinColorFieldTests {
    private func icon(_ draw: (Int, Int) -> NSColor) throws -> NSImage {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(data: nil, width: 16, height: 16, bitsPerComponent: 8,
            bytesPerRow: 64, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.byteOrder32Big.rawValue))
        for y in 0..<16 { for x in 0..<16 {
            context.setFillColor(draw(x, y).cgColor)
            context.fill(CGRect(x: x, y: y, width: 1, height: 1))
        } }
        return NSImage(cgImage: try #require(context.makeImage()), size: NSSize(width: 16, height: 16))
    }

    private func bitmap(_ image: NSImage) throws -> [UInt8] {
        let cg = try #require(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let data = try #require(cg.dataProvider?.data)
        return Array(data as Data)
    }

    private func color(_ bytes: [UInt8], x: Int, y: Int) -> SIMD4<Double> {
        let i = (y * 16 + x) * 4
        return SIMD4(Double(bytes[i]), Double(bytes[i + 1]), Double(bytes[i + 2]), Double(bytes[i + 3])) / 255
    }

    @Test func `transparent grooves receive smooth opaque color without dark seams`() throws {
        // Two colored strokes with an empty middle, like the gaps in a letter.
        let image = try icon { x, _ in
            x < 4 ? NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)
            : x > 11 ? NSColor(srgbRed: 0, green: 0, blue: 1, alpha: 1) : .clear
        }
        let field = try #require(PinColorField.make(from: image))
        let bitmap = try bitmap(field)
        for y in 0..<16 {
            var previous: SIMD4<Double>?
            for x in 0..<16 {
                let color = color(bitmap, x: x, y: y)
                #expect(color.w > 0.99)
                if let previous {
                    #expect(abs(color.x - previous.x) < 0.16)
                    #expect(abs(color.z - previous.z) < 0.16)
                }
                previous = color
            }
            let center = color(bitmap, x: 8, y: y)
            #expect(center.x > 0.6 && center.z > 0.6)
        }
    }

    @Test func `a small colored mark reaches all edges without inventing other hues`() throws {
        let image = try icon { x, y in
            x == 8 && y == 8 ? NSColor(srgbRed: 0, green: 0.8, blue: 0.2, alpha: 0.5) : .clear
        }
        let field = try #require(PinColorField.make(from: image))
        let bitmap = try bitmap(field)
        for y in 0..<16 { for x in 0..<16 {
            let color = color(bitmap, x: x, y: y)
            #expect(color.w > 0.99)
            #expect(color.x < 0.03)
            #expect(abs(color.y - 0.8) < 0.03)
            #expect(abs(color.z - 0.2) < 0.03)
        } }
    }

    @Test func `empty and template icons use the neutral fallback`() throws {
        #expect(PinColorField.make(from: try icon { _, _ in .clear }) == nil)
        let template = try icon { _, _ in .black }
        template.isTemplate = true
        #expect(PinColorField.make(from: template) == nil)
    }
}
