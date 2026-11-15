import SwiftUI

/// One destination, captured before the source picker opens.
struct BrowserImportDestination: Identifiable {
    let id: UUID
    let name: String
    let history: HistoryStore
    let historyIsEnabled: Bool
}

struct BrowserImportView: View {
    let destination: BrowserImportDestination
    let pins: PinStore
    let profileExists: () -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var source: BrowserImportSource = .safari
    @State private var preview: BrowserImportPreview?
    @State private var bookmarks = true
    @State private var history = true
    @State private var busy = false
    @State private var error: String?
    @State private var result: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(result == nil ? "Bring your browser with you" : "Ready to browse")
                    .font(.system(size: 22, weight: .semibold))
                Text("Import into \(destination.name)")
                    .font(.callout).foregroundStyle(.secondary)
            }
            if let result {
                Label(result, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            } else if let preview {
                VStack(spacing: 12) {
                    Toggle(isOn: $bookmarks) {
                        Label("\(count(preview.bookmarkCount, "bookmark")) · \(count(preview.folderCount, "folder"))", systemImage: "bookmark")
                    }.disabled(preview.bookmarkCount == 0)
                    Toggle(isOn: $history) {
                        Label(count(preview.historyCount, "history visit"), systemImage: "clock")
                    }.disabled(preview.historyCount == 0)
                }
                .toggleStyle(.checkbox)
                Text("Folders stay together. Existing items are skipped.")
                    .font(.callout).foregroundStyle(.secondary)
                if history && !destination.historyIsEnabled {
                    Text("History is off. Turn it on in Settings to see imported visits.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                if !preview.issues.isEmpty {
                    Text(preview.issues.joined(separator: "\n"))
                        .font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Picker("From", selection: $source) {
                    ForEach(BrowserImportSource.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden()
                Text("Choose a bookmarks export or a browser profile folder. Cove can read bookmarks and history from Safari, Chrome, and Dia.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let error {
                Text(error).font(.callout).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                if busy { ProgressView().controlSize(.small); Text("Reading…").foregroundStyle(.secondary) }
                Spacer()
                if result != nil {
                    Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
                } else {
                    Button(preview == nil ? "Not Now" : "Back") {
                        if preview == nil { dismiss() } else { preview = nil; error = nil }
                    }.keyboardShortcut(.cancelAction)
                    Button(preview == nil ? "Choose File or Folder…" : "Import") {
                        if preview == nil { chooseSource() } else { commitImport() }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(busy || (preview != nil && !hasSelection))
                }
            }
        }
        .padding(24).frame(width: 440)
        .interactiveDismissDisabled(busy)
    }

    private func count(_ value: Int, _ noun: String) -> String {
        "\(value) \(noun)\(value == 1 ? "" : "s")"
    }

    private var hasSelection: Bool {
        guard let preview else { return false }
        return (bookmarks && preview.bookmarkCount > 0) || (history && preview.historyCount > 0)
    }

    private func chooseSource() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Review Import"
        panel.message = "Choose an HTML bookmarks export, Bookmarks file, History database, or a browser profile folder."
        // No source data is read until the user selects it in this panel.
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            busy = true
            error = nil
            let selectedSource = source
            Task {
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() }; busy = false }
                do {
                    let loaded = try await Task.detached(priority: .userInitiated) {
                        try BrowserImportPreview.read(from: url, source: selectedSource)
                    }.value
                    preview = loaded
                    bookmarks = loaded.bookmarkCount > 0
                    history = loaded.historyCount > 0
                } catch { self.error = error.localizedDescription }
            }
        }
    }

    private func commitImport() {
        guard let preview, hasSelection else { return }
        guard profileExists() else { error = "This profile was deleted. Close this panel and choose another profile."; return }
        do {
            // History is transactional. Write it first, so a failed history write
            // leaves the bookmark selection available for a safe retry.
            let visits = history ? try destination.history.importVisits(preview.history) : 0
            let pages = bookmarks ? pins.importBookmarks(preview.bookmarks, from: preview.source.rawValue, into: destination.id) : 0
            result = "Imported \(count(pages, "bookmark")) and \(count(visits, "history visit"))."
            error = nil
        } catch { self.error = error.localizedDescription }
    }
}
