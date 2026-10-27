import SwiftUI

struct BrowserView: View {
    static let windowID = "browser"
    static let privateWindowID = "private"

    private let appServices: AppServices
    @StateObject private var tabManager: TabManager
    @State private var areTabsVisible = true
    @Environment(\.appearsActive) private var appearsActive
    @Environment(\.openWindow) private var openWindow

    init(appServices: AppServices, isPrivate: Bool = false) {
        self.appServices = appServices
        self._tabManager = StateObject(wrappedValue: Self.makeTabManager(appServices: appServices, isPrivate: isPrivate))
    }

    /// A normal window shows the shared spaces, each browsing with its
    /// profile's context, and is saved with the session. A private window
    /// gets a context of its own and keeps nothing: no spaces, no session, no
    /// pins, and an archive of its own, in memory, for its closed tabs.
    private static func makeTabManager(appServices: AppServices, isPrivate: Bool) -> TabManager {
        let context = isPrivate ? BrowsingContext.makePrivate(over: appServices.browsingContext) : appServices.browsingContext
        return TabManager(
            settings: appServices.settingsStore,
            services: appServices.tabSessionServices(in: context),
            archive: isPrivate ? TabArchive(directory: nil) : appServices.tabArchive,
            pins: isPrivate ? PinStore(fileURL: nil) : appServices.pinStore,
            spaces: isPrivate ? nil : appServices.spaceStore,
            session: isPrivate ? nil : appServices.sessionStore
        )
    }

    var body: some View {
        Group {
            if let activeTab = tabManager.activeTab {
                WindowChromeHost(showsTrafficLights: stripVisible) { window in
                    appServices.sessionStore.attach(window, to: tabManager)
                } content: {
                    BrowserShellView(
                        appServices: appServices,
                        tabManager: tabManager,
                        activeTab: activeTab,
                        areTabsVisible: $areTabsVisible
                    ) {
                        activeTabContent(activeTab)
                    }
                    .overlay {
                        CommandBarOverlay(model: tabManager.commandBar)
                    }
                }
            }
        }
        .background(ChromePalette.shell)
        .environment(\.chromeTheme, tabManager.isPrivate ? .privateBrowsing : tabManager.activeSpace?.theme ?? .system)
        .frame(minWidth: 900, minHeight: 640)
        .focusedSceneObject(tabManager)
        .onAppear {
            areTabsVisible = !tabManager.hideTabs
            guard !tabManager.isPrivate else { return }
            for _ in 0..<appServices.sessionStore.takeWindowsToReopen() {
                openWindow(id: Self.windowID)
            }
        }
        .onDisappear {
            guard !tabManager.isPrivate else { return }
            appServices.sessionStore.untrack(tabManager)
        }
        // Tells the router which window was active last, so links from other
        // apps and from History land here only if this is it. They never land
        // in a private window.
        .onChange(of: appearsActive, initial: true) { _, active in
            guard active, !tabManager.isPrivate, let window = NSApp.keyWindow else { return }
            appServices.externalURLRouter.activate(tabManager, in: window)
        }
        // Links from other apps come to an open window instead of each opening
        // a new one (SwiftUI opens one only if none exists), then go through
        // the router like everything else.
        .handlesExternalEvents(preferring: externalEvents, allowing: externalEvents)
        .onOpenURL { url in
            appServices.externalURLRouter.open([url])
        }
        .sheet(isPresented: isPresent($tabManager.spaceToEdit)) {
            if let id = tabManager.spaceToEdit {
                SpaceEditor(store: appServices.spaceStore, spaceID: id)
            }
        }
        .confirmationDialog(
            "Delete \u{201C}\(spaceToDelete?.name ?? "")\u{201D}?",
            isPresented: isPresent($tabManager.spaceToDelete),
            presenting: spaceToDelete
        ) { space in
            Button("Delete Space", role: .destructive) {
                tabManager.deleteSpace(space.id)
            }
        } message: { _ in
            Text("Its open tabs move to the archive, and its pinned tabs are removed.")
        }
        .onChange(of: tabManager.hideTabs) { _, hide in
            withAnimation(ChromeMotion.shell) {
                areTabsVisible = !hide
            }
        }
        .onChange(of: tabManager.tabLayout) { _, _ in
            withAnimation(ChromeMotion.shell) {
                areTabsVisible = !tabManager.hideTabs
            }
        }
    }

    private var spaceToDelete: Space? {
        tabManager.spaces.first { $0.id == tabManager.spaceToDelete }
    }

    private func isPresent(_ id: Binding<UUID?>) -> Binding<Bool> {
        Binding(get: { id.wrappedValue != nil }, set: { if !$0 { id.wrappedValue = nil } })
    }

    private var externalEvents: Set<String> {
        tabManager.isPrivate ? [] : ["*"]
    }

    private var stripVisible: Bool {
        !tabManager.hideTabs || areTabsVisible
    }

    private func activeTabContent(_ tab: TabSession) -> some View {
        PageView(tab: tab, appServices: appServices)
            .id(tab.id)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transaction { $0.animation = nil }
    }
}
