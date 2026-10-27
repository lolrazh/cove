import Foundation
import Testing
import WebKit
@testable import Cove

/// The library against the test extension in `Fixtures`, in a folder of its
/// own per test.
@MainActor
struct ExtensionLibraryTests {
    private let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("CoveTests-\(UUID().uuidString)/Extensions")

    private var fixture: URL {
        Bundle(for: BundleToken.self).url(forResource: "CoveTestExtension", withExtension: nil, subdirectory: "Fixtures")!
    }

    private func files() -> Set<String> {
        Set((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? [])
    }

    @Test func `an added extension is copied in, allowed what it asked for, and comes back`() async throws {
        let library = ExtensionLibrary(directory: directory)
        let candidate = try await library.prepare(from: fixture)
        #expect(candidate.webExtension.displayName == "Cove Test Extension")
        #expect(library.installed.isEmpty)

        library.install(candidate)
        let record = try #require(library.installed.first)
        #expect(record.name == "Cove Test Extension")
        #expect(record.isEnabled && !record.allowsPrivateBrowsing)
        #expect(Set(record.granted.permissions.keys) == ["storage", "tabs"])
        #expect(record.granted.sites.keys.contains("*://*/*"))
        #expect(files().contains(record.fileName))

        let relaunched = ExtensionLibrary(directory: directory)
        await relaunched.loadInstalled()
        #expect(relaunched.installed == [record])
        #expect(relaunched.extensions[record.id]?.displayName == "Cove Test Extension")
        #expect(relaunched.failures.isEmpty)
    }

    @Test func `a zip archive is kept as one and reads the same`() async throws {
        let archive = try zip(fixture)
        let library = ExtensionLibrary(directory: directory)
        let candidate = try await library.prepare(from: archive)
        #expect(candidate.fileName.hasSuffix(".zip"))
        #expect(candidate.webExtension.displayName == "Cove Test Extension")
    }

    @Test func `something that isn't an extension leaves nothing behind`() async throws {
        let library = ExtensionLibrary(directory: directory)
        let empty = directory.deletingLastPathComponent().appendingPathComponent("Empty")
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        await #expect(throws: (any Error).self) { try await library.prepare(from: empty) }
        #expect(files().isEmpty)
    }

    @Test func `a discarded candidate and a removed extension take their files with them`() async throws {
        let library = ExtensionLibrary(directory: directory)
        library.discard(try await library.prepare(from: fixture))
        #expect(files().isEmpty)

        let candidate = try await library.prepare(from: fixture)
        library.install(candidate)
        library.remove(candidate.id)
        #expect(library.installed.isEmpty)
        #expect(library.extensions.isEmpty)
        #expect(files() == ["Extensions.plist"])
        #expect(ExtensionLibrary(directory: directory).installed.isEmpty)
    }

    @Test func `files nothing refers to are swept at launch`() async throws {
        let library = ExtensionLibrary(directory: directory)
        let left = try await library.prepare(from: fixture)
        let kept = try await library.prepare(from: fixture)
        library.install(kept)

        await ExtensionLibrary(directory: directory).loadInstalled()
        #expect(!files().contains(left.fileName))
        #expect(files().contains(kept.fileName))
    }

    @Test func `edits that change nothing aren't saved`() async throws {
        let library = ExtensionLibrary(directory: directory)
        let candidate = try await library.prepare(from: fixture)
        library.install(candidate)
        var published = 0
        let watch = library.$installed.dropFirst().sink { _ in published += 1 }
        library.update(candidate.id) { $0.isEnabled = true }
        library.update(candidate.id) { $0.allowsPrivateBrowsing = true }
        #expect(published == 1)
        #expect(ExtensionLibrary(directory: directory).installed.first?.allowsPrivateBrowsing == true)
        watch.cancel()
    }

    /// A zip of a folder, the way Finder's Compress makes one.
    private func zip(_ folder: URL) throws -> URL {
        var archive: URL?
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: folder, options: .forUploading, error: &coordinationError) { zipped in
            let destination = directory.deletingLastPathComponent().appendingPathComponent("CoveTestExtension.zip")
            try? FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? FileManager.default.copyItem(at: zipped, to: destination)
            archive = destination
        }
        if let coordinationError { throw coordinationError }
        return try #require(archive)
    }
}

private final class BundleToken {}
