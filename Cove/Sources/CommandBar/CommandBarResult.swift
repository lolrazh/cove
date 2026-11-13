import Foundation

/// One row in the Command Bar. Identity comes from the kind and its payload, so
/// a selection survives the list refreshing around it.
struct CommandBarResult: Identifiable, Hashable {
    enum Kind: Hashable {
        /// An open tab in this window.
        case tab(UUID)
        /// A tab in the archive, reopened with its back/forward list.
        case archived(UUID)
        /// Another profile, to switch to.
        case profile(UUID)
        /// An extension's button, by its context's unique identifier.
        case extensionAction(String)
        /// A note, found by its title or its words.
        case document(UUID, DocumentKind)
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
    case newFolder
    case newNote
    case newEasel
    case importBookmarks
    case newProfile
    case editProfile
    case duplicateTab
    case addSplitView
    case rotateSplitView
    case separateSplitView
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
    case capture
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
    case newLittleCove
    case showLibrary
    case showHistory
    case extensions
    case settings

    var title: String {
        switch self {
        case .copyURL: "Copy URL"
        case .pinTab: "Pin Tab"
        case .unpinTab: "Unpin Tab"
        case .newFolder: "New Folder"
        case .newNote: "New Note"
        case .newEasel: "New Easel"
        case .importBookmarks: "Import Bookmarks"
        case .newProfile: "New Profile"
        case .editProfile: "Edit Profile"
        case .duplicateTab: "Duplicate Tab"
        case .addSplitView: "Add Split View"
        case .rotateSplitView: "Rotate Split View"
        case .separateSplitView: "Separate Split View"
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
        case .capture: "Capture"
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
        case .newLittleCove: "New Little Cove Window"
        case .showLibrary: "Library"
        case .showHistory: "Show All History"
        case .extensions: "Extensions"
        case .settings: "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .copyURL: "link"
        case .pinTab: ChromeSymbols.Tabs.pin
        case .unpinTab: ChromeSymbols.Tabs.unpin
        case .newFolder: ChromeSymbols.Tabs.folder
        case .newNote: ChromeSymbols.Documents.newNote
        case .newEasel: ChromeSymbols.Documents.easel
        case .importBookmarks: "square.and.arrow.down.on.square"
        case .newProfile: ChromeSymbols.Settings.profiles
        case .editProfile: "pencil"
        case .duplicateTab: "plus.square.on.square"
        case .addSplitView: ChromeSymbols.Tabs.splitView
        case .rotateSplitView: ChromeSymbols.Tabs.splitVertically
        case .separateSplitView: "rectangle"
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
        case .capture: ChromeSymbols.Capture.capture
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
        case .newLittleCove: ChromeSymbols.Tabs.littleCove
        case .showLibrary: ChromeSymbols.Navigation.library
        case .showHistory: ChromeSymbols.Navigation.history
        case .extensions: ChromeSymbols.Extensions.extensions
        case .settings: ChromeSymbols.Settings.general
        }
    }

    /// Words people might type that aren't in the title.
    var keywords: [String] {
        switch self {
        case .copyURL: ["link", "address"]
        case .pinTab: ["bookmark", "keep"]
        case .unpinTab: ["bookmark", "today"]
        case .newFolder: ["pinned", "group"]
        case .newNote: ["write", "text", "document", "jot"]
        case .newEasel: ["canvas", "board", "draw", "sketch", "whiteboard", "clipping"]
        case .importBookmarks: ["safari", "chrome", "pinned"]
        case .newProfile: ["create", "add", "profile"]
        case .editProfile: ["rename", "icon", "color", "theme", "profile"]
        case .duplicateTab: ["copy", "clone"]
        case .addSplitView: ["side by side", "pane", "tile"]
        case .rotateSplitView: ["vertical", "horizontal", "stack", "side by side"]
        case .separateSplitView: ["unsplit", "pane"]
        case .muteTab, .unmuteTab: ["sound", "audio", "silence"]
        case .pauseMedia, .playMedia: ["music", "video", "audio", "resume", "stop"]
        case .closeOtherTabs: ["clean", "tidy"]
        case .findInPage: ["search", "text"]
        case .zoomIn: ["bigger", "larger", "magnify"]
        case .zoomOut: ["smaller"]
        case .actualSize: ["zoom", "reset"]
        case .printPage: ["pdf"]
        case .savePage: ["download", "archive", "html"]
        case .capture: ["screenshot", "snapshot", "image", "clip", "region", "element"]
        case .viewSource: ["html", "code", "developer"]
        case .pictureInPicture: ["pip", "video", "float"]
        case .siteSettings: ["permissions", "camera", "microphone", "location", "cookies", "clear", "blocking", "security"]
        case .boostSite: ["customize", "style", "css", "javascript", "zap", "hide", "theme", "font", "color"]
        case .showTabsInSidebar, .showTabsOnTop: ["toggle", "layout", "vertical", "horizontal"]
        case .hideTabs, .showTabs: ["toggle", "sidebar", "immersive"]
        case .reopenClosedTab: ["restore", "undo"]
        case .newWindow: []
        case .newPrivateWindow: ["incognito", "private browsing"]
        case .newLittleCove: ["little arc", "mini", "small", "quick"]
        case .showLibrary: ["downloads", "archive", "history"]
        case .showHistory: ["recent", "visited"]
        case .extensions: ["add-ons", "plugins", "manage", "load", "unpacked"]
        case .settings: ["preferences", "options"]
        }
    }
}

/// Find the typed part without assuming ASCII or equal UTF-16 lengths.
/// The same row stays in place while this range grows with each keystroke.
enum SuggestionMatch {
    static func range(in suggestion: String, query: String) -> Range<String.Index>? {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nil }
        return suggestion.range(of: query, options: [.caseInsensitive, .diacriticInsensitive])
    }

    static func continuations(_ items: [String], for query: String) -> [String] {
        items.filter { $0.range(of: query, options: [.anchored, .caseInsensitive, .diacriticInsensitive]) != nil }
    }
}
