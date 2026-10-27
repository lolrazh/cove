import SwiftUI

/// Settings › Spaces: the spaces in their order, and the profiles they
/// browse as. Edits reach every window through the store.
struct SpacesSettingsPane: View {
    @ObservedObject var store: SpaceStore

    @State private var editing: Space?
    @State private var deletingSpace: Space?
    @State private var deletingProfile: Profile?

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(store.spaces.spaces) { space in
                        spaceRow(space)
                    }
                    .onMove { source, destination in
                        store.change { $0.moveSpaces(fromOffsets: source, toOffset: destination) }
                    }
                }
                Button("New Space") {
                    store.change { $0.addSpace() }
                }
            } header: {
                Text("Spaces")
            } footer: {
                Text("Drag to reorder. ⌃1 to ⌃9 switch between the first nine.")
            }

            Section {
                ForEach(store.spaces.profiles) { profile in
                    profileRow(profile)
                }
                Button("New Profile") {
                    store.change { $0.addProfile() }
                }
            } header: {
                Text("Profiles")
            } footer: {
                Text("Each profile keeps its own cookies, logins and site data. Spaces in a profile share its Favorites.")
            }
        }
        .sheet(item: $editing) { space in
            SpaceEditor(store: store, spaceID: space.id)
        }
        .confirmationDialog(
            "Delete \u{201C}\(deletingSpace?.name ?? "")\u{201D}?",
            isPresented: isPresent($deletingSpace),
            presenting: deletingSpace
        ) { space in
            Button("Delete Space", role: .destructive) {
                store.change { $0.removeSpace(space.id) }
            }
        } message: { _ in
            Text("Its open tabs move to the archive, and its pinned tabs are removed.")
        }
        .confirmationDialog(
            "Delete \u{201C}\(deletingProfile?.name ?? "")\u{201D}?",
            isPresented: isPresent($deletingProfile),
            presenting: deletingProfile
        ) { profile in
            Button("Delete Profile", role: .destructive) {
                store.deleteProfile(profile.id)
            }
        } message: { _ in
            Text("Its spaces and Favorites move to the default profile. Cookies, logins and other site data saved in it are deleted.")
        }
    }

    private func spaceRow(_ space: Space) -> some View {
        HStack(spacing: 10) {
            SpaceIconView(icon: space.icon)
                .foregroundStyle(space.theme.tint ?? .secondary)
                .frame(width: 20)
            Text(space.name)
            if store.spaces.profiles.count > 1 {
                Text(store.spaces.profile(space.profileID)?.name ?? "")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Edit…") { editing = space }
            Button {
                deletingSpace = space
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .disabled(store.spaces.spaces.count < 2)
            .help("Delete Space")
        }
    }

    private func profileRow(_ profile: Profile) -> some View {
        HStack(spacing: 10) {
            Image(systemName: ChromeSymbols.Spaces.profile)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            ProfileNameField(name: profile.name) { name in
                store.change { $0.renameProfile(profile.id, to: name) }
            }
            if !profile.isDefault {
                Button {
                    deletingProfile = profile
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Delete Profile")
            }
        }
    }

    private func isPresent<Item>(_ item: Binding<Item?>) -> Binding<Bool> {
        Binding(get: { item.wrappedValue != nil }, set: { if !$0 { item.wrappedValue = nil } })
    }
}

/// A profile's name, edited in place and kept on Return.
private struct ProfileNameField: View {
    let name: String
    let onRename: (String) -> Void

    @State private var draft = ""

    var body: some View {
        TextField("Name", text: $draft)
            .labelsHidden()
            .onSubmit { onRename(draft) }
            .onChange(of: name, initial: true) { _, name in draft = name }
    }
}
