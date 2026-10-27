import SwiftUI

/// The sidebar footer's spaces, as in Arc: an icon for each, the active one
/// lit. Click to switch; the context menu edits, moves or deletes.
struct SidebarSpaceIcons: View {
    @ObservedObject var tabManager: TabManager

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabManager.spaces) { space in
                let isActive = space.id == tabManager.activeSpaceID
                Button {
                    tabManager.switchToSpace(space.id)
                } label: {
                    SpaceIconView(icon: space.icon)
                        .foregroundStyle(isActive ? .primary : .secondary)
                        .opacity(isActive ? 1 : 0.55)
                }
                .buttonStyle(ChromeButtonStyle(size: .accessory(side: 22)))
                .help(space.name)
                .contextMenu {
                    SpaceActions(space: space, tabManager: tabManager)
                }
                .animation(ChromeMotion.hover, value: isActive)
            }
        }
    }
}

/// A space's name above its tabs, so a swipe shows which space arrived.
/// Double-click to edit it.
struct SidebarSpaceTitle: View {
    let space: Space
    @ObservedObject var tabManager: TabManager

    var body: some View {
        HStack(spacing: 8) {
            SpaceIconView(icon: space.icon)
                .frame(width: 16)
            Text(space.name)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .font(.callout.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .frame(height: ChromeMetrics.sidebarRowHeight - 8)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { tabManager.spaceToEdit = space.id }
        .contextMenu {
            SpaceActions(space: space, tabManager: tabManager)
        }
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
                SpaceIconView(icon: space.icon)
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
