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
        before.change { $0.add(pin, to: .pinned) }
        let tab = SavedTab(url: "https://example.com/docs", title: "Docs", customTitle: "Reading", interactionState: Data([1]), lastUsedAt: nil)
        before.record(tab, for: pin.id)
        before.record(tab, for: UUID())
        #expect(before.savedTab(for: pin.id)?.customTitle == "Reading")

        before.save()

        let after = PinStore(fileURL: fileURL)
        #expect(after.pins.pinned.tabs == [pin])
        #expect(after.savedTab(for: pin.id)?.url == "https://example.com/docs")
        #expect(after.savedTab(for: pin.id)?.interactionState == Data([1]))
    }

    @Test func `a removed pin's tab is forgotten and an unchanged layout is not republished`() {
        let store = PinStore(fileURL: fileURL)
        store.change { $0.add(pin, to: .favorites) }
        store.record(SavedTab(url: pin.url, title: "", customTitle: nil, interactionState: nil, lastUsedAt: nil), for: pin.id)

        var publishes = 0
        let subscription = store.$pins.dropFirst().sink { _ in publishes += 1 }
        store.change { $0.update(UUID()) { $0.title = "Nothing" } }
        #expect(publishes == 0)

        store.change { $0.remove(pin.id) }
        #expect(publishes == 1)
        #expect(store.savedTab(for: pin.id) == nil)
        subscription.cancel()
    }

    @Test func `without a file, nothing is kept`() {
        let store = PinStore(fileURL: nil)
        store.change { $0.add(pin, to: .pinned) }
        store.save()
        #expect(PinStore(fileURL: nil).pins == Pins())
    }
}
