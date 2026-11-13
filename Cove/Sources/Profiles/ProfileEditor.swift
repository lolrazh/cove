import SwiftUI
import AppKit

/// A small live editor. Closing the popover keeps the name and color.
struct ProfileEditor: View {
    @ObservedObject var store: ProfileStore
    let profileID: UUID
    var onClose: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @FocusState private var isNameFocused: Bool

    private let columns = Array(repeating: GridItem(.fixed(26), spacing: 4), count: 8)

    var body: some View {
        if let profile = store.profiles.profile(profileID) {
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
                    .accessibilityLabel("Profile name")
                    .focused($isNameFocused)
                    .onChange(of: name) { _, value in
                        update { $0.name = value }
                    }
                    .onSubmit { close() }

                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(Array(ChromeTheme.presets.enumerated()), id: \.offset) { index, theme in
                        colorChoice(theme, name: ChromeTheme.presetNames[index],
                                    selected: theme.rawValue == profile.theme.rawValue)
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Theme colors")
            }
            .padding(12)
            .frame(width: 260)
            .background(Color(nsColor: .windowBackgroundColor))
            .onExitCommand { close() }
            .onAppear {
                name = profile.name
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

    private func update(_ change: (inout Profile) -> Void) {
        store.change { $0.update(profileID, change) }
    }

    private func close() {
        if let onClose { onClose() } else { dismiss() }
    }
}

/// Only the visible profile control supplies an anchor to the window shell.
struct ProfileEditorAnchor: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? { nil }

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        if let next = nextValue() { value = next }
    }
}

/// A native transient popover with immediate presentation. The positioning view
/// stays in the shell while sidebar layouts change, so there is one presenter.
struct ProfileEditorPopover: NSViewRepresentable {
    let store: ProfileStore
    @Binding var profileID: UUID?
    let anchor: CGRect
    let canPresent: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> AnchorView { AnchorView() }

    func updateNSView(_ view: AnchorView, context: Context) {
        let coordinator = context.coordinator
        view.present = { [weak view, weak coordinator] in
            guard let view, let coordinator else { return }
            updatePopover(view, coordinator: coordinator)
        }
        view.present?()
    }

    private func updatePopover(_ view: NSView, coordinator: Coordinator) {
        coordinator.selection = $profileID
        guard let profileID else {
            coordinator.popover.close()
            return
        }
        guard canPresent, view.window != nil else { return }
        // SwiftUI's anchor is measured from the top; NSView's origin is below.
        let rect = CGRect(x: anchor.minX, y: view.bounds.height - anchor.maxY,
                          width: anchor.width, height: anchor.height)
        if coordinator.presentedID == profileID {
            coordinator.popover.positioningRect = rect
            return
        }
        coordinator.popover.close()
        coordinator.presentedID = profileID
        let host = NSHostingController(rootView: ProfileEditor(store: store, profileID: profileID) { [weak coordinator] in
            coordinator?.popover.performClose(nil)
        })
        coordinator.popover.contentViewController = host
        coordinator.popover.contentSize = host.view.fittingSize
        coordinator.popover.show(relativeTo: rect, of: view, preferredEdge: .minY)
    }

    static func dismantleNSView(_ view: AnchorView, coordinator: Coordinator) {
        view.present = nil
        coordinator.selection = nil
        coordinator.popover.close()
    }

    final class AnchorView: NSView {
        var present: (() -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window != nil else { return }
            // A revealed sidebar can replace the preference-backed host.
            // Retry after attachment, using the latest request and geometry.
            DispatchQueue.main.async { [weak self] in self?.present?() }
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSPopoverDelegate {
        let popover = NSPopover()
        var selection: Binding<UUID?>?
        var presentedID: UUID?

        override init() {
            super.init()
            popover.behavior = .transient
            popover.animates = false
            popover.delegate = self
        }

        func popoverDidClose(_ notification: Notification) {
            let closedID = presentedID
            presentedID = nil
            guard let selection else { return }
            // Closing may occur during a SwiftUI update. Clear only this
            // presentation, not a different profile opened in the same turn.
            DispatchQueue.main.async {
                if selection.wrappedValue == closedID { selection.wrappedValue = nil }
            }
        }
    }
}
