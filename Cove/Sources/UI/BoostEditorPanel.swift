import SwiftUI

/// The Boost editor, floating at the page's trailing edge like Arc's: simple
/// controls first (a tint, a font, elements zapped away), then the code.
/// The page stays usable beside it, which zapping needs.
struct BoostEditorPanel: View {
    @ObservedObject var editor: BoostEditor
    let onClose: () -> Void

    @State private var showsCode = false
    @State private var controlsHeight: CGFloat = 0

    private enum Metrics {
        static let width: CGFloat = 300
        static let inset: CGFloat = 12
        static let codeHeight: CGFloat = 120
        static let swatch: CGFloat = 18
    }

    /// Tints to pick from in one click; the color well has the rest.
    private static let tints = ["#FF5F57", "#FF9F0A", "#FFD60A", "#30D158", "#40C8E0", "#0A84FF", "#BF5AF2", "#FF375F"]

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(Metrics.inset)

            Divider()

            // As tall as the controls, scrolling only when the page is shorter.
            ScrollView {
                controls.onGeometryChange(for: CGFloat.self, of: \.size.height) { controlsHeight = $0 }
            }
            .frame(maxHeight: controlsHeight)
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(width: Metrics.width)
        .chromeFloatingSurface(minimumRadius: ChromeRadius.tile)
        .padding(ChromeMetrics.cardInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .onExitCommand {
            editor.isZapping ? editor.stopZapping() : onClose()
        }
        .onDisappear(perform: editor.stopZapping)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: ChromeSymbols.Navigation.boost)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text("Boost")
                    .font(.headline)
                Text(editor.boost.domain)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 8)
            Toggle("Boost On", isOn: Binding(get: { editor.boost.isEnabled }, set: editor.setEnabled))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
                .help(editor.boost.isEnabled ? "Turn Off Boost" : "Turn On Boost")
            Button(action: onClose) {
                Image(systemName: ChromeSymbols.Tabs.close)
            }
            .buttonStyle(ChromeButtonStyle(size: .accessory(side: 22)))
            .help("Done")
        }
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle("Include subdomains", isOn: $editor.boost.includesSubdomains)
                .help("Also boost every site under \(editor.boost.domain)")

            section("Color") { tintPicker }
            section("Font") { fontPicker }
            section("Hidden Elements") { hiddenElements }
            code

            if editor.isSaved {
                Button("Delete Boost", role: .destructive) {
                    editor.delete()
                    onClose()
                }
                .buttonStyle(.link)
                .foregroundStyle(.red)
            }
        }
        .padding(Metrics.inset)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tintPicker: some View {
        HStack(spacing: 6) {
            swatch(nil)
            ForEach(Self.tints, id: \.self, content: swatch)
            ColorPicker("Custom Color", selection: customTint, supportsOpacity: false)
                .labelsHidden()
                .help("Custom Color")
        }
    }

    private func swatch(_ tint: String?) -> some View {
        Button {
            editor.boost.tint = tint
        } label: {
            Circle()
                .fill(tint.flatMap(Color.init(hex:)).map(AnyShapeStyle.init) ?? AnyShapeStyle(.fill.tertiary))
                .overlay {
                    if tint == nil {
                        Image(systemName: "slash.circle")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: Metrics.swatch, height: Metrics.swatch)
                .padding(2)
                .overlay {
                    Circle()
                        .stroke(Color.accentColor, lineWidth: 2)
                        .opacity(editor.boost.tint == tint ? 1 : 0)
                }
        }
        .buttonStyle(.plain)
        .help(tint == nil ? "No Color" : "")
    }

    private var customTint: Binding<Color> {
        Binding(
            get: { editor.boost.tint.flatMap(Color.init(hex:)) ?? .gray },
            set: { editor.boost.tint = $0.hex }
        )
    }

    private var fontPicker: some View {
        Picker("Font", selection: $editor.boost.font) {
            Text("The Site's Own").tag(Boost.Font?.none)
            Divider()
            ForEach(Boost.Font.allCases, id: \.self) { font in
                Text(font.name).tag(Boost.Font?.some(font))
            }
        }
        .labelsHidden()
        .fixedSize()
    }

    private var hiddenElements: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: editor.toggleZapping) {
                Label(editor.isZapping ? "Done Zapping" : "Zap Elements", systemImage: "bolt.fill")
            }
            .controlSize(.small)
            .help("Click elements on the page to hide them")

            if editor.isZapping {
                Text("Click anything on the page to hide it. Press Escape when you're done.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(editor.boost.hiddenElements, id: \.self) { selector in
                HStack(spacing: 4) {
                    Text(selector)
                        .font(.callout.monospaced())
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(selector)
                    Spacer(minLength: 4)
                    Button {
                        editor.unhide(selector)
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .buttonStyle(ChromeButtonStyle(size: .accessory(side: 20)))
                    .help("Show Again")
                }
            }
        }
    }

    private var code: some View {
        DisclosureGroup("Code", isExpanded: $showsCode) {
            VStack(alignment: .leading, spacing: 6) {
                Text("CSS")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                codeEditor($editor.boost.css)

                HStack {
                    Text("JavaScript")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Reload", action: editor.reload)
                        .buttonStyle(.link)
                        .font(.subheadline)
                        .help("Scripts run when the page loads")
                }
                .padding(.top, 6)
                codeEditor($editor.boost.script)
            }
            .padding(.top, 6)
        }
    }

    private func codeEditor(_ text: Binding<String>) -> some View {
        CodeEditor(text: text)
            .frame(height: Metrics.codeHeight)
            .chromeFieldStyle(focused: false, minimumRadius: ChromeRadius.accessory)
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            content()
        }
    }
}

private extension Color {
    /// A color written "#RRGGBB".
    init?(hex: String) {
        guard hex.hasPrefix("#"), hex.count == 7, let value = Int(hex.dropFirst(), radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    var hex: String? {
        guard let color = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        let value = [color.redComponent, color.greenComponent, color.blueComponent]
            .map { Int(($0 * 255).rounded()).clamped(to: 0...255) }
            .reduce(0) { $0 << 8 | $1 }
        return String(format: "#%06X", value)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
