import Foundation

/// A one-time, copy-on-write migration. The old Cove directory is the backup.
/// Only a complete staged directory becomes live. A failed migration never
/// opens an empty store or changes the original files.
enum ProfileMigration {
    static var legacyRoot: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Cove")
    }

    static var root: URL { legacyRoot.appendingPathComponent("Profiles-v1") }

    struct ProfileRecord: Codable {
        let id: UUID
        let name: String
        let theme: ChromeTheme
    }
    struct ProfileList: Codable { let profiles: [ProfileRecord] }
    struct PinList: Codable { var pinned: [UUID: SidebarTree<Pin>] }
    struct PinFile: Codable { let layout: PinList; let tabs: [String: SavedTab] }
    struct ProfileSession: Codable {
        let profileID: UUID
        var tabs: [SavedTab] = []
        var activeTabIndex: Int?
        var activePinID: UUID?
        var splits: [TabSplit<Int>] = []
        var documents: [TodayDocumentPlace] = []
        var activeDocumentID: UUID?
    }
    struct Window: Codable {
        let profiles: [ProfileSession]
        let activeProfileID: UUID
        let placement: WindowPlacement?
    }

    private struct LegacyProfile: Decodable { let id: UUID; let name: String }
    private struct LegacySpace: Decodable {
        let id: UUID
        let name: String
        let theme: ChromeTheme
        let profileID: UUID
    }
    private struct LegacySpaces: Decodable {
        let spaces: [LegacySpace]
        let profiles: [LegacyProfile]
    }
    private struct LegacyPins: Decodable {
        struct Layout: Decodable {
            let favorites: [UUID: [Pin]]
            let pinned: [UUID: SidebarTree<Pin>]
        }
        struct Unscoped: Decodable { let favorites: [Pin]; let pinned: SidebarTree<Pin> }
        let layout: Layout?
        let pins: Unscoped?
        let tabs: [String: SavedTab]
    }
    private struct LegacySession: Decodable {
        let spaceID: UUID
        let tabs: [SavedTab]
        let activeTabIndex: Int?
        let activePinID: UUID?
        let splits: [TabSplit<Int>]?
        let documents: [TodayDocumentPlace]?
        let activeDocumentID: UUID?
    }
    private struct LegacyWindow: Decodable {
        let spaces: [LegacySession]?
        let activeSpaceID: UUID?
        let placement: WindowPlacement?
        let tabs: [SavedTab]?
        let activeTabIndex: Int?
    }

    enum Failure: Error { case missingProfile(UUID), missingSpace(UUID), duplicatePin(UUID) }

    /// Call before any store or WebKit context is opened.
    @discardableResult
    static func run(at source: URL = legacyRoot, initialTheme: ChromeTheme = .system) throws -> URL {
        let fm = FileManager.default
        let destination = source.appendingPathComponent("Profiles-v1", isDirectory: true)
        if fm.fileExists(atPath: destination.path) { return destination }
        try fm.createDirectory(at: source, withIntermediateDirectories: true)
        let stage = source.appendingPathComponent(".Profiles-v1-staging")
        if fm.fileExists(atPath: stage.path) { try fm.removeItem(at: stage) }
        try fm.createDirectory(at: stage, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: stage) }

        let defaultID = UUID(uuidString: "C0FE0000-0000-4000-8000-000000000001")!
        let firstSpaceID = UUID(uuidString: "C0FE0000-0000-4000-8000-000000000002")!
        let old = try read(LegacySpaces.self, "spaces.plist", at: source)
        let oldProfiles = old?.profiles ?? [LegacyProfile(id: defaultID, name: "Personal")]
        let oldSpaces = old?.spaces ?? [LegacySpace(id: firstSpaceID, name: "Personal", theme: initialTheme, profileID: defaultID)]
        let legacyIDs = Set(oldProfiles.map(\.id))
        for space in oldSpaces where !legacyIDs.contains(space.profileID) { throw Failure.missingProfile(space.profileID) }
        var used = Set<UUID>()
        var owners: [UUID: UUID] = [:]
        var profiles: [ProfileRecord] = []
        for space in oldSpaces {
            // The first space keeps the old login store. Every further space
            // becomes a profile with its own stable ID and empty login store.
            let id = used.insert(space.profileID).inserted ? space.profileID : space.id
            owners[space.id] = id
            profiles.append(ProfileRecord(id: id, name: space.name, theme: space.theme))
        }
        for profile in oldProfiles where !used.contains(profile.id) {
            profiles.append(ProfileRecord(id: profile.id, name: profile.name, theme: initialTheme))
        }
        func owner(_ space: UUID) throws -> UUID {
            guard let id = owners[space] else { throw Failure.missingSpace(space) }
            return id
        }

        let oldPins = try read(LegacyPins.self, "pins.plist", at: source)
        var pins = PinList(pinned: [:])
        let favorites = oldPins?.layout?.favorites ?? oldPins?.pins.map { [defaultID: $0.favorites] } ?? [:]
        var savedTabs = oldPins?.tabs ?? [:]
        var copiedFavorites = Set<UUID>()
        for profile in profiles {
            let legacyID = oldSpaces.first { owners[$0.id] == profile.id }?.profileID ?? profile.id
            let copy = !copiedFavorites.insert(legacyID).inserted
            let items = (favorites[legacyID] ?? []).map { pin -> SidebarItem<Pin> in
                guard copy else { return .tab(pin) }
                let id = UUID()
                savedTabs[id.uuidString] = savedTabs[pin.id.uuidString]
                return .tab(Pin(id: id, url: pin.url, title: pin.title))
            }
            pins.pinned[profile.id] = SidebarTree(items)
        }
        for id in favorites.keys where !legacyIDs.contains(id) { throw Failure.missingProfile(id) }
        let pinned = oldPins?.layout?.pinned ?? oldPins?.pins.map { [firstSpaceID: $0.pinned] } ?? [:]
        for (space, tree) in pinned {
            pins.pinned[try owner(space), default: SidebarTree()].items += tree.items
        }
        var pinIDs = Set<UUID>()
        for pin in pins.pinned.values.flatMap(\.tabs) where !pinIDs.insert(pin.id).inserted {
            throw Failure.duplicatePin(pin.id)
        }

        let oldWindows = try read([LegacyWindow].self, "session.plist", at: source) ?? []
        let windows = try oldWindows.map { window in
            let sessions = window.spaces ?? [LegacySession(spaceID: firstSpaceID, tabs: window.tabs ?? [],
                activeTabIndex: window.activeTabIndex, activePinID: nil, splits: nil, documents: nil, activeDocumentID: nil)]
            let activeSpace = window.activeSpaceID ?? firstSpaceID
            var merged: [UUID: ProfileSession] = [:]
            // Space order is stable; selection is taken from the shown space.
            let order = Dictionary(uniqueKeysWithValues: oldSpaces.enumerated().map { ($0.element.id, $0.offset) })
            for session in sessions.sorted(by: { order[$0.spaceID, default: .max] < order[$1.spaceID, default: .max] }) {
                let id = try owner(session.spaceID)
                var result = merged[id] ?? ProfileSession(profileID: id)
                let tabOffset = result.tabs.count
                let itemOffset = result.tabs.count + result.documents.count
                if merged[id] == nil || session.spaceID == activeSpace {
                    result.activeTabIndex = session.activeTabIndex.map { $0 + tabOffset }
                    result.activePinID = session.activePinID
                    result.activeDocumentID = session.activeDocumentID
                }
                result.tabs += session.tabs
                result.splits += (session.splits ?? []).compactMap { $0.map { $0 + tabOffset } }
                result.documents += (session.documents ?? []).map { TodayDocumentPlace(id: $0.id, index: $0.index + itemOffset) }
                merged[id] = result
            }
            return Window(profiles: profiles.compactMap { merged[$0.id] },
                          activeProfileID: try owner(activeSpace), placement: window.placement)
        }

        // Previously shared history, archive and unfiled documents stay in
        // Personal. They have no reliable old profile ownership to infer.
        let personal = stage.appendingPathComponent(defaultID.uuidString)
        try fm.createDirectory(at: personal, withIntermediateDirectories: true)
        let sharedNames = ["history.db", "archive.db", "favicons.db", "boosts.plist", "Documents"]
        for name in sharedNames {
            for suffix in name.hasSuffix(".db") ? ["", "-wal", "-shm"] : [""] {
                let file = source.appendingPathComponent(name + suffix)
                if fm.fileExists(atPath: file.path) {
                    try fm.copyItem(at: file, to: personal.appendingPathComponent(name + suffix))
                }
            }
        }
        // A document formerly used in another profile gets an independent
        // copy there. Its ID and contents remain intact.
        for profile in profiles where profile.id != defaultID {
            let directory = stage.appendingPathComponent(profile.id.uuidString)
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
            var documents = Set(pins.pinned[profile.id]?.documents ?? [])
            for session in windows.flatMap(\.profiles) where session.profileID == profile.id {
                documents.formUnion(session.documents.map(\.id))
            }
            try copyDocuments(documents, from: source, to: directory)
        }
        try write(ProfileList(profiles: profiles), "profiles.plist", at: stage)
        try write(PinFile(layout: pins, tabs: savedTabs), "pins.plist", at: stage)
        try write(windows, "session.plist", at: stage)
        try fm.moveItem(at: stage, to: destination)
        return destination
    }

    private static func copyDocuments(_ ids: Set<UUID>, from source: URL, to destination: URL) throws {
        guard !ids.isEmpty else { return }
        let folder = source.appendingPathComponent("Documents")
        guard let index = try read([DocumentInfo].self, "index.plist", at: folder) else { return }
        let target = destination.appendingPathComponent("Documents")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        let kept = index.filter { ids.contains($0.id) }
        for document in kept {
            let name = "\(document.id.uuidString).\(document.kind.fileExtension)"
            let file = folder.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: file.path) {
                try FileManager.default.copyItem(at: file, to: target.appendingPathComponent(name))
            }
        }
        try write(kept, "index.plist", at: target)
    }

    private static func read<T: Decodable>(_ type: T.Type, _ name: String, at directory: URL) throws -> T? {
        let url = directory.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try PropertyListDecoder().decode(type, from: Data(contentsOf: url))
    }

    private static func write<T: Encodable>(_ value: T, _ name: String, at directory: URL) throws {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        try encoder.encode(value).write(to: directory.appendingPathComponent(name), options: .atomic)
    }
}
