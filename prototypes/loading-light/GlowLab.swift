import AppKit
import SwiftUI

// Isolated native study. No prototype settings are applied to the browser.
struct GlowSettings: Codable, Equatable {
    var spread = 22.0
    var strength = 0.19
    var rightSpread = 9.0
    var base = 0.45
    var curve = 1.4
    var thickness = 1.0
    var lineStrength = 0.9
    var red = 0.16
    var green = 0.46
    var blue = 0.96
    var dark = false
    var progress = 0.724
    var radius = 8.0

    var tint: Color { Color(red: red, green: green, blue: blue) }

    static func preset(_ name: String) -> Self {
        var value = Self()
        switch name {
        case "Wide wash": value.spread = 32; value.strength = 0.14; value.rightSpread = 14
        case "Near strip": value.spread = 14; value.strength = 0.24; value.rightSpread = 6
        default: break
        }
        return value
    }
}

struct SavedGlow: Codable, Identifiable {
    var id = UUID()
    var name: String
    var settings: GlowSettings
}

// The emitter ends at progress. A small diffuse blur wraps around its tip,
// then widens gently with height. The rounded spread balances a constant-width
// tail and a sharp fan. The address surface clips the whole light field.
struct UpwardLight: View, Animatable {
    let settings: GlowSettings
    var progress: Double
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    /// Integral of a normalized Gaussian over the finite emitting segment.
    /// Outside the source this decreases monotonically; no new source appears.
    private func coverage(at x: Double, end: Double, sigma: Double) -> Double {
        let scale = max(0.15, sigma) * sqrt(2)
        return max(0, 0.5 * (erf(x / scale) - erf((x - end) / scale)))
    }

    var body: some View {
        Canvas { context, size in
            guard progress > 0 else { return }
            let end = size.width * min(1, max(0, progress))
            let verticalSigma = settings.spread / 2.5
            // Half-point rows retain a smooth falloff at Retina scale.
            for row in 0..<Int(ceil(size.height * 2)) {
                let y = Double(row) / 2
                let height = max(0, size.height - y - 0.25 - settings.thickness / 2)
                let broad = settings.strength * exp(-0.5 * pow(height / verticalSigma, 2))
                let close = 0.13 * exp(-0.5 * pow(height / 2.2, 2))
                // A small base radius rounds the tip instead of pinching it to
                // a wedge. The height term is gentler than the previous fan.
                let broadSigma = max(0.15, settings.rightSpread * hypot(0.6, 0.55 * height / verticalSigma))
                let closeSigma = max(0.15, min(1.5, settings.rightSpread / 6) * hypot(0.6, 0.4 * height / 2.2))
                let extent = min(size.width, end + max(broadSigma, closeSigma) * 4)
                // Sample the body and both ends, including the narrow close halo.
                // Dense endpoint stops avoid a polygon edge as the fan opens.
                var positions = (0...32).map { Double($0) / 32 * end }
                for sigma in [broadSigma, closeSigma] {
                    for step in -16...16 {
                        let offset = Double(step) / 4 * sigma
                        positions.append(min(extent, max(0, end + offset)))
                        positions.append(min(extent, max(0, offset)))
                    }
                }
                positions.append(extent)
                let stops = Set(positions).sorted().map { x -> Gradient.Stop in
                    let position = min(1, max(0, x / end))
                    let emission = settings.base + (1 - settings.base) * pow(position, settings.curve)
                    let energy = broad * coverage(at: x, end: end, sigma: broadSigma)
                        + close * coverage(at: x, end: end, sigma: closeSigma)
                    return .init(color: settings.tint.opacity(emission * energy), location: x / extent)
                }
                let glow = GraphicsContext.Shading.linearGradient(
                    Gradient(stops: stops), startPoint: .zero, endPoint: CGPoint(x: extent, y: 0)
                )
                context.fill(Path(CGRect(x: 0, y: y, width: extent, height: 0.5)), with: glow)
            }
            let lineStops = (0...32).map { step -> Gradient.Stop in
                let x = Double(step) / 32
                return .init(color: settings.tint.opacity(settings.lineStrength * (settings.base + (1 - settings.base) * pow(x, settings.curve))), location: x)
            }
            let core = Path(CGRect(x: 0, y: size.height - settings.thickness, width: end, height: settings.thickness))
            context.fill(core, with: .linearGradient(Gradient(stops: lineStops), startPoint: .zero, endPoint: CGPoint(x: end, y: 0)))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct AddressPreview: View {
    let settings: GlowSettings
    let progress: Double
    let visibility: Double

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "globe").frame(width: 28)
            Text("127.0.0.1").frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: 13))
        .foregroundStyle(settings.dark ? Color.white.opacity(0.85) : Color.black.opacity(0.7))
        .padding(.horizontal, 4)
        .frame(height: 32)
        .background(settings.dark ? Color(white: 0.155) : Color(white: 0.95))
        .overlay {
            UpwardLight(settings: settings, progress: progress).opacity(visibility)
        }
        // Clip the whole light field to the address bar, not to the loaded span.
        .clipShape(RoundedRectangle(cornerRadius: settings.radius, style: .continuous))
    }
}

