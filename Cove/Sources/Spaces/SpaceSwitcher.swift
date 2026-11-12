import SwiftUI

/// Compact space dots in the sidebar footer, with the active one emphasized.
/// Click to switch; the context menu edits, moves or deletes.
struct SidebarSpaceIcons: View {
    @ObservedObject var tabManager: TabManager
    @ObservedObject private var transition: SpaceTransition
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(tabManager: TabManager) {
        self.tabManager = tabManager
        self.transition = tabManager.spaceTransition
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabManager.spaces) { space in
                let weight = transition.state.weight(for: space.id, selected: tabManager.activeSpaceID)
                Button {
                    tabManager.switchToSpace(space.id)
                } label: {
                    SpaceIconView(diameter: 6)
                        .foregroundStyle(.primary)
                        .frame(height: 24)
                }
                .buttonStyle(ChromeButtonStyle(size: .accessory(side: 12), restingOpacity: 0.28 + 0.5 * weight))
                .accessibilityLabel(space.name)
                .accessibilityAddTraits(space.id == tabManager.activeSpaceID ? .isSelected : [])
                .help(space.name)
                .contextMenu { SpaceActions(space: space, tabManager: tabManager) }
            }
        }
        .animation(reduceMotion ? nil : ChromeMotion.spaceChange, value: tabManager.activeSpaceID)
    }
}

/// A space's name above its tabs, so a swipe shows which space arrived.
/// Click to edit its theme and details.
struct SidebarSpaceTitle: View {
    let space: Space
    @ObservedObject var tabManager: TabManager
    @ObservedObject private var transition: SpaceTransition

    init(space: Space, tabManager: TabManager) {
        self.space = space
        self.tabManager = tabManager
        self.transition = tabManager.spaceTransition
    }

    var body: some View {
        Button { tabManager.spaceToEdit = space.id } label: {
            ZStack(alignment: .leading) {
                ForEach(tabManager.spaces) { item in
                    Text(item.name)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .opacity(transition.state.weight(for: item.id, selected: space.id))
                        .accessibilityHidden(item.id != space.id)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: ChromeMetrics.sidebarRowHeight - 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Edit theme and space")
        .font(.callout.weight(.medium))
        .foregroundStyle(ChromePalette.onTheme)
        .accessibilityLabel("Edit theme for \(space.name)")
        .contextMenu { SpaceActions(space: space, tabManager: tabManager) }
        .animation(ChromeMotion.spaceChange, value: space.id)
    }
}

/// With tabs on top, the spaces sit at the strip's leading edge as one
/// button showing the active space's icon, opening a menu of all of them.
struct SpaceMenuButton: View {
    @ObservedObject var tabManager: TabManager

    var body: some View {
        if let space = tabManager.activeSpace {
            Menu {
                SpaceMenuItems(tabManager: tabManager)
            } label: {
                SpaceIconView()
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .buttonStyle(ChromeButtonStyle(size: .titlebar))
            .fixedSize()
            .help(space.name)
        }
    }
}

/// Every space to switch to, the active one checked, then New Space and Edit
/// Space: the strip's menu and the menu bar's Spaces menu.
struct SpaceMenuItems: View {
    @ObservedObject var tabManager: TabManager
    /// ⌃1 to ⌃9 on the first nine, in the menu bar only.
    var showsShortcuts = false

    var body: some View {
        ForEach(Array(tabManager.spaces.enumerated()), id: \.element.id) { index, space in
            Toggle(isOn: Binding(
                get: { space.id == tabManager.activeSpaceID },
                set: { _ in tabManager.switchToSpace(space.id) }
            )) {
                Text(space.name)
            }
            .keyboardShortcut(showsShortcuts && index < 9 ? KeyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .control) : nil)
        }

        Divider()

        Button("New Space", action: tabManager.newSpace)

        Button("Edit Space…") {
            tabManager.spaceToEdit = tabManager.activeSpaceID
        }
    }
}

/// What can be done to a space from its icon or title.
private struct SpaceActions: View {
    let space: Space
    @ObservedObject var tabManager: TabManager

    var body: some View {
        Button("Edit Space…") {
            tabManager.spaceToEdit = space.id
        }

        Button("Move Left") {
            tabManager.moveSpace(space.id, by: -1)
        }
        .disabled(tabManager.spaces.first?.id == space.id)

        Button("Move Right") {
            tabManager.moveSpace(space.id, by: 1)
        }
        .disabled(tabManager.spaces.last?.id == space.id)

        Divider()

        Button("Delete Space…") {
            tabManager.spaceToDelete = space.id
        }
        .disabled(tabManager.spaces.count < 2)
    }
}
