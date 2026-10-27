import SwiftUI
import UniformTypeIdentifiers
import WebKit

/// Settings › Extensions: the added extensions, each switched on or off,
/// allowed in private windows or not, with what it asked for and what it's
/// allowed; Load Unpacked… adds one from a folder or a zip archive. Changes
/// reach every profile through the library.
struct ExtensionsSettingsPane: View {
    @ObservedObject var library: ExtensionLibrary

    @State private var candidate: ExtensionLibrary.Candidate?
    @State private var failure: String?
    @State private var removing: InstalledExtension?

    var body: some View {
        Form {
            Section {
                if library.installed.isEmpty {
                    Text("No extensions yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(library.installed) { record in
                    ExtensionRow(record: record, webExtension: library.extensions[record.id], failure: library.failures[record.id], library: library) {
                        removing = record
                    }
                }
                Button("Load Unpacked\u{2026}", action: chooseExtension)
            } header: {
                Text("Extensions")
            } footer: {
                Text("Add an extension\u{2019}s folder, or a .zip or .xpi archive of one. Extensions built for Safari, Chrome and Firefox run on WebKit\u{2019}s extension support; stores like the Chrome Web Store can\u{2019}t install into Cove.")
            }
        }
        .sheet(item: $candidate) { candidate in
            ExtensionPermissionSheet(request: ExtensionPermissionRequest(installing: candidate.webExtension)) { isAdded in
                isAdded ? library.install(candidate) : library.discard(candidate)
                self.candidate = nil
            }
        }
        .alert("Couldn\u{2019}t Add Extension", isPresented: isPresent($failure), presenting: failure) { _ in
            Button("OK") {}
        } message: { failure in
            Text(failure)
        }
        .confirmationDialog(
            "Remove \u{201C}\(removing?.name ?? "")\u{201D}?",
            isPresented: isPresent($removing),
            presenting: removing
        ) { record in
            Button("Remove Extension", role: .destructive) {
                library.remove(record.id)
            }
        } message: { _ in
            Text("Its files and everything it stored are deleted.")
        }
    }

    private func chooseExtension() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.allowedContentTypes = [.folder, .zip] + [UTType(filenameExtension: "xpi")].compactMap { $0 }
        panel.message = "Choose an unpacked extension\u{2019}s folder, or a .zip or .xpi archive."
        panel.prompt = "Load"
        guard let window = NSApp.keyWindow else { return }
        Task {
            guard await panel.beginSheetModal(for: window) == .OK, let url = panel.url else { return }
            do {
                candidate = try await library.prepare(from: url)
            } catch {
                failure = error.localizedDescription
            }
        }
    }

    private func isPresent<Value>(_ value: Binding<Value?>) -> Binding<Bool> {
        Binding(get: { value.wrappedValue != nil }, set: { if !$0 { value.wrappedValue = nil } })
    }
}

/// One extension: icon, name, version and description, its switch, and
/// beneath, its private-window switch, permissions and sites.
private struct ExtensionRow: View {
    let record: InstalledExtension
    let webExtension: WKWebExtension?
    let failure: String?
    let library: ExtensionLibrary
    let onRemove: () -> Void

    var body: some View {
        DisclosureGroup {
            if let failure {
                Text(failure)
                    .foregroundStyle(.red)
            }
            Toggle("Allow in Private Windows", isOn: binding(\.allowsPrivateBrowsing))
            if !permissions.isEmpty {
                heading("Permissions")
                ForEach(permissions, id: \.self) { permission in
                    Toggle(isOn: permissionBinding(permission)) {
                        Text(permission)
                        if let description = ExtensionPermissionRequest.description(of: permission) {
                            Text(description)
                        }
                    }
                }
            }
            if !sites.isEmpty {
                heading("Websites")
                ForEach(sites, id: \.self) { site in
                    Toggle(isOn: siteBinding(site)) {
                        Text(ExtensionPermissionRequest.siteName(site))
                        Text(site)
                    }
                }
            }
            HStack {
                Spacer()
                Button("Remove Extension\u{2026}", role: .destructive, action: onRemove)
            }
        } label: {
            HStack(spacing: 10) {
                ExtensionIcon(image: webExtension?.icon(for: CGSize(width: 32, height: 32)), size: 28)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(webExtension?.displayName ?? record.name)
                        if let version = webExtension?.displayVersion ?? webExtension?.version {
                            Text(version)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let description = webExtension?.displayDescription {
                        Text(description)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
                Toggle("Enabled", isOn: binding(\.isEnabled))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .disabled(webExtension == nil)
            }
        }
    }

    private func heading(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
    }

    /// What it asks for, now or optionally, and anything else it was allowed.
    private var permissions: [String] {
        let asked = (webExtension?.requestedPermissions ?? []).union(webExtension?.optionalPermissions ?? []).map(\.rawValue)
        return Set(asked).union(record.granted.permissions.keys).sorted()
    }

    private var sites: [String] {
        let asked = (webExtension?.allRequestedMatchPatterns ?? []).union(webExtension?.optionalPermissionMatchPatterns ?? []).map(\.string)
        return Set(asked).union(record.granted.sites.keys).sorted()
    }

    private func binding(_ keyPath: WritableKeyPath<InstalledExtension, Bool>) -> Binding<Bool> {
        Binding(get: { record[keyPath: keyPath] }, set: { value in library.update(record.id) { $0[keyPath: keyPath] = value } })
    }

    private func permissionBinding(_ permission: String) -> Binding<Bool> {
        Binding(
            get: { record.granted.permissions[permission] != nil },
            set: { isAllowed in library.update(record.id) { $0.allow(permission: permission, isAllowed) } }
        )
    }

    private func siteBinding(_ site: String) -> Binding<Bool> {
        Binding(
            get: { record.granted.sites[site] != nil },
            set: { isAllowed in library.update(record.id) { $0.allow(site: site, isAllowed) } }
        )
    }
}