struct GlowLab: View {
    @State private var settings = GlowSettings()
    @State private var choices: [SavedGlow] = []
    @State private var choiceName = "My glow"
    @State private var notice = "Changes stay in this preview. Save a choice when it feels right."
    @State private var state = "Loading"
    @State private var visibility = 1.0
    @State private var replayID = 0
    @State private var playing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let dataURL = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("choices.json")
    private let referenceURL = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("dia-address-crop.png")
    private let colors: [(String, Double, Double, Double)] = [
        ("Blue", 0.16, 0.46, 0.96), ("Dia gold", 0.877, 0.693, 0.0065),
        ("Orange", 0.96, 0.43, 0.12), ("Green", 0.18, 0.66, 0.40),
        ("Purple", 0.61, 0.36, 0.94), ("Pink", 0.94, 0.30, 0.57)
    ]

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Loading light").font(.largeTitle.bold())
                        Text("Tune the light. Save the version you want in Cove.").foregroundStyle(.secondary)
                    }
                    HStack(spacing: 8) {
                        ForEach(["Soft lift", "Wide wash", "Near strip"], id: \.self) { name in
                            Button(name) { applyPreset(name) }.controlSize(.large)
                        }
                        Spacer()
                        Toggle("Dark surface", isOn: $settings.dark).toggleStyle(.switch)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Your preview").font(.headline)
                            Spacer()
                            Text("Native size · 32 pt field").font(.caption).foregroundStyle(.secondary)
                        }
                        VStack(spacing: 0) {
                            HStack(spacing: 4) {
                                ForEach(["sidebar.left", "chevron.left", "chevron.right", playing ? "xmark" : "arrow.clockwise"], id: \.self) { symbol in
                                    Image(systemName: symbol).frame(width: 28, height: 28)
                                }
                                AddressPreview(settings: settings, progress: settings.progress, visibility: visibility)
                            }
                            .foregroundStyle(settings.dark ? Color.white.opacity(0.7) : Color.black.opacity(0.6))
                            .padding(8)
                            .background(settings.dark ? Color(white: 0.12) : Color(white: 0.985))
                            VStack(alignment: .leading, spacing: 10) {
                                Text(state == "Complete" ? "Page ready" : "A place for your next idea.").font(.title2.weight(.semibold))
                                Text("Watch the light at the base of the address bar.")
                                    .foregroundStyle(.secondary)
                                Spacer(minLength: 32)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(28)
                            .foregroundStyle(settings.dark ? Color.white : Color.black)
                            .background(settings.dark ? Color(white: 0.09) : Color.white)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.primary.opacity(0.08)))

                        HStack {
                            Button(playing ? "Restart load" : "Replay load", systemImage: "play.fill") {
                                playing = true; replayID += 1
                            }.buttonStyle(.borderedProminent)
                            Picker("State", selection: Binding(get: { state }, set: { value in
                                state = value; updateState(value)
                            })) {
                                ForEach(["Loading", "Complete", "Stopped", "Idle"], id: \.self) { Text($0) }
                            }.frame(width: 240)
                            Spacer()
                            Text("\(Int(settings.progress * 100))% loaded").monospacedDigit().foregroundStyle(.secondary)
                        }
                        Slider(value: $settings.progress, in: 0...1, onEditingChanged: { editing in
                            if editing { cancelReplay(); state = "Loading"; visibility = 1 }
                        }).accessibilityLabel("Loading progress")
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Dia reference").font(.headline)
                            Spacer()
                            Button("Match color & progress") {
                                cancelReplay(); state = "Loading"; visibility = 1
                                settings.red = 0.877; settings.green = 0.693; settings.blue = 0.0065
                                settings.dark = false; settings.progress = 0.724
                            }
                        }
                        if let image = NSImage(contentsOf: referenceURL) {
                            Image(nsImage: image).resizable().frame(height: 36)
                                .padding(.leading, 136).padding(.trailing, 8)
                                .accessibilityLabel("Actual Dia gold loading screenshot")
                        }
                        Text("Actual capture · Work theme · width fitted, original height. The reference does not change with the controls.")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Saved choices").font(.headline)
                            Spacer()
                            Button("Copy settings") { copySettings() }
                        }
                        HStack {
                            TextField("Choice name", text: $choiceName)
                                .textFieldStyle(.roundedBorder)
                            Button("Save choice") { saveChoice() }
                                .disabled(choiceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        if choices.isEmpty {
                            Text("Save a few versions, then switch between them here.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(choices) { choice in
                                HStack {
                                    Circle().fill(choice.settings.tint).frame(width: 10, height: 10)
                                    Text(choice.name)
                                    Spacer()
                                    Text("Rise \(Int(choice.settings.spread)) · Strength \(Int(choice.settings.strength * 100))%")
                                        .font(.caption).foregroundStyle(.secondary)
                                    Button("Load \(choice.name)") {
                                        cancelReplay(); settings = choice.settings; state = "Loading"; visibility = 1
                                        notice = "Loaded \(choice.name)."
                                    }
                                }
                            }
                        }
                        Text(notice).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                    Text("Soft lift: broad, low light.  Wide wash: more height, less strength.  Near strip: a closer, stronger glow.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(28)
            }
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Light controls").font(.title2.bold())
                    Text("Light stays above the strip. The rounded field cuts the left edge.")
                        .font(.callout).foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Theme color").font(.headline)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(colors, id: \.0) { color in
                                Button {
                                    settings.red = color.1; settings.green = color.2; settings.blue = color.3
                                } label: {
                                    VStack(spacing: 5) {
                                        Circle().fill(Color(red: color.1, green: color.2, blue: color.3)).frame(width: 22, height: 22)
                                        Text(color.0).font(.caption)
                                    }.frame(maxWidth: .infinity).padding(.vertical, 5)
                                }.buttonStyle(.bordered).accessibilityLabel(color.0)
                            }
                        }
                        ColorPicker("Custom color", selection: Binding(get: { settings.tint }, set: { color in
                            guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return }
                            settings.red = rgb.redComponent; settings.green = rgb.greenComponent; settings.blue = rgb.blueComponent
                        }), supportsOpacity: false)
                    }
                    control("Upward spread", value: $settings.spread, range: 8...48, suffix: " pt", detail: "How far light rises into the field.")
                    control("Glow strength", value: $settings.strength, range: 0.03...0.45, scale: 100, suffix: "%", detail: "Brightness of the broad light.")
                    control("Right spill", value: $settings.rightSpread, range: 0...24, suffix: " pt", detail: "How far soft light wraps around the tip.")
                    control("Left brightness", value: $settings.base, range: 0.15...0.95, scale: 100, suffix: "%", detail: "Keeps light visible across the loaded span.")
                    control("Rise curve", value: $settings.curve, range: 0.5...3, decimals: 1, detail: "Higher values keep the increase near the end.")
                    control("Line brightness", value: $settings.lineStrength, range: 0.3...1, scale: 100, suffix: "%")
                    control("Line thickness", value: $settings.thickness, range: 0.5...2, decimals: 1, suffix: " pt")
                    control("Corner radius", value: $settings.radius, range: 4...16, suffix: " pt")
                    Button("Reset to Soft lift") { applyPreset("Soft lift") }
                }.padding(24)
            }.frame(width: 320)
        }
        .frame(minWidth: 1060, minHeight: 740)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { loadChoices() }
        .task(id: replayID) {
            guard playing else { return }
            state = "Loading"; visibility = 1; settings.progress = 0.02
            do {
                for next in [0.12, 0.32, 0.50, 0.64, 0.72, 0.82, 0.91, 1.0] {
                    try await Task.sleep(for: .milliseconds(next == 0.72 ? 1400 : 650))
                    try Task.checkCancellation()
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { settings.progress = next }
                }
                try await Task.sleep(for: .milliseconds(200))
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { visibility = 0 }
                playing = false; state = "Complete"
            } catch { /* A new run or user edit superseded this replay. */ }
        }
    }

    private func control(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, scale: Double = 1, decimals: Int = 0, suffix: String = "", detail: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title).fontWeight(.medium)
                Spacer()
                Text(String(format: "%.*f", decimals, value.wrappedValue * scale) + suffix)
                    .monospacedDigit().foregroundStyle(.secondary)
            }
            Slider(value: value, in: range).accessibilityLabel(title)
            if let detail { Text(detail).font(.caption).foregroundStyle(.secondary) }
        }
    }

    private func cancelReplay() { playing = false; replayID += 1 }
    private func updateState(_ value: String) {
        cancelReplay()
        if value == "Complete" { settings.progress = 1 }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { visibility = value == "Loading" ? 1 : 0 }
    }
    private func applyPreset(_ name: String) {
        cancelReplay()
        let old = settings
        settings = .preset(name)
        settings.red = old.red; settings.green = old.green; settings.blue = old.blue
        settings.dark = old.dark; settings.progress = old.progress
        state = "Loading"; visibility = 1
        notice = "\(name) loaded. Color and progress kept."
    }
    private func loadChoices() {
        guard FileManager.default.fileExists(atPath: dataURL.path) else { return }
        do { choices = try JSONDecoder().decode([SavedGlow].self, from: Data(contentsOf: dataURL)) }
        catch { notice = "Could not read saved choices: \(error.localizedDescription)" }
    }
    private func saveChoice() {
        let name = choiceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let choice = SavedGlow(name: name, settings: settings)
        do {
            let updated = choices + [choice]
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(updated).write(to: dataURL, options: .atomic)
            choices = updated
            notice = "Saved \(name). Choices stay available after closing this window."
            choiceName = "Choice \(choices.count + 1)"
        } catch { notice = "Could not save: \(error.localizedDescription)" }
    }
    private func copySettings() {
        do {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(settings)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(String(decoding: data, as: UTF8.self), forType: .string)
            notice = "Settings copied. Paste them into this chat, or save a named choice."
        } catch { notice = "Could not copy settings: \(error.localizedDescription)" }
    }
}

@main
struct GlowLabApp: App {
    var body: some Scene {
        Window("Cove · Loading Light Lab", id: "glow-lab") {
            GlowLab()
        }
        .defaultSize(width: 1320, height: 850)
        .windowResizability(.contentMinSize)
    }
}
