import Foundation
import Testing
@testable import Cove

struct PinsTests {
    private let a = Pin(id: UUID(), url: "https://a.example/", title: "A")
    private let b = Pin(id: UUID(), url: "https://b.example/", title: "B")
    private let c = Pin(id: UUID(), url: "https://c.example/", title: "C")
    private let d = Pin(id: UUID(), url: "https://d.example/", title: "D")
    private let folder = SidebarFolder<Pin>(name: "Work")

    /// Favorites a, b; Pinned c, Work[d].
    private var pins: Pins {
        var pins = Pins()
        pins.add(a, to: .favorites)
        pins.add(b, to: .favorites)
        pins.add(c, to: .pinned)
        pins.addFolder(folder)
        pins.add(d, to: .pinned, at: .into(folder.id))
        return pins
    }

    private func titles(_ pins: [Pin]) -> String {
        pins.map(\.title).joined()
    }

    @Test func `pins are placed, found and removed by section`() {
        var pins = pins
        #expect(titles(pins.favorites) == "AB")
        #expect(titles(pins.pinned.tabs) == "CD")
        #expect(titles(pins.all) == "ABCD")
        #expect(pins.section(of: a.id) == .favorites)
        #expect(pins.section(of: d.id) == .pinned)
        #expect(pins.section(of: folder.id) == .pinned)
        #expect(pins.section(of: UUID()) == nil)

        #expect(pins.remove(a.id) == a)
        #expect(pins.remove(d.id) == d)
        #expect(pins.remove(folder.id) == nil)
        #expect(titles(pins.all) == "BC")
    }

    @Test func `moves between favorites and pinned, and a folder stays in pinned`() {
        var pins = pins
        pins.move(a.id, to: .pinned, at: .into(folder.id))
        #expect(titles(pins.favorites) == "B")
        #expect(titles(pins.pinned.folder(folder.id)!.contents.tabs) == "DA")

        pins.move(d.id, to: .favorites, at: .before(b.id))
        #expect(titles(pins.favorites) == "DB")
        #expect(titles(pins.pinned.tabs) == "CA")

        pins.move(folder.id, to: .favorites, at: .end)
        #expect(titles(pins.favorites) == "DB")
        #expect(pins.pinned.folder(folder.id) != nil)
    }

    @Test func `a drop lands on the side the drag came from`() {
        var down = pins
        down.move(a.id, onto: c.id)
        #expect(titles(down.favorites) == "B")
        #expect(titles(down.pinned.tabs) == "CAD")

        var up = pins
        up.move(c.id, onto: a.id)
        #expect(titles(up.favorites) == "CAB")
        #expect(titles(up.pinned.tabs) == "D")

        var within = pins
        within.move(b.id, onto: a.id)
        #expect(titles(within.favorites) == "BA")
    }

    @Test func `imported bookmarks become pins and folders, nesting kept`() throws {
        let imported: [ImportedBookmark] = [
            .page(title: "Example", url: URL(string: "https://example.com/")!),
            .folder(title: "Work", children: [
                .page(title: "Docs", url: URL(string: "https://docs.example/")!),
                .folder(title: "Deep", children: [.page(title: "Deeper", url: URL(string: "https://deep.example/")!)]),
            ]),
        ]
        let tree = SidebarTree(imported.map(SidebarItem.init))
        #expect(tree.tabs.map(\.title) == ["Example", "Docs", "Deeper"])
        #expect(tree.tabs.map(\.url) == ["https://example.com/", "https://docs.example/", "https://deep.example/"])
        #expect(tree.folders.map(\.name) == ["Work", "Deep"])
        let work = try #require(tree.folders.first)
        #expect(work.contents.tabs.map(\.title) == ["Docs", "Deeper"])
    }

    @Test func `a pin's title is updated in place and a deleted folder gives back its pins`() {
        var pins = pins
        pins.update(d.id) { $0.title = "Docs" }
        pins.update(a.id) { $0.title = "Apple" }
        #expect(titles(pins.all) == "AppleBCDocs")

        pins.updateFolder(folder.id) { $0.isCollapsed = true }
        #expect(pins.pinned.folder(folder.id)?.isCollapsed == true)

        #expect(pins.removeFolder(folder.id).map(\.title) == ["Docs"])
        #expect(titles(pins.pinned.tabs) == "C")
    }
}

struct PinnedDocumentTests {
    @Test func `notes pin into Pinned and its folders, never Favorites`() {
        var pins = Pins()
        let note = UUID()
        let folder = SidebarFolder<Pin>(name: "Work")
        pins.addFolder(folder)
        pins.addDocument(note, at: .into(folder.id))
        #expect(pins.pinned.documents == [note])
        #expect(pins.section(of: note) == .pinned)
        #expect(pins.pinned.tabs.isEmpty)

        pins.move(note, to: .favorites, at: .end)
        #expect(pins.favorites.isEmpty)
        #expect(pins.pinned.documents == [note])

        pins.removeDocument(note)
        #expect(pins.pinned.documents.isEmpty)
        #expect(pins.pinned.folder(folder.id) != nil)
    }

    @Test func `a deleted note is unpinned in every space, and empty spaces are dropped`() {
        let note = UUID()
        let other = PinScope(space: UUID(), profile: Profile.defaultID)
        var layout = PinLayout()
        layout[.default].addDocument(note)
        layout[other].addDocument(note)
        layout[other].add(Pin(id: UUID(), url: "https://example.com/", title: "Example"), to: .pinned)

        layout.removeDocument(note)
        #expect(layout[.default].pinned.isEmpty)
        #expect(layout[other].pinned.documents.isEmpty)
        #expect(layout[other].pinned.tabs.count == 1)
        #expect(layout == {
            var expected = PinLayout()
            expected[other] = layout[other]
            return expected
        }())
    }
}
