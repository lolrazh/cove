import SwiftUI

/// A small live editor. Closing the popover keeps the name and color.
struct SpaceEditor: View {
    @ObservedObject var store: SpaceStore
    let spaceID: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @FocusState private var isNameFocused: Bool

    private let columns = Array(repeating: GridItem(.fixed(32), spacing: 4), count: 8)

    var body: some View {
        if let space = store.spaces.space(spaceID) {
            VStack(alignment: .leading, spacing: 16) {
                TextField("Name", text: $name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .medium))
                    .padding(10)
                    .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(isNameFocused ? Color.accentColor : .clear, lineWidth: 1)
                    }
                    .accessibilityLabel("Space name")
                    .focused($isNameFocused)
                    .onChange(of: name) { _, value in
                        update { $0.name = value }
                    }
                    .onSubmit { dismiss() }

                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(Array(ChromeTheme.presets.enumerated()), id: \.offset) { index, theme in
                        colorChoice(theme, name: ChromeTheme.presetNames[index],
                                    selected: theme.rawValue == space.theme.rawValue)
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Theme colors")
            }
            .padding(16)
            .frame(width: 316)
            .background(Color(nsColor: .windowBackgroundColor))
            .onAppear {
                name = space.name
                isNameFocused = true
            }
        }
    }

    private func colorChoice(_ theme: ChromeTheme, name: String, selected: Bool) -> some View {
        Button { update { $0.theme = theme } } label: {
            Circle()
                .fill(LinearGradient(colors: [theme.palette.light, theme.palette.companion],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay { Circle().strokeBorder(.black.opacity(0.10)) }
                .overlay {
                    if selected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(3)
                            .background(.black.opacity(0.65), in: Circle())
                    }
                }
                .frame(width: 26, height: 26)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(ChromeButtonStyle(size: .accessory(side: 32)))
        .accessibilityLabel(name)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .help(name)
    }

    private func update(_ change: (inout Space) -> Void) {
        store.change { $0.update(spaceID, change) }
    }
}
