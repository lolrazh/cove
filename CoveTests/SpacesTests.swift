import Foundation
import Testing
@testable import Cove

struct SpacesTests {
    @Test func `a first launch has one space in the default profile, in the old frame color`() {
        let theme = ChromeTheme(rawValue: "#5EA4E8")
        let spaces = Spaces(theme: theme)
        #expect(spaces.spaces.map(\.id) == [Space.defaultID])
        #expect(spaces.spaces[0].theme == theme)
        #expect(spaces.spaces[0].profileID == Profile.defaultID)
        #expect(spaces.profiles.map(\.id) == [Profile.defaultID])
    }

    @Test func `new spaces are numbered and wear a color no other space does`() {
        var spaces = Spaces(theme: ChromeTheme.presets[1])
        let second = spaces.addSpace()
        let third = spaces.addSpace()
        #expect(second.name == "Space 2")
        #expect(third.name == "Space 3")
        #expect(Set(spaces.spaces.map(\.theme)).count == 3)
        #expect(!spaces.spaces.contains { $0.theme == .system })
    }

    @Test func `a new space goes into the given profile, or the default for an unknown one`() {
        var spaces = Spaces()
        let work = spaces.addProfile()
        #expect(spaces.addSpace(in: work.id).profileID == work.id)
        #expect(spaces.addSpace(in: UUID()).profileID == Profile.defaultID)
    }

    @Test func `edits keep a name and a known profile`() {
        var spaces = Spaces()
        spaces.update(Space.defaultID) {
            $0.name = "  Work "
            $0.icon = .emoji("💼")
        }
        #expect(spaces.space(Space.defaultID)?.name == "Work")
        #expect(spaces.space(Space.defaultID)?.icon == .emoji("💼"))

        spaces.update(Space.defaultID) {
            $0.name = " "
            $0.profileID = UUID()
        }
        #expect(spaces.space(Space.defaultID)?.name == "Work")
        #expect(spaces.space(Space.defaultID)?.profileID == Profile.defaultID)
    }

    @Test func `the last space can't be removed`() {
        var spaces = Spaces()
        spaces.removeSpace(Space.defaultID)
        #expect(spaces.spaces.count == 1)

        let second = spaces.addSpace()
        spaces.removeSpace(Space.defaultID)
        #expect(spaces.spaces.map(\.id) == [second.id])
    }

    @Test func `spaces move within the list, and neighbors don't wrap`() {
        var spaces = Spaces()
        let second = spaces.addSpace()
        let third = spaces.addSpace()

        spaces.moveSpace(third.id, by: -5)
        #expect(spaces.spaces.map(\.id) == [third.id, Space.defaultID, second.id])

        #expect(spaces.space(1, from: third.id)?.id == Space.defaultID)
        #expect(spaces.space(-1, from: third.id) == nil)
        #expect(spaces.space(1, from: second.id) == nil)
    }

    @Test func `a removed profile's spaces move to the default profile, which stays`() {
        var spaces = Spaces()
        let work = spaces.addProfile()
        let space = spaces.addSpace(in: work.id)

        spaces.removeProfile(Profile.defaultID)
        #expect(spaces.profiles.count == 2)

        spaces.removeProfile(work.id)
        #expect(spaces.profiles.map(\.id) == [Profile.defaultID])
        #expect(spaces.space(space.id)?.profileID == Profile.defaultID)
    }

    @Test func `profiles rename, but never to nothing`() {
        var spaces = Spaces()
        spaces.renameProfile(Profile.defaultID, to: "Personal")
        spaces.renameProfile(Profile.defaultID, to: "")
        #expect(spaces.profile(Profile.defaultID)?.name == "Personal")
    }
}

struct PinLayoutTests {
    private let pin = Pin(id: UUID(), url: "https://example.com/", title: "Example")

    @Test func `pinned tabs are per space, favorites per profile`() {
        var layout = PinLayout()
        let work = UUID()
        let personal = PinScope.default
        let workSpace = PinScope(space: work, profile: Profile.defaultID)
        let otherProfile = PinScope(space: work, profile: UUID())

        layout[personal].add(pin, to: .favorites)
        let pinned = Pin(id: UUID(), url: "https://apple.com/", title: "Apple")
        layout[personal].add(pinned, to: .pinned)

        #expect(layout[workSpace].favorites == [pin])
        #expect(layout[workSpace].pinned.isEmpty)
        #expect(layout[otherProfile].favorites.isEmpty)
        #expect(layout.pin(pinned.id) == pinned)
    }

