import SwiftUI

/// Compact profile dots in the sidebar footer, with the active one emphasized.
/// Click to switch; the context menu edits, moves or deletes.
struct SidebarProfileIcons: View {
    @ObservedObject var tabManager: TabManager
    @ObservedObject private var transition: ProfileTransition
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(tabManager: TabManager) {
        self.tabManager = tabManager
        self.transition = tabManager.profileTransition
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabManager.profiles) { profile in
                let weight = transition.state.weight(for: profile.id, selected: tabManager.activeProfileID)
                Button {
                    tabManager.switchToProfile(profile.id)
                } label: {
                    ProfileIconView(diameter: 6)
                        .foregroundStyle(.primary)
                        .frame(height: 24)
                }
                .buttonStyle(ChromeButtonStyle(size: .accessory(side: 12), restingOpacity: 0.28 + 0.5 * weight))
                .accessibilityLabel(profile.name)
                .accessibilityAddTraits(profile.id == tabManager.activeProfileID ? .isSelected : [])
                .help(profile.name)
                .contextMenu { ProfileActions(profile: profile, tabManager: tabManager) }
            }
        }
        .animation(reduceMotion ? nil : ChromeMotion.profileChange, value: tabManager.activeProfileID)
    }
}

/// A profile's name above its tabs, so a swipe shows which profile arrived.
/// Click to edit its theme and details.
struct SidebarProfileTitle: View {
    let profile: Profile
    @ObservedObject var tabManager: TabManager
    @ObservedObject private var transition: ProfileTransition

    init(profile: Profile, tabManager: TabManager) {
        self.profile = profile
        self.tabManager = tabManager
        self.transition = tabManager.profileTransition
    }

    var body: some View {
        Button { tabManager.profileToEdit = tabManager.profileToEdit == profile.id ? nil : profile.id } label: {
            ZStack(alignment: .leading) {
                ForEach(tabManager.profiles) { item in
                    Text(item.name)
                        .lineLimit(1)
                        .opacity(transition.state.weight(for: item.id, selected: profile.id))
                        .accessibilityHidden(item.id != profile.id)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: ChromeMetrics.sidebarRowHeight - 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(ChromeButtonStyle(size: .accessory(side: 26)))
        .help("Edit theme and profile")
        .font(.callout.weight(.medium))
        .foregroundStyle(ChromePalette.onTheme)
        .accessibilityLabel("Edit theme for \(profile.name)")
        .contextMenu { ProfileActions(profile: profile, tabManager: tabManager) }
        .animation(ChromeMotion.profileChange, value: profile.id)
    }
}

/// With tabs on top, the profiles sit at the strip's leading edge as one
/// button showing the active profile's icon, opening a menu of all of them.
struct ProfileMenuButton: View {
    @ObservedObject var tabManager: TabManager

    var body: some View {
        if let profile = tabManager.activeProfile {
            Menu {
                ProfileMenuItems(tabManager: tabManager)
            } label: {
                ProfileIconView()
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .buttonStyle(ChromeButtonStyle(size: .titlebar))
            .fixedSize()
            .help(profile.name)
        }
    }
}

/// Every profile to switch to, the active one checked, then New Profile and Edit
/// Profile: the strip's menu and the menu bar's Profiles menu.
struct ProfileMenuItems: View {
    @ObservedObject var tabManager: TabManager
    /// ⌃1 to ⌃9 on the first nine, in the menu bar only.
    var showsShortcuts = false

    var body: some View {
        ForEach(Array(tabManager.profiles.enumerated()), id: \.element.id) { index, profile in
            Toggle(isOn: Binding(
                get: { profile.id == tabManager.activeProfileID },
                set: { _ in tabManager.switchToProfile(profile.id) }
            )) {
                Text(profile.name)
            }
            .keyboardShortcut(showsShortcuts && index < 9 ? KeyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .control) : nil)
        }

        Divider()

        Button("New Profile", action: tabManager.newProfile)

        Button("Edit Profile…") {
            tabManager.profileToEdit = tabManager.activeProfileID
        }
    }
}

/// What can be done to a profile from its icon or title.
private struct ProfileActions: View {
    let profile: Profile
    @ObservedObject var tabManager: TabManager

    var body: some View {
        Button("Edit Profile…") {
            tabManager.profileToEdit = profile.id
        }

        Button("Move Left") {
            tabManager.moveProfile(profile.id, by: -1)
        }
        .disabled(tabManager.profiles.first?.id == profile.id)

        Button("Move Right") {
            tabManager.moveProfile(profile.id, by: 1)
        }
        .disabled(tabManager.profiles.last?.id == profile.id)

        Divider()

        Button("Delete Profile…") {
            tabManager.profileToDelete = profile.id
        }
        .disabled(profile.isDefault)
    }
}
