import AppKit
import Testing
@testable import Cove

@MainActor
struct TabSelectionTests {
    private let ids = (0..<5).map { _ in UUID() }

    @Test func commandClickCollectsTabsWithoutRequestingPageFocus() {
        var selection = TabSelection()
        let collected = selection.click(ids[2], in: ids, activeID: ids[0], modifiers: .command)
        #expect(collected)
        #expect(selection.ids == [ids[0], ids[2]])
        let toggled = selection.click(ids[0], in: ids, activeID: ids[0], modifiers: .command)
        #expect(toggled)
        #expect(selection.ids == [ids[2]])
        #expect(selection.anchorID == ids[0])
    }

    @Test func shiftRangeUsesFixedAnchorAndCanShrink() {
        var selection = TabSelection(anchorID: ids[1])
        let extended = selection.click(ids[4], in: ids, activeID: ids[0], modifiers: .shift)
        #expect(extended)
        #expect(selection.ids == Set(ids[1...4]))
        let shortened = selection.click(ids[2], in: ids, activeID: ids[0], modifiers: .shift)
        #expect(shortened)
        #expect(selection.ids == Set(ids[1...2]))
        #expect(selection.anchorID == ids[1])
    }

    @Test func hiddenAnchorFallsBackToVisibleActiveTab() {
        var selection = TabSelection(anchorID: ids[1])
        let visible = [ids[0], ids[2], ids[4]]
        let extended = selection.click(ids[4], in: visible, activeID: ids[2], modifiers: .shift)
        #expect(extended)
        #expect(selection.ids == [ids[2], ids[4]])
        #expect(selection.anchorID == ids[2])
    }

    @Test func ordinaryClickClearsSelectionAndRequestsPageFocus() {
        var selection = TabSelection(ids: Set(ids.prefix(3)), anchorID: ids[0])
        let selectionOnly = selection.click(ids[4], in: ids, activeID: ids[0], modifiers: [])
        #expect(!selectionOnly)
        #expect(selection.ids.isEmpty)
        #expect(selection.anchorID == ids[4])
        let missingTabSelection = selection.click(UUID(), in: ids, activeID: ids[0], modifiers: .command)
        #expect(!missingTabSelection)
        #expect(selection.ids.isEmpty)
        #expect(selection.anchorID == nil)
    }
}
