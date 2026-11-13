import SwiftUI

/// A profile chooses one primary color and an intensity. Its full tonal palette
/// is derived, so custom colors get the same treatment as the built-in choices.
struct ChromeTheme: Hashable {
    var tint: Color?
    var glow: Double = 1

    static let system = ChromeTheme()

    /// Private windows use an indigo palette distinct from the normal default.
    static let privateBrowsing = ChromeTheme(rawValue: "#2E2560")

    /// The eight study pairs, followed by eight additional color choices.
    private static let colors = [
        ("#BAC4CC", "#C7B9B0"), ("#35CC9A", "#42B7B0"),
        ("#4BAFF1", "#8984EE"), ("#AC86EB", "#D68FC8"),
        ("#F8CE60", "#F3A270"), ("#EF9BB8", "#D595DC"),
        ("#EE8295", "#F4B18F"), ("#F5AC72", "#ED8E91"),
        ("#46C2BD", "#79BFE6"), ("#87D6B0", "#A9D894"),
        ("#61C8EB", "#849CEB"), ("#8584ED", "#B38DE9"),
        ("#B77AC8", "#E38EBC"), ("#F48F81", "#F4B497"),
        ("#ED666F", "#F3937C"), ("#D8BB94", "#E5CA9B"),
    ]
    static let presets = colors.map { ChromeTheme(rawValue: $0.0) }
    static let presetNames = ["Neutral", "Green", "Blue", "Purple", "Yellow", "Pink", "Red", "Orange",
                              "Teal", "Mint", "Sky", "Indigo", "Plum", "Coral", "Scarlet", "Sand"]

    var palette: ThemePalette {
        let seed = tint ?? Color(red: 75.0 / 255, green: 175.0 / 255, blue: 241.0 / 255)
        let color = seed.resolve(in: EnvironmentValues())
        let pair = Self.colors.first { $0.0 == (tint == nil ? "#4BAFF1" : rawValue) }
        return ThemePalette(red: Double(color.red), green: Double(color.green), blue: Double(color.blue),
                            companion: pair.flatMap { ChromeTheme(rawValue: $0.1).tint })
    }

    var primaryLight: Color { palette.light.opacity(glow) }
    var secondaryLight: Color { palette.companion.opacity(glow) }

    /// Keep the frame bright in both page appearances. Increased Contrast
    /// uses the opaque system surface.
    func frameColor(in environment: EnvironmentValues) -> Color {
        if environment.colorSchemeContrast == .increased {
            return Color(nsColor: .underPageBackgroundColor)
        }
        return Color.white.mix(with: palette.paper, by: glow)
    }

}

/// Stored as an sRGB hex string, empty for the default palette.
extension ChromeTheme: RawRepresentable {
    init(rawValue: String) {
        var hex = Substring(rawValue)
        if hex.hasPrefix("#") { hex = hex.dropFirst() }
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else {
            self.init()
            return
        }
        self.init(tint: Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        ))
    }

    var rawValue: String {
        guard let tint else { return "" }
        let resolved = tint.resolve(in: EnvironmentValues())
        let channels = [resolved.red, resolved.green, resolved.blue].map { Int(($0 * 255).rounded()) }
        return channels.reduce("#") { $0 + String(format: "%02X", min(max($1, 0), 255)) }
    }
}

// Read both the original color string and the short-lived two-color format.
// Old secondaryTint values are ignored: the primary now owns the full palette.
extension ChromeTheme: Codable {
    private enum CodingKeys: String, CodingKey { case tint, glow }

    init(from decoder: Decoder) throws {
        if let hex = try? decoder.singleValueContainer().decode(String.self) {
            self.init(rawValue: hex)
            return
        }
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(rawValue: try values.decodeIfPresent(String.self, forKey: .tint) ?? "")
        glow = min(1, max(0, try values.decodeIfPresent(Double.self, forKey: .glow) ?? 1))
    }

    func encode(to encoder: Encoder) throws {
        if glow == 1 {
            var value = encoder.singleValueContainer()
            try value.encode(rawValue)
        } else {
            var values = encoder.container(keyedBy: CodingKeys.self)
            try values.encode(rawValue, forKey: .tint)
            try values.encode(glow, forKey: .glow)
        }
    }
}

