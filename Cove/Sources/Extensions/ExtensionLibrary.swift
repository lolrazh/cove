import Foundation
import WebKit
import os

/// The extensions the user added, one list for the app: their files, copied
/// into Cove's folder when added so they keep working wherever the originals
/// go, whether each is on, and what each may do. Each profile's
/// `ExtensionHost` runs the ones that are on. Without a folder it keeps
/// nothing, which tests want.
@MainActor
final class ExtensionLibrary: ObservableObject {
    /// An extension copied in and read, waiting for the user to add it or
    /// not: what the review sheet shows.
    struct Candidate: Identifiable {
        let id: UUID
        let fileName: String
        let webExtension: WKWebExtension
    }

    /// In the order they were added.
    @Published private(set) var installed: [InstalledExtension]
    /// The extensions read from their files, ready to run, by ID.
    @Published private(set) var extensions: [UUID: WKWebExtension] = [:]
    /// Why an extension couldn't be read, by ID.
    @Published private(set) var failures: [UUID: String] = [:]
    /// Opens a browser window, private or not, for an extension's
    /// `windows.create`; set by the app, which alone can open scenes.
    var openBrowserWindow: ((_ isPrivate: Bool) -> Void)?

    private let directory: URL?
    private var windowWaiters: [CheckedContinuation<ExtensionWindow, Never>] = []
    private static let logger = Logger(subsystem: "com.cove.browser", category: "Extensions")

    init(directory: URL? = ExtensionLibrary.defaultDirectory) {
        self.directory = directory
        installed = StoreFile.read(directory.map(Self.listURL)) {
            try? PropertyListDecoder().decode([InstalledExtension].self, from: $0)
        } ?? []
    }

    static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Cove/Extensions")
    }

    private static func listURL(in directory: URL) -> URL {
        directory.appendingPathComponent("Extensions.plist")
    }

    /// Reads every added extension from its files, at launch, and removes
    /// files nothing refers to, like a candidate left when Cove quit.
    func loadInstalled() async {
        guard let directory else { return }
        let kept = Set(installed.map(\.fileName) + [Self.listURL(in: directory).lastPathComponent])
        let files = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        for file in files where !kept.contains(file) {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(file))
        }
        for record in installed {
            do {
                extensions[record.id] = try await WKWebExtension(resourceBaseURL: directory.appendingPathComponent(record.fileName))
            } catch {
                failures[record.id] = error.localizedDescription
                Self.logger.error("Couldn't load \(record.name, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - Adding and removing

    /// Copies an unpacked extension's folder, or a zip archive of one (a
    /// Firefox `.xpi` is one), into the library and reads it. Nothing is
    /// added until `install`; `discard` removes the copy.
    func prepare(from source: URL) async throws -> Candidate {
        guard let directory else { throw CocoaError(.fileWriteNoPermission) }
        let id = UUID()
        let isFolder = (try? source.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        let fileName = isFolder ? id.uuidString : "\(id.uuidString).zip"
        let copy = directory.appendingPathComponent(fileName)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: source, to: copy)
        do {
            let webExtension = try await WKWebExtension(resourceBaseURL: copy)
            return Candidate(id: id, fileName: fileName, webExtension: webExtension)
        } catch {
            try? FileManager.default.removeItem(at: copy)
            throw error
        }
    }

    /// Adds a candidate, allowed what it asked for: the user saw the list
    /// before choosing to add it, as with Chrome's install prompt.
    func install(_ candidate: Candidate) {
        let webExtension = candidate.webExtension
        var record = InstalledExtension(
            id: candidate.id,
            fileName: candidate.fileName,
            name: webExtension.displayName ?? candidate.fileName
        )
        record.granted = ExtensionGrants(requestedBy: webExtension)
        extensions[candidate.id] = webExtension
        installed.append(record)
        save()
    }

    func discard(_ candidate: Candidate) {
        directory.map { try? FileManager.default.removeItem(at: $0.appendingPathComponent(candidate.fileName)) }
    }

    /// Removes an extension and its files. Each host stops it and forgets
    /// what it stored.
    func remove(_ id: UUID) {
        guard let index = installed.firstIndex(where: { $0.id == id }) else { return }
        let record = installed.remove(at: index)
        extensions[id] = nil
        failures[id] = nil
        save()
        directory.map { try? FileManager.default.removeItem(at: $0.appendingPathComponent(record.fileName)) }
    }

    // MARK: - Changing

    func update(_ id: UUID, _ change: (inout InstalledExtension) -> Void) {
        guard let index = installed.firstIndex(where: { $0.id == id }) else { return }
        var record = installed[index]
        change(&record)
        guard record != installed[index] else { return }
        installed[index] = record
        save()
    }

    func record(_ id: UUID) -> InstalledExtension? {
        installed.first { $0.id == id }
    }

    // MARK: - Windows extensions open

    /// Opens a browser window for an extension and waits for it to appear.
    func openWindow(isPrivate: Bool) async -> ExtensionWindow? {
        guard let openBrowserWindow else { return nil }
        openBrowserWindow(isPrivate)
        return await withCheckedContinuation { windowWaiters.append($0) }
    }

    /// A browser window came on screen, which an extension may be waiting for.
    func windowDidAppear(_ window: ExtensionWindow) {
        guard !windowWaiters.isEmpty else { return }
        windowWaiters.removeFirst().resume(returning: window)
    }

    private func save() {
        guard let directory else { return }
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        guard let data = try? encoder.encode(installed) else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: Self.listURL(in: directory), options: .atomic)
    }
}
