import AppKit
import QuartzCore

struct Sample: Decodable { let name: String; let bytes: Int64 }
@main struct RenderCards {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        let args = CommandLine.arguments
        let samples = try JSONDecoder().decode([Sample].self, from: Data(contentsOf: URL(fileURLWithPath: args[1])))
        let directory = URL(fileURLWithPath: args[2])
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for (index, sample) in samples.enumerated() {
            for radius in [10, 12, 16] {
                for (mode, name) in [("dark", NSAppearance.Name.darkAqua), ("light", .aqua)] {
                    let card = DownloadFlightCard.make(filename: sample.name, appearance: NSAppearance(named: name)!, scale: 3, cornerRadius: CGFloat(radius))
                    card.isGeometryFlipped = true
                    guard let context = CGContext(data: nil, width: 660, height: 108, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { continue }
                    context.scaleBy(x: 3, y: 3)
                    context.translateBy(x: 0, y: 36)
                    context.scaleBy(x: 1, y: -1)
                    card.render(in: context)
                    let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
                    try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("\(index)-\(radius)-\(mode).png"))
                }
            }
        }
        try renderSheets(directory: directory)
    }
}

import SwiftUI

@MainActor
func renderSheets(directory: URL) throws {
    func save(_ view: some View, name: String) throws {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, .dark))
        renderer.scale = 2
        guard let image = renderer.cgImage else { return }
        let bitmap = NSBitmapImageRep(cgImage: image)
        try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(name))
    }
    try save(VStack(alignment: .leading, spacing: 24) {
        Text("The download card, paused").font(.system(size: 22, weight: .semibold))
        Text("Actual app rendering · shown at 2× · current size 220 × 36 pt")
            .font(.system(size: 13)).foregroundStyle(.secondary)
        ForEach([16, 12, 10], id: \.self) { radius in
            VStack(alignment: .leading, spacing: 8) {
                Text(radius == 16 ? "16 pt — current" : "\(radius) pt — option")
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
                Image(nsImage: NSImage(contentsOf: directory.appendingPathComponent("0-\(radius)-dark.png"))!)
                    .resizable().frame(width: 440, height: 72)
            }
        }
    }.padding(32).foregroundStyle(.white).background(Color(white: 0.07)), name: "corners.png")
    let cases: [(String, Int64, Int64, Int?)] = [
        ("Your format", 25_800_000, 258_000_000, 18),
        ("Whole decimal stays visible", 26_000_000, 258_000_000, 17),
        ("Before three digits", 99_900_000, 258_000_000, 61),
        ("After three digits", 100_000_000, 258_000_000, 60),
        ("Hours", 100_000_000, 2_100_000_000, 10_380),
        ("Terabytes / days", 100_000_000_000, 2_100_000_000_000, 90_000),
        ("Small file", 7, 76, 1),
        ("Unknown size / no estimate", 1_000_000, -1, nil),
        ("Stalled / estimate hidden", 25_800_000, 258_000_000, nil)
    ]
    try save(VStack(alignment: .leading, spacing: 20) {
        Text("Progress states").font(.system(size: 22, weight: .semibold))
        Text("Native SwiftUI · same component as Cove")
            .font(.system(size: 13)).foregroundStyle(.secondary)
        ForEach(cases.indices, id: \.self) { index in
            let sample = cases[index]
            VStack(alignment: .leading, spacing: 5) {
                Text(sample.0).font(.system(size: 12)).foregroundStyle(.secondary)
                DownloadProgressText(completed: sample.1, total: sample.2, remainingSeconds: sample.3)
                    .font(.caption).frame(width: 240, alignment: .leading)
            }
        }
    }.padding(32).foregroundStyle(.white).background(Color(white: 0.07)), name: "progress.png")
}