/// Cove's generated analogous palette. Dia's tonal roles and color wheel were
/// observed in its binary; these coefficients are our own visual choices.
struct ThemePalette {
    let hue: Double
    let saturation: Double
    let companionHue: Double
    let light: Color
    private let pairedColor: Color?

    init(red: Double, green: Double, blue: Double, companion: Color? = nil) {
        pairedColor = companion
        let high = max(red, green, blue), low = min(red, green, blue)
        let delta = high - low
        let sector: Double
        if delta < 0.0001 { sector = 0 }
        else if high == red { sector = (green - blue) / delta }
        else if high == green { sector = 2 + (blue - red) / delta }
        else { sector = 4 + (red - green) / delta }
        hue = (sector / 6 + 1).truncatingRemainder(dividingBy: 1)
        let sourceSaturation = high == 0 ? 0 : delta / high
        saturation = sourceSaturation < 0.08 ? sourceSaturation : max(0.72, sourceSaturation)
        // Keep arbitrary dark custom seeds readable under the shared dark ink.
        // The selected study pairs retain their exact primary colors.
        light = companion == nil
            ? Color(hue: hue, saturation: min(sourceSaturation, 0.60), brightness: max(high, 0.85))
            : Color(red: red, green: green, blue: blue)
        companionHue = (hue + (hue < 0.18 ? -0.045 : 0.065) + 1).truncatingRemainder(dividingBy: 1)
    }

    var companion: Color { pairedColor ?? Color(hue: companionHue, saturation: saturation * 0.65, brightness: 0.93) }
    var paper: Color { light.mix(with: .white, by: 0.22, in: .device) }
}

extension EnvironmentValues {
    @Entry var chromeTheme: ChromeTheme = .system
    @Entry var chromeFrameColor: Color? = nil
    @Entry var chromePrimaryLight: Color? = nil
    @Entry var chromeSecondaryLight: Color? = nil
}

/// The frame, in the environment's theme and appearance.
struct ChromeFrameStyle: ShapeStyle {
    func resolve(in environment: EnvironmentValues) -> Color {
        (environment.chromeFrameColor ?? environment.chromeTheme.frameColor(in: environment))
    }
}

/// Text on saturated theme surfaces needs a solid foreground, rather than the
/// system's translucent secondary label blending into the colored light.
struct ChromeOnThemeStyle: ShapeStyle {
    func resolve(in environment: EnvironmentValues) -> Color {
        environment.colorSchemeContrast == .increased && environment.colorScheme == .dark
            ? .white : Color(red: 0.09, green: 0.20, blue: 0.26)
    }
}

/// A translucent lift over the Fine grain frame.
struct ChromeRaisedStyle: ShapeStyle {
    func resolve(in environment: EnvironmentValues) -> Color {
        environment.colorSchemeContrast == .increased ? ChromePalette.content : .white.opacity(0.49)
    }
}

// Resolve the frame once, then interpolate its components. Changing a theme
// environment value alone jumps custom ShapeStyles to the final color.
extension View {
    func animatedChromeTheme(_ theme: ChromeTheme, profiles: [Profile], transition: ProfileTransition) -> some View {
        modifier(ChromeThemeTransition(theme: theme, profiles: profiles, transition: transition))
    }
}

private struct ChromeThemeTransition: ViewModifier {
    let theme: ChromeTheme
    let profiles: [Profile]
    @ObservedObject var transition: ProfileTransition
    @Environment(\.self) private var environment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let motion = transition.state
        let source = profiles.first { $0.id == motion.source }?.theme ?? theme
        let targetID = motion.position < 0 ? motion.next : motion.previous
        let target = profiles.first { $0.id == targetID }?.theme ?? source
        let frame = motion.isActive
            ? source.frameColor(in: environment).mix(with: target.frameColor(in: environment),
                by: Double(min(abs(motion.position), 1)), in: .perceptual)
            : theme.frameColor(in: environment)
        let fraction = Double(min(abs(motion.position), 1))
        let primary = motion.isActive ? source.primaryLight.mix(with: target.primaryLight, by: fraction, in: .perceptual) : theme.primaryLight
        let secondary = motion.isActive ? source.secondaryLight.mix(with: target.secondaryLight, by: fraction, in: .perceptual) : theme.secondaryLight
        let animation: Animation? = switch motion.phase {
        case .tracking: nil
        case .settling: nil
        case .idle: reduceMotion ? ChromeMotion.hover : ChromeMotion.themeChange
        }
        content.animation(animation) { view in
            view
                .environment(\.chromeTheme, theme)
                .modifier(ResolvedChromeColor(frame.resolve(in: environment), key: \.chromeFrameColor))
                .modifier(ResolvedChromeColor(primary.resolve(in: environment), key: \.chromePrimaryLight))
                .modifier(ResolvedChromeColor(secondary.resolve(in: environment), key: \.chromeSecondaryLight))
        }
    }
}

