import SwiftUI

/// A small live editor. Closing the popover keeps the name and color.
struct SpaceEditor: View {
    @ObservedObject var store: SpaceStore
    let spaceID: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @FocusState private var isNameFocused: Bool

    private let columns = Array(repeating: GridItem(.fixed(26), spacing: 4), count: 8)

    var body: some View {
        if let space = store.spaces.space(spaceID) {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Name", text: $name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
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
            .padding(12)
            .frame(width: 260)
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
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(2)
                            .background(.black.opacity(0.65), in: Circle())
                    }
                }
                .frame(width: 22, height: 22)
                .frame(width: 26, height: 26)
        }
        .buttonStyle(ChromeButtonStyle(size: .accessory(side: 26)))
        .accessibilityLabel(name)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .help(name)
    }

    private func update(_ change: (inout Space) -> Void) {
        store.change { $0.update(spaceID, change) }
    }
}
