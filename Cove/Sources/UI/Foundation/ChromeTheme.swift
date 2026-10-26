import SwiftUI

/// The frame's color: an optional tint over the system gray. A value, so a
/// window today and a Space later can each carry one; the frame reads it from
/// the environment and never full-window glass.
struct ChromeTheme: Equatable {
    var tint: Color?

    static let system = ChromeTheme()

    /// The Settings swatches, after Arc's space colors: saturated enough to
    /// survive the mix below, in both appearances.
    static let presets: [ChromeTheme] = [
        .system,
        ChromeTheme(rawValue: "#E8788C"),
        ChromeTheme(rawValue: "#F0A060"),
        ChromeTheme(rawValue: "#E2BE48"),
        ChromeTheme(rawValue: "#74B486"),
        ChromeTheme(rawValue: "#5EA4E8"),
        ChromeTheme(rawValue: "#9C86E2"),
    ]

    /// How much tint goes into the frame. Light frames take more before they
    /// stop reading as gray; increased contrast halves it to keep the chrome
    /// quiet behind the controls.
    private static let lightAmount = 0.24
    private static let darkAmount = 0.22

    /// The frame behind the page card, in this theme and the given appearance.
    func frameColor(in environment: EnvironmentValues) -> Color {
        let base = Color(Color(nsColor: .underPageBackgroundColor).resolve(in: environment))
        guard let tint else { return base }
        var amount = environment.colorScheme == .dark ? Self.darkAmount : Self.lightAmount
        if environment.colorSchemeContrast == .increased { amount /= 2 }
        return base.mix(with: tint, by: amount, in: .perceptual)
    }
}

/// Stored as an sRGB hex string, empty for the system gray.
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

extension EnvironmentValues {
    @Entry var chromeTheme: ChromeTheme = .system
}

/// The frame, in the environment's theme and appearance.
struct ChromeFrameStyle: ShapeStyle {
    func resolve(in environment: EnvironmentValues) -> Color {
        environment.chromeTheme.frameColor(in: environment)
    }
}

/// A surface lifted off the frame, like the active sidebar tab. In light mode
/// that's the page's color, as in Arc. In dark mode the page is darker than the
/// frame and would read as sunken, so the lift comes from lightening the frame
/// itself, which keeps the theme's tint.
struct ChromeRaisedStyle: ShapeStyle {
    private static let lift = 0.09

    func resolve(in environment: EnvironmentValues) -> Color {
        guard environment.colorScheme == .dark else { return ChromePalette.content }
        return environment.chromeTheme.frameColor(in: environment).mix(with: .white, by: Self.lift)
    }
}