private struct ResolvedChromeColor: AnimatableModifier {
    let key: WritableKeyPath<EnvironmentValues, Color?>
    nonisolated var red: Double
    nonisolated var green: Double
    nonisolated var blue: Double
    nonisolated var opacity: Double

    init(_ color: Color.Resolved, key: WritableKeyPath<EnvironmentValues, Color?>) {
        self.key = key
        red = Double(color.linearRed); green = Double(color.linearGreen)
        blue = Double(color.linearBlue); opacity = Double(color.opacity)
    }

    nonisolated var animatableData: AnimatablePair<AnimatablePair<Double, Double>, AnimatablePair<Double, Double>> {
        get { AnimatablePair(AnimatablePair(red, green), AnimatablePair(blue, opacity)) }
        set {
            red = newValue.first.first; green = newValue.first.second
            blue = newValue.second.first; opacity = newValue.second.second
        }
    }

    func body(content: Content) -> some View {
        content.environment(key, Color(.sRGBLinear, red: red, green: green, blue: blue, opacity: opacity))
    }
}

/// Choose the readable system controls for an opaque page background. The
/// threshold is where black and white have equal WCAG contrast ratios.
enum PageChromeContrast {
    static func scheme(for color: NSColor, fallback: ColorScheme) -> ColorScheme {
        guard let rgb = color.usingColorSpace(.sRGB), rgb.alphaComponent > 0.99 else { return fallback }
        func linear(_ value: Double) -> Double {
            value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * linear(rgb.redComponent)
            + 0.7152 * linear(rgb.greenComponent) + 0.0722 * linear(rgb.blueComponent)
        return luminance > 0.179 ? .light : .dark
    }
}

/// One static glass surface for docked and floating chrome. macOS owns the
/// backdrop material; Cove adds an 8 pt softening pass and a cached grain tile.
struct ChromeAmbientBackground: View {
    @Environment(\.chromeTheme) private var theme
    @Environment(\.chromePrimaryLight) private var primary
    @Environment(\.chromeSecondaryLight) private var secondary
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            if contrast == .increased || reduceTransparency {
                Rectangle().fill(ChromePalette.shell)
            } else {
                ChromeGlassBackdrop().blur(radius: 8)
                Rectangle().fill(ChromePalette.shell).opacity(0.94)
                GeometryReader { geometry in
                    let extent = max(geometry.size.width, geometry.size.height)
                    ZStack {
                        RadialGradient(colors: [(primary ?? theme.primaryLight).opacity(0.62), .clear],
                                       center: .topLeading, startRadius: 0, endRadius: extent * 0.9)
                        RadialGradient(colors: [(secondary ?? theme.secondaryLight).opacity(0.62), .clear],
                                       center: .bottomLeading, startRadius: 0, endRadius: extent * 0.8)
                    }
                    .blur(radius: 40)
                }
                Rectangle().fill(ImagePaint(image: Image(nsImage: FineGrain.image)))
                    .blendMode(.softLight)
                    .opacity(0.10)
            }
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct ChromeGlassBackdrop: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

private enum FineGrain {
    /// One repeatable 128 px tile, made once. No timer, per-frame noise, or asset dependency.
    static let image: NSImage = {
        let side = 128
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
            bitsPerSample: 8, samplesPerPixel: 1, hasAlpha: false, isPlanar: false,
            colorSpaceName: .deviceWhite, bytesPerRow: side, bitsPerPixel: 8),
            let pixels = bitmap.bitmapData else { return NSImage(size: .zero) }
        var seed: UInt32 = 17
        for index in 0..<(side * side) {
            seed = seed &* 1664525 &+ 1013904223
            pixels[index] = 80 + UInt8(truncatingIfNeeded: seed >> 25)
        }
        let image = NSImage(size: NSSize(width: side / 2, height: side / 2))
        image.addRepresentation(bitmap)
        return image
    }()
}
