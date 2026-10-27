import AppKit
import Combine

/// Keeps the notes: an index of them, and each one's file beside it in
/// `Application Support/Cove/Documents`. One store for the app; what's open
/// is loaded once and shared by every window showing it. Without a directory
/// it keeps nothing, which is what tests want.
@MainActor
final class DocumentStore: ObservableObject {
    @Published private(set) var documents: [UUID: DocumentInfo]

    private let directory: URL?
    private var notes: [UUID: Note] = [:]
    private var pendingSave: Task<Void, Never>?
    private var terminationObserver: NSObjectProtocol?

    init(directory: URL? = DocumentStore.defaultDirectory) {
        self.directory = directory
        let index = directory?.appendingPathComponent("index.plist")
        let saved = StoreFile.read(index) { try? PropertyListDecoder().decode([DocumentInfo].self, from: $0) } ?? []
        documents = Dictionary(saved.map { ($0.id, $0) }) { first, _ in first }

        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.save() }
        }
    }

    static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Cove/Documents")
    }

    // MARK: - Documents

    func create(_ kind: DocumentKind) -> DocumentInfo {
        let document = DocumentInfo(kind: kind)
        documents[document.id] = document
        scheduleSave()
        return document
    }

    func rename(_ id: UUID, to title: String) {
        change(id) { $0.title = title }
    }

    /// The document is on screen: Today keeps it a while longer.
    func markUsed(_ id: UUID) {
        change(id) { $0.lastUsedAt = .now }
    }

    /// Deletes the document and its file for good.
    func delete(_ id: UUID) {
        guard let document = documents.removeValue(forKey: id) else { return }
        notes[id] = nil
        fileURL(for: document).map { try? FileManager.default.removeItem(at: $0) }
        scheduleSave()
    }

    /// The note's live text, loaded on first use.
    func note(_ id: UUID) -> Note? {
        if let note = notes[id] { return note }
        guard let document = documents[id], document.kind == .note else { return nil }
        let note = Note(id: id, fileURL: fileURL(for: document)) { [weak self] text in
            self?.change(id) {
                $0.text = text
                $0.modifiedAt = .now
            }
        }
        notes[id] = note
        return note
    }

    // MARK: - Saving

    private func change(_ id: UUID, _ change: (inout DocumentInfo) -> Void) {
        guard var document = documents[id] else { return }
        change(&document)
        guard document != documents[id] else { return }
        documents[id] = document
        scheduleSave()
    }

    private func fileURL(for document: DocumentInfo) -> URL? {
        directory?.appendingPathComponent("\(document.id.uuidString).\(document.kind.fileExtension)")
    }

    private func scheduleSave() {
        pendingSave?.cancel()
        pendingSave = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            self?.save()
        }
    }

    /// Saves the open documents and the index now. Changes otherwise save a
    /// second after the last of them.
    func save() {
        notes.values.forEach { $0.save() }
        pendingSave?.cancel()
        guard let directory else { return }
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        let index = documents.values.sorted { $0.createdAt < $1.createdAt }
        guard let data = try? encoder.encode(index) else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: directory.appendingPathComponent("index.plist"), options: .atomic)
    }
}
