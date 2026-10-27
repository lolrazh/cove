import SwiftUI

/// Names and dresses a space: its name, icon, frame color and profile. The
/// icon, color and profile apply as they're picked, so the frame behind the
/// sheet shows the color while choosing; the name is kept on Return or Done.
struct SpaceEditor: View {
    @ObservedObject var store: SpaceStore
    let spaceID: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var emoji = ""
    @FocusState private var isNameFocused: Bool

    private let iconColumns = Array(repeating: GridItem(.fixed(28), spacing: 6), count: 8)

    var body: some View {
        if let space = store.spaces.space(spaceID) {
            VStack(spacing: 0) {
                form(space)
                HStack {
                    Spacer()
                    Button("Done", action: finish)
                        .keyboardShortcut(.defaultAction)
                }
                .padding([.horizontal, .bottom], 20)
            }
            .frame(width: 420)
            .onAppear {
                name = space.name
                isNameFocused = true
                if case .emoji(let current) = space.icon { emoji = current }
            }
        }
    }

    private func form(_ space: Space) -> some View {
        Form {
            Section {
                TextField("Name", text: $name)
                    .focused($isNameFocused)
                    .onSubmit(finish)
            }

            Section("Icon") {
                LazyVGrid(columns: iconColumns, spacing: 6) {
                    ForEach(SpaceIcon.symbols, id: \.self) { icon in
                        IconChoice(icon: icon, isSelected: icon == space.icon) {
                            update { $0.icon = icon }
                        }
                    }
                }
                TextField("Emoji", text: $emoji, prompt: Text("Type or paste one"))
                    .onChange(of: emoji) { _, typed in
                        guard let character = typed.last(where: \.isEmoji) else { return }
                        if emoji != String(character) { emoji = String(character) }
                        update { $0.icon = .emoji(String(character)) }
                    }
            }

            Section("Color") {
                HStack(spacing: 10) {
                    ForEach(ChromeTheme.presets, id: \.self) { theme in
                        ThemeSwatch(theme: theme, isSelected: theme == space.theme) {
                            update { $0.theme = theme }
                        }
                    }
                }
                ColorPicker("Custom color", selection: customTint(space), supportsOpacity: false)
            }

            Section {
                Picker("Profile", selection: profileBinding(space)) {
                    ForEach(store.spaces.profiles) { profile in
                        Text(profile.name).tag(profile.id)
                    }
                }
            } footer: {
                Text("Spaces in the same profile share cookies, logins and Favorites.")
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func update(_ change: (inout Space) -> Void) {
        store.change { $0.update(spaceID, change) }
    }

    private func finish() {
        update { $0.name = name }
        dismiss()
    }

    private func customTint(_ space: Space) -> Binding<Color> {
        Binding(
            get: { space.theme.tint ?? Color(nsColor: .underPageBackgroundColor) },
            set: { tint in update { $0.theme = ChromeTheme(tint: tint) } }
        )
    }

    private func profileBinding(_ space: Space) -> Binding<UUID> {
        Binding(get: { space.profileID }, set: { id in update { $0.profileID = id } })
    }
}

/// One of the editor's symbols, ringed in the accent color when chosen.
private struct IconChoice: View {
    let icon: SpaceIcon
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SpaceIconView(icon: icon)
                .frame(width: 28, height: 28)
                .background {
                    ConcentricRectangle.chrome(minimum: ChromeRadius.control)
                        .fill(isSelected ? AnyShapeStyle(ChromePalette.hover) : AnyShapeStyle(.clear))
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// One theme to pick: its tint as a disc, the system gray for none, with a
/// ring in the accent color around the selected one.
private struct ThemeSwatch: View {
    let theme: ChromeTheme
    let isSelected: Bool
    let action: () -> Void

    private let side: CGFloat = 22

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(theme.tint ?? Color(nsColor: .underPageBackgroundColor))
                .overlay {
                    Circle().strokeBorder(.separator)
                }
                .padding(3)
                .overlay {
                    Circle()
                        .strokeBorder(.tint, lineWidth: 2)
                        .opacity(isSelected ? 1 : 0)
                }
                .frame(width: side + 6, height: side + 6)
                .animation(ChromeMotion.hover, value: isSelected)
        }
        .buttonStyle(.plain)
        .help(theme.tint == nil ? "System" : "Color \(theme.rawValue)")
    }
}

private extension Character {
    /// Drawn as an emoji: digits and symbols that merely can be are left out.
    var isEmoji: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return scalar.properties.isEmojiPresentation || (unicodeScalars.count > 1 && scalar.properties.isEmoji)
    }
}
