import Foundation
import Testing
@testable import Cove

struct TodayTests {
    private struct Tab: Identifiable, Equatable {
        let id = UUID()
    }

    @Test func `notes keep their places among the tabs when saved and restored`() {
        let tabs = [Tab(), Tab(), Tab()]
        let first = UUID(), middle = UUID(), last = UUID()
        let today: [TodayItem<Tab>] = [.document(first), .tab(tabs[0]), .tab(tabs[1]), .document(middle), .tab(tabs[2]), .document(last)]

        let places = today.documentPlaces()
        #expect(places == [
            TodayDocumentPlace(id: first, index: 0),
            TodayDocumentPlace(id: middle, index: 3),
            TodayDocumentPlace(id: last, index: 5),
        ])
        let restored = TodayItem.restoring(tabs: tabs, documents: places.reversed())
        #expect(restored.map(\.id) == today.map(\.id))
    }

    @Test func `a note whose place is past the end goes last`() {
        let tabs = [Tab()]
        let note = UUID()
        let restored = TodayItem.restoring(tabs: tabs, documents: [TodayDocumentPlace(id: note, index: 9)])
        #expect(restored.map(\.id) == [tabs[0].id, note])
    }

    @Test func `today saved with notes comes back, and older sessions have none`() throws {
        let tab = SavedTab(url: "https://example.com/", title: "Example", customTitle: nil, interactionState: nil, lastUsedAt: nil)
        let note = UUID()
        let window = SavedWindow(
            spaces: [
                SavedSpace(spaceID: UUID(), tabs: [tab], activeTabIndex: 0, activePinID: nil, documents: [TodayDocumentPlace(id: note, index: 0)], activeDocumentID: note),
                SavedSpace(spaceID: UUID(), tabs: [tab], activeTabIndex: 0, activePinID: nil),
            ],
            activeSpaceID: UUID()
        )
        let decoded = try PropertyListDecoder().decode(SavedWindow.self, from: PropertyListEncoder().encode(window))
        #expect(decoded.spaces[0].documents == [TodayDocumentPlace(id: note, index: 0)])
        #expect(decoded.spaces[0].activeDocumentID == note)
        #expect(decoded.spaces[1].documents == nil)
    }
}
