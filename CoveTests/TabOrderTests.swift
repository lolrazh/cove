import Foundation
import Testing
@testable import Cove

struct TabOrderTests {
    private struct Tab: Identifiable, Equatable {
        let id: Character
    }

    private let tabs = "abcde".map(Tab.init)

    private func ids(_ tabs: some Sequence<Tab>) -> String {
        String(tabs.map(\.id))
    }

    @Test func `next and previous wrap around the ends`() {
        #expect(tabs.element(1, from: "c")?.id == "d")
        #expect(tabs.element(1, from: "e")?.id == "a")
        #expect(tabs.element(-1, from: "a")?.id == "e")
        #expect(tabs.element(-1, from: "c")?.id == "b")
        #expect(tabs.element(1, from: "z") == nil)
    }

    @Test func `a single tab is its own neighbor`() {
        let one = [Tab(id: "a")]
        #expect(one.element(1, from: "a")?.id == "a")
        #expect(one.element(-1, from: "a")?.id == "a")
    }

    @Test func `closing the newest tab selects the adjacent older tab`() {
        #expect(tabs.neighborWhenClosing("e")?.id == "d")
        #expect(tabs.neighborWhenClosing("c")?.id == "d")
        #expect(tabs.neighborWhenClosing("a")?.id == "b")
    }

    @Test func `closing has no neighbor for a lone or unknown tab`() {
        #expect([Tab(id: "a")].neighborWhenClosing("a") == nil)
        #expect([Tab]().neighborWhenClosing("a") == nil)
        #expect(tabs.neighborWhenClosing("z") == nil)
    }

    @Test func `command digits pick by place and nine picks the last`() {
        #expect(tabs.element(forShortcut: 1)?.id == "a")
        #expect(tabs.element(forShortcut: 5)?.id == "e")
        #expect(tabs.element(forShortcut: 6) == nil)
        #expect(tabs.element(forShortcut: 9)?.id == "e")
        let many = "abcdefghijk".map(Tab.init)
        #expect(many.element(forShortcut: 8)?.id == "h")
        #expect(many.element(forShortcut: 9)?.id == "k")
    }

    @Test func `elements after a tab are the ones shown below it`() {
        #expect(ids(tabs.elements(after: "b")) == "cde")
        #expect(ids(tabs.elements(after: "e")) == "")
        #expect(ids(tabs.elements(after: "z")) == "")
    }

    @Test func `a dragged tab takes the place of the one under it`() {
        var forward = tabs
        forward.move("a", onto: "c")
        #expect(ids(forward) == "bcade")

        var backward = tabs
        backward.move("d", onto: "b")
        #expect(ids(backward) == "adbce")

        var unchanged = tabs
        unchanged.move("c", onto: "c")
        unchanged.move("z", onto: "a")
        #expect(unchanged == tabs)
    }

    @Test func `a group moves together onto another group, landing past it`() {
        var down = tabs
        down.move(["a", "b"], onto: ["d"])
        #expect(ids(down) == "cdabe")

        var up = tabs
        up.move(["e"], onto: ["b", "c"])
        #expect(ids(up) == "aebcd")

        // Scattered members end up together, in their order.
        var scattered = tabs
        scattered.move(["a", "c"], onto: ["e"])
        #expect(ids(scattered) == "bdeac")

        var overlapping = tabs
        overlapping.move(["a", "b"], onto: ["b"])
        #expect(overlapping == tabs)
    }

    @Test func `gathering brings a group together where its first member is`() {
        var gathered = tabs
        gathered.gather(["d", "b"])
        #expect(ids(gathered) == "abdce")

        var unknown = tabs
        unknown.gather(["z"])
        #expect(unknown == tabs)
    }

    @Test func `the display order runs pinned, then today, as each layout shows them`() {
        struct Pinned: Identifiable { let id = UUID(); let name: Character }
        let (a, b, c, d) = (Pinned(name: "a"), Pinned(name: "b"), Pinned(name: "c"), Pinned(name: "d"))
        let folded = SidebarFolder(name: "Folded", isCollapsed: true, contents: SidebarTree([.tab(c)]))
        let open = SidebarFolder(name: "Open", contents: SidebarTree([.tab(d)]))
        let pinned = SidebarTree([.tab(a), .folder(folded), .folder(open), .tab(b)])
        let today = "xyz".map(Pinned.init)

        func names(_ tabs: [Pinned]) -> String { String(tabs.map(\.name)) }
        let sidebar = TabLayout.sidebar.displayOrder(pinned: pinned, today: today)
        let strip = TabLayout.horizontal.displayOrder(pinned: pinned, today: today)

        // The sidebar skips the folded folder's tab. New Today tabs go below
        // the existing tabs in both layouts, without reversing saved order.
        #expect(names(sidebar) == "adbxyz")
        #expect(names(strip) == "acdbxyz")
        // ⌘1 is the first pinned tab.
        #expect(sidebar.element(forShortcut: 1)?.name == "a")
        #expect(TabLayout.sidebar.displayOrder(pinned: pinned, today: today).element(forShortcut: 1)?.name == "a")
        #expect(sidebar.element(forShortcut: 9)?.name == "z")
    }

    @Test func `new tabs append downward and shortcuts and close below follow the visible order`() {
        struct Item: Identifiable { let id = UUID() }
        let a = Item(), b = Item(), c = Item()
        var today = [a, b]
        today.append(c)
        let shown = TabLayout.sidebar.displayOrder(pinned: SidebarTree<Item>(), today: today)
        #expect(shown.map(\.id) == [a.id, b.id, c.id])
        #expect(shown.element(forShortcut: 1)?.id == a.id)
        #expect(shown.element(1, from: a.id)?.id == b.id)
        #expect(shown.elements(after: b.id).map(\.id) == [c.id])
        today.move(c.id, onto: a.id)
        #expect(TabLayout.sidebar.displayOrder(pinned: SidebarTree<Item>(), today: today).map(\.id) == [c.id, a.id, b.id])
    }
}
