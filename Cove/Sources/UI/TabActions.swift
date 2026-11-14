import SwiftUI

/// What can be done to a tab: its context menu, and the active tab's half of
/// the Tab menu. Pinning comes first.
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
        // A private window keeps nothing, pins included.
        if !tabManager.isPrivate {
            pinning

            Divider()
        }

        splitting

        Divider()

        if tabManager.section(of: tab.id) == .today {
            grouping
            Divider()
        }

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
            Button(actionTabIDs.count > 1 ? "Close Selected Tabs" : "Close Tab") {
                tabManager.closeSelectedTabs(from: tab.id)
            }
            .disabled(!tabManager.canCloseTab(tab.id))
        }

        Button("Close Other Tabs") {
            tabManager.closeOtherTabs(keeping: tab.id)
        }
        .disabled(tabManager.tabs.count < 2)

        Button(tabManager.tabLayout == .sidebar ? "Close Tabs Below" : "Close Tabs to the Right") {
            tabManager.closeTabs(below: tab.id)
        }
        .disabled(tabManager.tabsInDisplayOrder.elements(after: tab.id).allSatisfy { tabManager.section(of: $0.id) != .today })
    }

    private var actionTabIDs: [UUID] {
        tabManager.selectionTabIDs(for: tab.id)
    }

    @ViewBuilder
    private var grouping: some View {
        if tabManager.section(of: tab.id) == .today {
            let ids = actionTabIDs.filter { tabManager.section(of: $0) == .today }
            Button(ids.count > 1 ? "New Group with Selected Tabs" : "New Group with Tab") {
                _ = tabManager.createGroup(tabIDs: ids)
                tabManager.clearTabSelection()
            }
            if !tabManager.tabGroups.isEmpty {
                Menu("Add to Group") {
                    ForEach(tabManager.tabGroups) { group in
                        Button(tabManager.groupTitle(group)) {
                            tabManager.moveTabs(ids, toGroup: group.id)
                            tabManager.clearTabSelection()
                        }
                        .disabled(ids.allSatisfy { group.members.contains($0) })
                    }
                }
            }
            if ids.contains(where: { tabManager.group(for: $0) != nil }) {
                Button("Remove from Group") {
                    tabManager.ungroupTabs(ids)
                    tabManager.clearTabSelection()
                }
            }
        }
    }

    /// Pin or unpin, with ⌘D from the menu bar; the other section to move to;
    /// the way back for a pinned tab that has wandered; a folder around a
    /// pinned tab.
    @ViewBuilder
    private var pinning: some View {
        let section = tabManager.section(of: tab.id)

        if section == .today {
            Button("Pin Tab") {
                tabManager.pinTab(tab.id)
            }
            .keyboardShortcut(pinShortcut)
            .disabled(tab.currentURL.isEmpty)

        } else {
            Button("Unpin Tab") {
                tabManager.unpinTab(tab.id)
            }
            .keyboardShortcut(pinShortcut)

            if tab.isAwayFromPin {
                Button("Back to Pinned Page", action: tab.returnToPin)
            }

            if section == .pinned, case .tab = placement {
                Button("New Folder with Tab") {
                    tabManager.newFolder(around: tab.id)
                }
            }
        }
    }

    /// A tab's menu brings it into the split on screen, or separates its
    /// split; the menu bar adds a pane to the active tab's, with ⌃⇧=.
    @ViewBuilder
    private var splitting: some View {
        switch placement {
        case .tab:
            if let split = tabManager.split(containing: tab.id) {
                Button("Separate Split View") {
                    tabManager.separateSplit(split.id)
                }
            } else if tabManager.section(of: tab.id) == .today {
                Button("Open in Split View") {
                    tabManager.openInSplitView(tab.id)
                }
                .disabled(!tabManager.canOpenInSplitView(tab.id))
            }
        case .menuBar:
            Button("Add Split View") {
                tabManager.addSplitView()
            }
            .keyboardShortcut("s", modifiers: [.control, .option])
            .disabled(!tabManager.canAddSplitPane)

            if let split = tabManager.activeSplit {
                Button(split.axis == .horizontal ? "Stack Split View" : "Arrange Split View Side by Side") {
                    tabManager.rotateSplit(split.id)
                }

                Button("Separate Split View") {
                    tabManager.separateSplit(split.id)
                }
            }
        }
    }

    private var pinShortcut: KeyboardShortcut? {
        if case .menuBar = placement { KeyboardShortcut("d", modifiers: .command) } else { nil }
    }
}
