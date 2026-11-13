import Foundation
import Testing
@testable import Cove

struct ProfileMigrationTests {
    @Test func preservesTabsPinsSelectionAndOriginalFiles() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let first = UUID(uuidString: "C0FE0000-0000-4000-8000-000000000002")!
        let second = LegacySpace(id: UUID(), name: "Reading", theme: .system, profileID: Profile.defaultID)
        let other = LegacyProfile(id: UUID(), name: "Work")
        let third = LegacySpace(id: UUID(), name: "Work", theme: .system, profileID: other.id)
        let spaces = LegacySpaces(spaces: [LegacySpace(id: first, name: "Personal", theme: .system, profileID: Profile.defaultID), second, third], profiles: [LegacyProfile(id: Profile.defaultID, name: "Default"), other])
        let favorite = Pin(id: UUID(), url: "https://mail.example", title: "Mail")
        let pin = Pin(id: UUID(), url: "https://work.example", title: "Work")
        let pins = LegacyLayout(favorites: [Profile.defaultID: [favorite]], pinned: [third.id: SidebarTree([.tab(pin)])])
        struct SavedPins: Encodable { let layout: LegacyLayout; let tabs: [String: SavedTab] }
        let tab = SavedTab(url: "https://example.com", title: "Example", customTitle: "My name",
                           interactionState: Data([1, 2, 3]), lastUsedAt: Date(timeIntervalSince1970: 123))
        let doc = UUID()
        let window = LegacyWindow(spaces: [
            LegacySession(spaceID: first, tabs: [tab], activeTabIndex: 0, activePinID: nil,
                       documents: [TodayDocumentPlace(id: doc, index: 1)]),
            LegacySession(spaceID: second.id, tabs: [tab, tab], activeTabIndex: 1, activePinID: nil,
                       splits: [TabSplit(panes: [0, 1])]),
            LegacySession(spaceID: third.id, tabs: [tab], activeTabIndex: nil, activePinID: pin.id)
        ], activeSpaceID: second.id)
        let encoder = PropertyListEncoder()
        let originals = [
            "spaces.plist": try encoder.encode(spaces),
            "pins.plist": try encoder.encode(SavedPins(layout: pins, tabs: [favorite.id.uuidString: tab])),
            "session.plist": try encoder.encode([window])
        ]
        for (name, data) in originals { try data.write(to: root.appendingPathComponent(name)) }
        let output = try ProfileMigration.run(at: root)
        let decoder = PropertyListDecoder()
        let result = try decoder.decode([ProfileMigration.Window].self, from: Data(contentsOf: output.appendingPathComponent("session.plist")))
        let personal = try #require(result.first?.profiles.first { $0.profileID == Profile.defaultID })
        #expect(personal.tabs.count == 1)
        #expect(personal.activeTabIndex == 0)
        let secondProfile = try #require(result.first?.profiles.first { $0.profileID == second.id })
        #expect(secondProfile.activeTabIndex == 1)
        #expect(result.first?.activeProfileID == second.id)
        #expect(secondProfile.splits.first?.panes == [0, 1])
        #expect(personal.documents == [TodayDocumentPlace(id: doc, index: 1)])
        #expect(personal.tabs.allSatisfy { $0.interactionState == tab.interactionState && $0.customTitle == tab.customTitle })
        let savedPins = try decoder.decode(ProfileMigration.PinFile.self, from: Data(contentsOf: output.appendingPathComponent("pins.plist")))
        #expect(savedPins.layout.pinned[Profile.defaultID]?.tabs.map(\.id) == [favorite.id])
        #expect(savedPins.layout.pinned[other.id]?.tabs.map(\.id) == [pin.id])
        let copied = try #require(savedPins.layout.pinned[second.id]?.tabs.first)
        #expect(copied.id != favorite.id)
        #expect(copied.url == favorite.url)
        #expect(savedPins.tabs[copied.id.uuidString]?.interactionState == tab.interactionState)
        #expect(savedPins.tabs[favorite.id.uuidString]?.interactionState == tab.interactionState)
        for (name, data) in originals { #expect(try Data(contentsOf: root.appendingPathComponent(name)) == data) }
        // A second run must not replay the old session over new browsing.
        let changed = Data("new session".utf8)
        try changed.write(to: output.appendingPathComponent("session.plist"))
        #expect(try ProfileMigration.run(at: root).path == output.path)
        #expect(try Data(contentsOf: output.appendingPathComponent("session.plist")) == changed)
    }

    @Test func invalidSourceDoesNotPublishOrModifyAnything() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let broken = Data("not a plist".utf8)
        try broken.write(to: root.appendingPathComponent("pins.plist"))
        #expect(throws: (any Error).self) { try ProfileMigration.run(at: root) }
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("Profiles-v1").path))
        #expect(try Data(contentsOf: root.appendingPathComponent("pins.plist")) == broken)
    }
}

private struct LegacyProfile: Encodable { let id: UUID; let name: String }
private struct LegacySpace: Encodable { let id: UUID; let name: String; let theme: ChromeTheme; let profileID: UUID }
private struct LegacySpaces: Encodable { let spaces: [LegacySpace]; let profiles: [LegacyProfile] }
private struct LegacyLayout: Encodable { let favorites: [UUID: [Pin]]; let pinned: [UUID: SidebarTree<Pin>] }
private struct LegacySession: Encodable {
    let spaceID: UUID
    let tabs: [SavedTab]
    let activeTabIndex: Int?
    let activePinID: UUID?
    var splits: [TabSplit<Int>]? = nil
    var documents: [TodayDocumentPlace]? = nil
}
private struct LegacyWindow: Encodable { let spaces: [LegacySession]; let activeSpaceID: UUID }
