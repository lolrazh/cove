import Foundation
import Testing
@testable import Cove

struct SidebarTreeTests {
    private struct Tab: Identifiable, Equatable {
        let id: UUID
        let name: Character
    }

    private let ids = Dictionary(uniqueKeysWithValues: "abcdefFGvwxyz".map { ($0, UUID()) })

    private func id(_ name: Character) -> UUID { ids[name]! }

    private func tab(_ name: Character) -> SidebarItem<Tab> {
        .tab(Tab(id: id(name), name: name))
    }

    private func folder(_ name: Character, _ contents: [SidebarItem<Tab>]) -> SidebarItem<Tab> {
        .folder(SidebarFolder(id: id(name), name: String(name), contents: SidebarTree(contents)))
    }

    /// a, b, F[c, d, G[e]], f
    private var tree: SidebarTree<Tab> {
        SidebarTree([tab("a"), tab("b"), folder("F", [tab("c"), tab("d"), folder("G", [tab("e")])]), tab("f")])
    }

    private func names(_ tabs: [Tab]) -> String {
        String(tabs.map(\.name))
    }

    private func order(_ tree: SidebarTree<Tab>) -> String {
        String(tree.ids.map { id in ids.first { $0.value == id }!.key })
    }

    @Test func `tabs flatten folders in order, visible ones skip collapsed folders`() {
        var tree = tree
        #expect(names(tree.tabs) == "abcdef")
        #expect(order(tree) == "abFcdGef")
        #expect(tree.folders.map(\.name) == ["F", "G"])

        tree.update(folder: id("G")) { $0.isCollapsed = true }
        #expect(names(tree.visibleTabs) == "abcdf")
        #expect(names(tree.tabs) == "abcdef")
        tree.update(folder: id("F")) { $0.isCollapsed = true }
        #expect(names(tree.visibleTabs) == "abf")
    }

    @Test func `items are found and removed wherever they are`() {
        var tree = tree
        #expect(tree.tab(id("e"))?.name == "e")
        #expect(tree.folder(id("G"))?.name == "G")
        #expect(tree.contains(id("G")))

        let e = tree.remove(id("e"))
        let f = tree.remove(id("F"))
        let gone = tree.remove(id("e"))
        #expect(e?.id == id("e"))
        #expect(f?.id == id("F"))
        #expect(gone == nil)
        #expect(order(tree) == "abf")
    }

    @Test func `insert at each position`() {
        var tree = tree
        let inserted = [
            tree.insert(tab("x"), at: .before(id("d"))),
            tree.insert(tab("y"), at: .after(id("e"))),
            tree.insert(tab("z"), at: .into(id("G"))),
            tree.insert(tab("w"), at: .end),
        ]
        #expect(inserted == [true, true, true, true])
        #expect(names(tree.tabs) == "abcxdeyzfw")

        let nowhere = tree.insert(tab("v"), at: .before(UUID()))
        let intoTab = tree.insert(tab("v"), at: .into(id("a")))
        #expect(!nowhere && !intoTab)
        #expect(names(tree.tabs) == "abcxdeyzfw")
    }

    @Test func `a folder never goes inside itself`() {
        var tree = tree
        tree.move(id("F"), to: .into(id("G")))
        tree.move(id("F"), to: .before(id("e")))
        tree.move(id("F"), to: .into(id("F")))
        #expect(tree == self.tree)

        tree.move(id("G"), to: .before(id("a")))
        #expect(order(tree) == "GeabFcdf")
    }

    @Test func `moving onto a tab takes its place, shifting it toward where the move came from`() {
        var forward = tree
        forward.move(id("a"), onto: id("c"))
        #expect(names(forward.tabs) == "bcadef")

        var backward = tree
        backward.move(id("f"), onto: id("b"))
        #expect(names(backward.tabs) == "afbcde")

        var out = tree
        out.move(id("e"), onto: id("a"))
        #expect(order(out) == "eabFcdGf")

        var unchanged = tree
        unchanged.move(id("c"), onto: id("c"))
        unchanged.move(UUID(), onto: id("a"))
        #expect(unchanged == tree)
    }

    @Test func `tabs are updated in place and the tree maps to another tab type`() {
        var tree = tree
        let updated = tree.update(tab: id("e")) { $0 = Tab(id: $0.id, name: "E") }
        let missing = tree.update(tab: UUID()) { _ in }
        #expect(updated && !missing)
        #expect(names(tree.tabs) == "abcdEf")

        let mapped = tree.map { Tab(id: $0.id, name: $0.name.uppercased().first!) }
        #expect(names(mapped.tabs) == "ABCDEF")
        #expect(order(mapped) == order(tree))
    }

    @Test func `the saved form survives a plist round trip`() throws {
        struct Saved: Identifiable, Codable, Equatable {
            let id: UUID
            let name: String
        }
        let tree = SidebarTree<Saved>([
            .tab(Saved(id: UUID(), name: "a")),
            .folder(SidebarFolder(name: "F", isCollapsed: true, contents: SidebarTree([.tab(Saved(id: UUID(), name: "b"))]))),
        ])
        let data = try PropertyListEncoder().encode(tree)
        #expect(try PropertyListDecoder().decode(SidebarTree<Saved>.self, from: data) == tree)
    }
}
