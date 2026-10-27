import SwiftUI

/// What can be done to a tab: its context menu, and the active tab's half of
/// the Tab menu. Pinning joins at the top.
struct TabActions: View {
    enum Placement {
        /// A tab's context menu. Renaming edits the title where it's shown.
        case tab(rename: () -> Void)
        /// The menu bar, which has Copy URL and Close Tab elsewhere already.
        case menuBar
    }

    @ObservedObject var tab: TabSession
    @ObservedObject var tabManager: TabManager
    let placement: Placement

    var body: some View {
        Button("Duplicate Tab") {
            tabManager.duplicateTab(tab.id)
        }

        if case .tab(let rename) = placement {
            Button("Rename Tab…", action: rename)

            Button("Copy Link") {
                tabManager.copyURL(of: tab)
            }
            .disabled(tab.currentURL.isEmpty)
        }

        Button(tab.isMuted ? "Unmute Tab" : "Mute Tab", action: tab.toggleMuted)

        Divider()

        if case .tab = placement {
            Button("Close Tab") {
                tabManager.closeTab(tab.id)
            }
            .disabled(tabManager.tabs.count < 2)
        }

        Button("Close Other Tabs") {
            tabManager.closeOtherTabs(keeping: tab.id)
        }
        .disabled(tabManager.tabs.count < 2)

        Button(tabManager.tabLayout == .sidebar ? "Close Tabs Below" : "Close Tabs to the Right") {
            tabManager.closeTabs(below: tab.id)
        }
        .disabled(tabManager.tabsInDisplayOrder.elements(after: tab.id).isEmpty)
    }
}
