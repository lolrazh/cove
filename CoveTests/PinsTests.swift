import Foundation
import Testing
@testable import Cove

struct PinsTests {
    @Test func movingPinsIntoAndOutOfFoldersPreservesOrder() {
        var pins = Pins()
        let a = Pin(id: UUID(), url: "https://a.test", title: "A")
        let b = Pin(id: UUID(), url: "https://b.test", title: "B")
        let folder = SidebarFolder<Pin>(name: "Reading")
        pins.add(a)
        pins.add(b)
        pins.addFolder(folder)
        pins.move(a.id, to: .pinned, at: .into(folder.id))
        #expect(pins.pinned.folder(folder.id)?.contents.tabs == [a])
        pins.move(a.id, to: .pinned, at: .before(b.id))
        #expect(pins.all == [a, b])
        let before = pins
        pins.move(a.id, to: .pinned, at: .into(UUID()))
        #expect(pins == before)
        #expect(pins.remove(a.id) == a)
        #expect(pins.all == [b])
    }
}

struct PinnedDocumentTests {
    @Test func `notes pin into Pinned and its folders`() {
        var pins = Pins()
        let note = UUID()
        let folder = SidebarFolder<Pin>(name: "Work")
        pins.addFolder(folder)
        pins.addDocument(note, at: .into(folder.id))
        #expect(pins.pinned.documents == [note])
        #expect(pins.section(of: note) == .pinned)
        #expect(pins.pinned.tabs.isEmpty)

        pins.move(note, to: .pinned, at: .end)
        #expect(pins.pinned.documents == [note])

        pins.removeDocument(note)
        #expect(pins.pinned.documents.isEmpty)
        #expect(pins.pinned.folder(folder.id) != nil)
    }

    @Test func `a deleted note is unpinned in every profile, and empty profiles are dropped`() {
        let note = UUID()
        let other = UUID()
        var layout = PinLayout()
        layout[Profile.defaultID].addDocument(note)
        layout[other].addDocument(note)
        layout[other].add(Pin(id: UUID(), url: "https://example.com/", title: "Example"), to: .pinned)

        layout.removeDocument(note)
        #expect(layout[Profile.defaultID].pinned.isEmpty)
        #expect(layout[other].pinned.documents.isEmpty)
        #expect(layout[other].pinned.tabs.count == 1)
        #expect(layout == {
            var expected = PinLayout()
            expected[other] = layout[other]
            return expected
        }())
    }
}
