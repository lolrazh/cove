import Foundation

extension CommandBarCommand {
    enum Category: String, CaseIterable {
        case create = "Create"
        case organize = "Tabs and Profiles"
        case page = "Page Tools"
        case media = "Audio and Video"
        case windows = "Windows and Layout"
        case library = "Library and Settings"
    }

    var category: Category {
        switch self {
        case .newNote, .newEasel, .newFolder: .create
        case .pinTab, .unpinTab, .newProfile, .editProfile, .duplicateTab, .closeOtherTabs, .newTabGroup, .ungroupTabs: .organize
        case .copyURL, .findInPage, .zoomIn, .zoomOut, .actualSize, .printPage, .savePage, .capture, .viewSource, .siteSettings, .boostSite: .page
        case .muteTab, .unmuteTab, .pauseMedia, .playMedia, .pictureInPicture: .media
        case .addSplitView, .rotateSplitView, .separateSplitView, .equalizeSplit, .showTabsInSidebar, .showTabsOnTop, .hideTabs, .showTabs, .newWindow, .newPrivateWindow, .newLittleCove: .windows
        case .reopenClosedTab, .importBookmarks, .showLibrary, .showDownloads, .showArchive, .showHistory, .extensions, .settings, .appearanceSettings, .privacySettings: .library
        }
    }

    var summary: String {
        switch self {
        case .newNote: "Write rich text, lists, checklists, and tables."
        case .newEasel: "Arrange text, images, drawings, and live page clippings on a canvas."
        case .newFolder: "Keep pinned tabs together in a folder."
        case .newProfile: "Create a separate set of tabs, notes, history, and site data."
        case .editProfile: "Change this profile's name and theme color."
        case .pinTab: "Keep this page or document in the profile's pinned section."
        case .unpinTab: "Move this saved tab back to regular tabs."
        case .newTabGroup: "Group the active tab or the tabs selected with ⌘-click."
        case .ungroupTabs: "Keep the selected tabs and remove their grouping."
        case .duplicateTab: "Open a second copy of this tab."
        case .closeOtherTabs: "Close regular tabs except the active tab."
        case .copyURL: "Copy this page's address."
        case .findInPage: "Find words in the current web page."
        case .zoomIn: "Make the page larger."
        case .zoomOut: "Make the page smaller."
        case .actualSize: "Return the page to 100% zoom."
        case .printPage: "Print the web page or save it as a PDF."
        case .savePage: "Save a web archive or the page's source."
        case .capture: "Capture a page region; copy it or send it to a Note or Easel."
        case .viewSource: "Read the current page's HTML."
        case .siteSettings: "Manage permissions, site data, and content blocking."
        case .boostSite: "Change a site's colors, fonts, CSS, or JavaScript; hide elements."
        case .muteTab: "Silence audio from this tab."
        case .unmuteTab: "Restore audio from this muted tab."
        case .pauseMedia: "Pause the media controlled by Cove's player."
        case .playMedia: "Resume media in Cove's player."
        case .pictureInPicture: "Float a playing video above your other windows."
        case .addSplitView: "Choose another page to view beside this one."
        case .rotateSplitView: "Switch between side-by-side and stacked panes."
        case .separateSplitView: "Turn split panes back into separate tabs."
        case .equalizeSplit: "Give each pane the same amount of space."
        case .showTabsInSidebar: "Put tabs on the left side of the window."
        case .showTabsOnTop: "Put tabs above the page."
        case .hideTabs: "Hide the tab area; move to the left edge to reveal the sidebar."
        case .showTabs: "Keep the tab area visible."
        case .newWindow: "Open another window in this profile."
        case .newPrivateWindow: "Browse without keeping this window's history or site data."
        case .newLittleCove: "Open a small window for a quick look at a page."
        case .reopenClosedTab: "Restore the last closed tab."
        case .importBookmarks: "Bring bookmarks and history from another browser."
        case .showLibrary: "Browse downloads, closed tabs, and history."
        case .showDownloads: "See download progress and open downloaded files."
        case .showArchive: "Find and reopen closed or automatically archived tabs."
        case .showHistory: "Search the pages visited in this profile."
        case .extensions: "Install and manage browser extensions."
        case .settings: "Set search, new tabs, tab sleeping, automatic archive, and downloads."
        case .appearanceSettings: "Choose the tab layout and sidebar visibility."
        case .privacySettings: "Control ad blocking, history, and search suggestions."
        }
    }
}

extension CommandBarRanker {
    /// A complete inventory, independent of what can run on the current page.
    /// Availability is presented by the model, rather than removing the feature.
    func catalog(query: String) -> Ranking {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let match = QueryMatch(query)
        let commands = CommandBarCommand.allCases.filter {
            query.isEmpty || match.matches(title: $0.title, keywords: $0.keywords)
                || match.quality(title: $0.summary, url: "") != nil
        }
        return Ranking(sections: CommandBarCommand.Category.allCases.compactMap { category in
            let rows = commands.filter { $0.category == category }.map {
                CommandBarResult(kind: .command($0), title: $0.title, destination: "")
            }
            return rows.isEmpty ? nil : CommandBarSection(title: category.rawValue, results: rows)
        }, completion: nil)
    }
}
