import Testing
@testable import Cove

struct TabGroupNameTests {
    @Test func removesUnreadCountAndSiteSuffix() {
        #expect(TabGroupName.title(for: [("(268) Wearable Tech Videos - YouTube", "https://youtube.com/watch")]) == "Wearable Tech Videos")
    }
    @Test func findsSharedTopicAndKeepsMixedSiteGroupsUseful() {
        #expect(TabGroupName.title(for: [("Notebook Research Display | Review", "https://a.test"),
                                         ("Notebook Research Battery — Tests", "https://b.test")]) == "Notebook Research")
        #expect(TabGroupName.title(for: [("Keyboard Review", "https://a.test"), ("Battery Tests", "https://b.test")]) == "Keyboard Review")
    }
    @Test func fallsBackWithoutALoadedTitle() {
        #expect(TabGroupName.title(for: [("", "https://www.example.com/path")]) == "example.com")
        #expect(TabGroupName.title(for: [("New Tab", "")]) == "Tab Group")
    }
    @Test func limitsLongNamesWithoutBreakingUnicode() {
        let title = String(repeating: "研究", count: 40)
        #expect(TabGroupName.title(for: [(title, "")]).count == 49)
    }
}
