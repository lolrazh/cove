import Foundation

/// One row in the Command Bar. Identity comes from the kind and its payload, so
/// a selection survives the list refreshing around it.
struct CommandBarResult: Identifiable, Hashable {
    enum Kind: Hashable {
        /// An open tab in this window.
        case tab(UUID)
        /// A tab in the archive, reopened with its back/forward list.
        case archived(UUID)
        /// A page from history.
        case history
        /// The input taken as an address.
        case url
        /// The input taken as a search.
        case search
        /// A completion offered by the search engine.
        case suggestion
        case command(CommandBarCommand)
    }

    let kind: Kind
    /// What the row says: a page title, a query, or a command name.
    let title: String
    /// Where it leads: a URL for pages, a query for searches. Empty for commands.
    let destination: String

    var id: Self { self }

    /// A page row's address without the parts people don't read.
    var displayURL: String {
        Self.displayURL(for: destination)
    }

    static func displayURL(for url: String) -> String {
        var display = url
        for prefix in ["https://", "http://"] where display.hasPrefix(prefix) {
            display.removeFirst(prefix.count)
        }
        if display.hasPrefix("www.") { display.removeFirst(4) }
        if display.hasSuffix("/") { display.removeLast() }
        return display
    }
}

struct CommandBarSection: Identifiable {
    /// Nil for the top hit, which needs no heading.
    let title: String?
    let results: [CommandBarResult]

    var id: String { title ?? "" }
}

/// Things the Command Bar can do besides navigate. Only commands that exist
/// elsewhere in the app, under the names their menu items use.
enum CommandBarCommand: CaseIterable, Hashable {
    case copyURL
    case pinTab
    case unpinTab
    case addToFavorites
    case newFolder
    case importBookmarks
    case duplicateTab
    case muteTab
    case unmuteTab
    case pauseMedia
    case playMedia
    case closeOtherTabs
    case findInPage
    case zoomIn
    case zoomOut
    case actualSize
    case printPage
    case savePage
    case viewSource
    case pictureInPicture
    case siteSettings
    case boostSite
    case showTabsInSidebar
    case showTabsOnTop
    case hideTabs
    case showTabs
    case reopenClosedTab
    case newWindow
    case newPrivateWindow
    case showLibrary
    case showHistory
    case settings

    var title: String {
        switch self {
        case .copyURL: "Copy URL"
        case .pinTab: "Pin Tab"
        case .unpinTab: "Unpin Tab"
        case .addToFavorites: "Add to Favorites"
        case .newFolder: "New Folder"
        case .importBookmarks: "Import Bookmarks"
        case .duplicateTab: "Duplicate Tab"
        case .muteTab: "Mute Tab"
        case .unmuteTab: "Unmute Tab"
        case .pauseMedia: "Pause Media"
        case .playMedia: "Play Media"
        case .closeOtherTabs: "Close Other Tabs"
        case .findInPage: "Find on Page"
        case .zoomIn: "Zoom In"
        case .zoomOut: "Zoom Out"
        case .actualSize: "Actual Size"
        case .printPage: "Print"
        case .savePage: "Save Page As"
        case .viewSource: "View Source"
        case .pictureInPicture: "Picture in Picture"
        case .siteSettings: "Site Settings"
        case .boostSite: "Boost This Site"
        case .showTabsInSidebar: "Show Tabs in Sidebar"
        case .showTabsOnTop: "Show Tabs on Top"
        case .hideTabs: "Hide Tabs"
        case .showTabs: "Show Tabs"
        case .reopenClosedTab: "Reopen Last Closed Tab"
        case .newWindow: "New Window"
        case .newPrivateWindow: "New Private Window"
        case .showLibrary: "Library"
        case .showHistory: "Show All History"
        case .settings: "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .copyURL: "link"
        case .pinTab: ChromeSymbols.Tabs.pin
        case .unpinTab: ChromeSymbols.Tabs.unpin
        case .addToFavorites: ChromeSymbols.Tabs.favorite
        case .newFolder: ChromeSymbols.Tabs.folder
        case .importBookmarks: "square.and.arrow.down.on.square"
        case .duplicateTab: "plus.square.on.square"
        case .muteTab: ChromeSymbols.Tabs.muted
        case .unmuteTab: ChromeSymbols.Tabs.playingAudio
        case .pauseMedia: ChromeSymbols.Media.pause
        case .playMedia: ChromeSymbols.Media.play
        case .closeOtherTabs: "xmark.square"
        case .findInPage: ChromeSymbols.Navigation.search
        case .zoomIn: "plus.magnifyingglass"
        case .zoomOut: "minus.magnifyingglass"
        case .actualSize: "1.magnifyingglass"
        case .printPage: "printer"
        case .savePage: "square.and.arrow.down"
        case .viewSource: "chevron.left.forwardslash.chevron.right"
        case .pictureInPicture: "pip.enter"
        case .siteSettings: "switch.2"
        case .boostSite: ChromeSymbols.Navigation.boost
        case .showTabsInSidebar, .showTabsOnTop: ChromeSymbols.Tabs.sidebarLayout
        case .hideTabs: "eye.slash"
        case .showTabs: "eye"
        case .reopenClosedTab: "arrow.uturn.backward"
        case .newWindow: "macwindow.badge.plus"
        case .newPrivateWindow: ChromeSymbols.Navigation.privateBrowsing
        case .showLibrary: ChromeSymbols.Navigation.library
        case .showHistory: ChromeSymbols.Navigation.history
        case .settings: ChromeSymbols.Settings.general
        }
    }

    /// Words people might type that aren't in the title.
    var keywords: [String] {
        switch self {
        case .copyURL: ["link", "address"]
        case .pinTab: ["bookmark", "keep"]
        case .unpinTab: ["bookmark", "today"]
        case .addToFavorites: ["favourite", "bookmark", "star"]
        case .newFolder: ["pinned", "group"]
        case .importBookmarks: ["safari", "chrome", "pinned"]
        case .duplicateTab: ["copy", "clone"]
        case .muteTab, .unmuteTab: ["sound", "audio", "silence"]
        case .pauseMedia, .playMedia: ["music", "video", "audio", "resume", "stop"]
        case .closeOtherTabs: ["clean", "tidy"]
        case .findInPage: ["search", "text"]
        case .zoomIn: ["bigger", "larger", "magnify"]
        case .zoomOut: ["smaller"]
        case .actualSize: ["zoom", "reset"]
        case .printPage: ["pdf"]
        case .savePage: ["download", "archive", "html"]
        case .viewSource: ["html", "code", "developer"]
        case .pictureInPicture: ["pip", "video", "float"]
        case .siteSettings: ["permissions", "camera", "microphone", "location", "cookies", "clear", "blocking", "security"]
        case .boostSite: ["customize", "style", "css", "javascript", "zap", "hide", "theme", "font", "color"]
        case .showTabsInSidebar, .showTabsOnTop: ["toggle", "layout", "vertical", "horizontal"]
        case .hideTabs, .showTabs: ["toggle", "sidebar", "immersive"]
        case .reopenClosedTab: ["restore", "undo"]
        case .newWindow: []
        case .newPrivateWindow: ["incognito", "private browsing"]
        case .showLibrary: ["downloads", "archive", "history"]
        case .showHistory: ["recent", "visited"]
        case .settings: ["preferences", "options"]
        }
    }
}
