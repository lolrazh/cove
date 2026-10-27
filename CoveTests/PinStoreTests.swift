import Foundation
import Testing
@testable import Cove

@MainActor
struct PinStoreTests {
    private let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CoveTests-\(UUID().uuidString)/pins.plist")

    private let pin = Pin(id: UUID(), url: "https://example.com/", title: "Example")

    @Test func `pins and their tabs come back from the file`() {
        let before = PinStore(fileURL: fileURL)
        before.change(in: .default) { $0.add(pin, to: .pinned) }
        let tab = SavedTab(url: "https://example.com/docs", title: "Docs", customTitle: "Reading", interactionState: Data([1]), lastUsedAt: nil)
        before.record(tab, for: pin.id)
        before.record(tab, for: UUID())
        #expect(before.savedTab(for: pin.id)?.customTitle == "Reading")

        before.save()

        let after = PinStore(fileURL: fileURL)
        #expect(after.pins(in: .default).pinned.tabs == [pin])
        #expect(after.savedTab(for: pin.id)?.url == "https://example.com/docs")
        #expect(after.savedTab(for: pin.id)?.interactionState == Data([1]))
    }

    @Test func `a removed pin's tab is forgotten and an unchanged layout is not republished`() {
        let store = PinStore(fileURL: fileURL)
        store.change(in: .default) { $0.add(pin, to: .favorites) }
        store.record(SavedTab(url: pin.url, title: "", customTitle: nil, interactionState: nil, lastUsedAt: nil), for: pin.id)

        var publishes = 0
        let subscription = store.$layout.dropFirst().sink { _ in publishes += 1 }
        store.change { $0.update(UUID()) { $0.title = "Nothing" } }
        #expect(publishes == 0)

        store.change(in: .default) { $0.remove(pin.id) }
        #expect(publishes == 1)
        #expect(store.savedTab(for: pin.id) == nil)
        subscription.cancel()
    }

    @Test func `pins saved before Spaces belong to the first space`() throws {
        struct UnscopedPins: Encodable {
            var pins: Pins
            var tabs: [String: SavedTab]
        }
        var pins = Pins()
        pins.add(pin, to: .pinned)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try PropertyListEncoder().encode(UnscopedPins(pins: pins, tabs: [:])).write(to: fileURL)

        let store = PinStore(fileURL: fileURL)
        #expect(store.pins(in: .default) == pins)
        #expect(store.pins(in: PinScope(space: UUID(), profile: Profile.defaultID)).pinned.isEmpty)
    }

    @Test func `without a file, nothing is kept`() {
        let store = PinStore(fileURL: nil)
        store.change(in: .default) { $0.add(pin, to: .pinned) }
        store.save()
        #expect(PinStore(fileURL: nil).layout == PinLayout())
    }
}
