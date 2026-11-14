import AppKit
import Testing
@testable import Cove

@MainActor
struct TabSelectionTests {
    private let ids = (0..<5).map { _ in UUID() }

    @Test func commandClickCollectsTabsWithoutRequestingPageFocus() {
        var selection = TabSelection()
        #expect(selection.click(ids[2], in: ids, activeID: ids[0], modifiers: .command))
        #expect(selection.ids == [ids[0], ids[2]])
        #expect(selection.click(ids[0], in: ids, activeID: ids[0], modifiers: .command))
        #expect(selection.ids == [ids[2]])
        #expect(selection.anchorID == ids[0])
    }

    @Test func shiftRangeUsesFixedAnchorAndCanShrink() {
        var selection = TabSelection(anchorID: ids[1])
        #expect(selection.click(ids[4], in: ids, activeID: ids[0], modifiers: .shift))
        #expect(selection.ids == Set(ids[1...4]))
        #expect(selection.click(ids[2], in: ids, activeID: ids[0], modifiers: .shift))
        #expect(selection.ids == Set(ids[1...2]))
        #expect(selection.anchorID == ids[1])
    }

    @Test func hiddenAnchorFallsBackToVisibleActiveTab() {
        var selection = TabSelection(anchorID: ids[1])
        let visible = [ids[0], ids[2], ids[4]]
        #expect(selection.click(ids[4], in: visible, activeID: ids[2], modifiers: .shift))
        #expect(selection.ids == [ids[2], ids[4]])
        #expect(selection.anchorID == ids[2])
    }

    @Test func ordinaryClickClearsSelectionAndRequestsPageFocus() {
        var selection = TabSelection(ids: Set(ids.prefix(3)), anchorID: ids[0])
        #expect(!selection.click(ids[4], in: ids, activeID: ids[0], modifiers: []))
        #expect(selection.ids.isEmpty)
        #expect(selection.anchorID == ids[4])
        #expect(!selection.click(UUID(), in: ids, activeID: ids[0], modifiers: .command))
        #expect(selection.ids.isEmpty)
        #expect(selection.anchorID == nil)
    }
}
