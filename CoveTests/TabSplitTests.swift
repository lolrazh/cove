import Foundation
import Testing
@testable import Cove

struct TabSplitTests {
    private typealias Split = TabSplit<String>

    private func approx(_ values: [Double]) -> [Double] {
        values.map { ($0 * 1000).rounded() / 1000 }
    }

    @Test func `a new split shares its length equally unless saved shares fit`() {
        #expect(Split(panes: ["a", "b"]).fractions == [0.5, 0.5])
        #expect(Split(panes: ["a", "b"], fractions: [0.3, 0.7]).fractions == [0.3, 0.7])
        #expect(Split(panes: ["a", "b"], fractions: [1]).fractions == [0.5, 0.5])
    }

    @Test func `adding a pane evens the shares, up to four panes, each once`() {
        var split = Split(panes: ["a", "b"], fractions: [0.2, 0.8])
        split.insert("c", at: 1)
        #expect(split.panes == ["a", "c", "b"])
        #expect(approx(split.fractions) == [0.333, 0.333, 0.333])

        split.insert("a", at: 0)
        #expect(split.panes == ["a", "c", "b"])

        split.insert("d", at: 99)
        #expect(split.panes == ["a", "c", "b", "d"])
        #expect(split.isFull)
        split.insert("e", at: 0)
        #expect(split.panes == ["a", "c", "b", "d"])
    }

    @Test func `removing a pane grows the others in proportion, and one pane is no split`() {
        let split = Split(panes: ["a", "b", "c"], fractions: [0.2, 0.5, 0.3])
        let removed = split.removing("b")
        #expect(removed?.panes == ["a", "c"])
        #expect(approx(removed?.fractions ?? []) == [0.4, 0.6])
        #expect(removed?.id == split.id)
        #expect(removed?.removing("a") == nil)
        #expect(split.removing("z") == split)
        #expect(split.keeping { $0 == "c" } == nil)
    }

    @Test func `the pane after takes over, else the one before`() {
        let split = Split(panes: ["a", "b", "c"])
        #expect(split.neighbor(of: "a") == "b")
        #expect(split.neighbor(of: "b") == "c")
        #expect(split.neighbor(of: "c") == "b")
        #expect(split.neighbor(of: "z") == nil)
    }

    @Test func `dividers sit between the panes and move length between neighbors only`() {
        var split = Split(panes: ["a", "b", "c"], fractions: [0.25, 0.25, 0.5])
        #expect(split.dividers == [0.25, 0.5])

        split.moveDivider(1, to: 0.7)
        #expect(approx(split.fractions) == [0.25, 0.45, 0.3])

        // Neither pane beside the divider goes below the smallest share.
        split.moveDivider(0, to: 0)
        #expect(approx(split.fractions) == [0.15, 0.55, 0.3])
        split.moveDivider(1, to: 1)
        #expect(approx(split.fractions) == [0.15, 0.7, 0.15])
        #expect(approx([split.fractions.reduce(0, +)]) == [1])

        split.moveDivider(2, to: 0.5)
        #expect(approx(split.fractions) == [0.15, 0.7, 0.15])
    }

    @Test func `a split maps to saved places and back, or not at all`() {
        let tabs = ["a", "b", "c"]
        let split = Split(panes: ["c", "a"], fractions: [0.6, 0.4], axis: .vertical)
        let saved = split.map { tabs.firstIndex(of: $0) }
        #expect(saved?.panes == [2, 0])
        #expect(saved?.fractions == [0.6, 0.4])
        #expect(saved?.axis == .vertical)

        let restored = saved?.map { tabs.indices.contains($0) ? tabs[$0] : nil }
        #expect(restored?.panes == ["c", "a"])
        #expect(saved?.map { $0 == 0 ? nil : tabs[$0] } == nil)
    }

    @Test func `a saved split survives a plist round trip`() throws {
        let split = TabSplit<Int>(panes: [0, 2], fractions: [0.3, 0.7])
        let data = try PropertyListEncoder().encode([split])
        #expect(try PropertyListDecoder().decode([TabSplit<Int>].self, from: data) == [split])
    }

    @Test func `splits are saved with their space, and older spaces have none`() throws {
        let tab = SavedTab(url: "https://example.com", title: "", customTitle: nil, interactionState: nil, lastUsedAt: nil)
        let split = TabSplit<Int>(panes: [1, 0], fractions: [0.6, 0.4], axis: .vertical)
        let window = SavedWindow(
            spaces: [
                SavedSpace(spaceID: UUID(), tabs: [tab, tab], activeTabIndex: 0, activePinID: nil, splits: [split]),
                SavedSpace(spaceID: UUID(), tabs: [tab], activeTabIndex: 0, activePinID: nil),
            ],
            activeSpaceID: UUID()
        )
        let decoded = try PropertyListDecoder().decode(SavedWindow.self, from: PropertyListEncoder().encode(window))
        #expect(decoded.spaces[0].splits == [split])
        #expect(decoded.spaces[1].splits == nil)
    }

    @Test func `entries show a split once, where its first tab is, in the split's order`() {
        struct Tab: Identifiable { let id = UUID(); let name: Character }
        let tabs = "abcde".map(Tab.init)
        let split = TabSplit(panes: [tabs[3].id, tabs[1].id])

        let entries = tabs.entries(splits: [split])
        let names = entries.map { entry -> String in
            switch entry {
            case .tab(let tab): String(tab.name)
            case .split(_, let tabs): "[" + String(tabs.map(\.name)) + "]"
            }
        }
        #expect(names == ["a", "[db]", "c", "e"])
        #expect(entries[1].id == split.id)
    }
}
