import SwiftUI

struct ProfilesSettingsPane: View {
    @ObservedObject var store: ProfileStore
    @State private var editing: Profile?
    @State private var deleting: Profile?

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(store.profiles.profiles) { profile in
                        HStack(spacing: 10) {
                            ProfileIconView()
                                .foregroundStyle(profile.theme.tint ?? .secondary)
                                .frame(width: 20)
                            Text(profile.name)
                            Spacer()
                            Button("Edit…") { editing = profile }
                                .popover(isPresented: Binding(
                                    get: { editing?.id == profile.id },
                                    set: { if !$0 { editing = nil } }
                                )) { ProfileEditor(store: store, profileID: profile.id) }
                            Button { deleting = profile } label: { Image(systemName: "trash") }
                                .buttonStyle(.borderless)
                                .disabled(profile.isDefault)
                                .help("Delete Profile")
                        }
                    }
                    .onMove { source, destination in
                        store.change { $0.moveProfiles(fromOffsets: source, toOffset: destination) }
                    }
                }
                Button("New Profile") {
                    store.change { editing = $0.addProfile() }
                }
            } footer: {
                Text("Each profile keeps its own tabs, theme, history, and sign-ins. Drag to reorder.")
            }
        }
        .confirmationDialog("Delete \u{201C}\(deleting?.name ?? "")\u{201D}?", isPresented: Binding(
            get: { deleting != nil }, set: { if !$0 { deleting = nil } }
        ), presenting: deleting) { profile in
            Button("Delete Profile", role: .destructive) { store.deleteProfile(profile.id) }
        } message: { _ in
            Text("This deletes its tabs, history, and site data. Other profiles are not changed.")
        }
    }
}
