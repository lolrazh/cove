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

    @Test func `moving works the same in a list shown reversed`() {
        // The sidebar shows the newest tab first ("edcba"). The move is made
        // on the stored order and must land the tab where c was on screen.
        var stored = tabs
        stored.move("a", onto: "c")
        #expect(ids(stored.reversed()) == "edacb")
    }
}