    @Test func `emptied sections leave nothing behind`() {
        var layout = PinLayout()
        layout[.default].add(pin, to: .pinned)
        layout[.default].remove(pin.id)
        #expect(layout == PinLayout())
    }

    @Test func `a pin's title changes wherever it is`() {
        var layout = PinLayout()
        let scope = PinScope(space: UUID(), profile: UUID())
        layout[scope].add(pin, to: .pinned)
        layout.update(pin.id) { $0.title = "Renamed" }
        #expect(layout[scope].pinned.tabs.first?.title == "Renamed")
    }

    @Test func `pins follow deleted spaces and profiles`() {
        var spaces = Spaces()
        let work = spaces.addProfile()
        let space = spaces.addSpace(in: work.id)
        let scope = PinScope(space: space.id, profile: work.id)
        var layout = PinLayout()
        layout[scope].add(pin, to: .favorites)
        layout[scope].add(Pin(id: UUID(), url: "https://apple.com/", title: "Apple"), to: .pinned)
        layout[.default].add(Pin(id: UUID(), url: "https://swift.org/", title: "Swift"), to: .favorites)

        spaces.removeSpace(space.id)
        spaces.removeProfile(work.id)
        layout.prune(to: spaces)

        #expect(layout[scope].pinned.isEmpty)
        #expect(layout[.default].favorites.map(\.title) == ["Swift", "Example"])
    }
}

struct SavedWindowTests {
    private let tab = SavedTab(url: "https://example.com/", title: "Example", customTitle: nil, interactionState: nil, lastUsedAt: nil)

    @Test func `a window keeps every space's Today and the space shown`() throws {
        let other = UUID()
        let pin = UUID()
        var window = SavedWindow(spaces: [
            SavedSpace(spaceID: Space.defaultID, tabs: [tab, tab], activeTabIndex: 1, activePinID: nil),
            SavedSpace(spaceID: other, tabs: [], activeTabIndex: nil, activePinID: pin),
        ], activeSpaceID: other)
        window.placement = WindowPlacement(frame: CGRect(x: 1, y: 2, width: 900, height: 700), isFullScreen: false)

        let decoded = try PropertyListDecoder().decode(SavedWindow.self, from: PropertyListEncoder().encode(window))
        #expect(decoded.activeSpaceID == other)
        #expect(decoded.spaces.map(\.spaceID) == [Space.defaultID, other])
        #expect(decoded.spaces[0].activeTabIndex == 1)
        #expect(decoded.spaces[1].activePinID == pin)
        #expect(decoded.placement?.frame.width == 900)
    }

    @Test func `a window saved before Spaces is the first space's`() throws {
        struct UnscopedWindow: Encodable {
            let tabs: [SavedTab]
            let activeTabIndex: Int
        }
        let data = try PropertyListEncoder().encode(UnscopedWindow(tabs: [tab], activeTabIndex: 0))
        let decoded = try PropertyListDecoder().decode(SavedWindow.self, from: data)
        #expect(decoded.activeSpaceID == Space.defaultID)
        #expect(decoded.spaces.map(\.spaceID) == [Space.defaultID])
        #expect(decoded.spaces[0].tabs.map(\.url) == [tab.url])
        #expect(decoded.spaces[0].activeTabIndex == 0)
    }
}

@MainActor
struct SpaceStoreTests {
    private let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CoveTests-\(UUID().uuidString)/spaces.plist")

    private func makeStore() -> SpaceStore {
        SpaceStore(fileURL: fileURL) { _ in
            Issue.record("No context is needed")
            return .standard(faviconStore: FaviconStore(readingThrough: FaviconStore()), extensions: ExtensionLibrary(directory: nil))
        }
    }

    @Test func `spaces and profiles come back from the file`() {
        let before = makeStore()
        var added: Space?
        before.change {
            let profile = $0.addProfile()
            added = $0.addSpace(in: profile.id)
        }

        let after = makeStore()
        #expect(after.spaces == before.spaces)
        #expect(after.spaces.space(added!.id)?.name == "Space 2")
    }

    @Test func `an unchanged edit isn't published`() {
        let store = makeStore()
        var publishes = 0
        let subscription = store.$spaces.dropFirst().sink { _ in publishes += 1 }
        store.change { $0.removeSpace(Space.defaultID) }
        #expect(publishes == 0)
        subscription.cancel()
    }
}
