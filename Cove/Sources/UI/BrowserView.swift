import SwiftUI

struct BrowserView: View {
    static let windowID = "browser"
    static let privateWindowID = "private"

    private let appServices: AppServices
    @StateObject private var tabManager: TabManager
    @State private var areTabsVisible = true
    @Environment(\.appearsActive) private var appearsActive
    @Environment(\.openWindow) private var openWindow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(appServices: AppServices, isPrivate: Bool = false) {
        self.appServices = appServices
        self._tabManager = StateObject(wrappedValue: Self.makeTabManager(appServices: appServices, isPrivate: isPrivate))
    }

    /// A normal window shows the shared profiles, each browsing with its
    /// profile's context, and is saved with the session. A private window
    /// gets a context of its own and keeps nothing: no profiles, no session, no
    /// pins, no notes, and an archive of its own, in memory, for its closed tabs.
    private static func makeTabManager(appServices: AppServices, isPrivate: Bool) -> TabManager {
        let context = isPrivate ? BrowsingContext.makePrivate(over: appServices.browsingContext) : appServices.browsingContext
        return TabManager(
            settings: appServices.settingsStore,
            services: appServices.tabSessionServices(in: context),
            archive: isPrivate ? TabArchive(directory: nil) : appServices.tabArchive,
            pins: isPrivate ? PinStore(fileURL: nil) : appServices.pinStore,
            profiles: isPrivate ? nil : appServices.profileStore,
            documents: isPrivate ? nil : appServices.documentStore,
            session: isPrivate ? nil : appServices.sessionStore
        )
    }

    var body: some View {
        Group {
            if let activeTab = tabManager.activeTab {
                WindowChromeHost(showsTrafficLights: stripVisible) { window in
                    appServices.sessionStore.attach(window, to: tabManager)
                    tabManager.extensionWindow.attach(window)
                } content: {
                    BrowserShellView(
                        appServices: appServices,
                        tabManager: tabManager,
                        activeTab: activeTab,
                        areTabsVisible: $areTabsVisible
                    ) {
                        activeTabContent(activeTab)
                    }
                }
            }
        }
        .animatedChromeTheme(tabManager.isPrivate ? .privateBrowsing : tabManager.activeProfile?.theme ?? .system,
                             profiles: tabManager.profiles, transition: tabManager.profileTransition)
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
            tabManager.extensionWindow.close()
            guard !tabManager.isPrivate else { return }
            appServices.sessionStore.untrack(tabManager)
        }
        // Tells the router which window was active last, so links from other
        // apps and from History land here only if this is it. They never land
        // in a private window.
        .onChange(of: appearsActive, initial: true) { _, active in
            guard active, !tabManager.isPrivate, let window = NSApp.keyWindow else { return }
            appServices.externalURLRouter.activate(tabManager, in: window, openWindow: openWindow)
        }
        // Links from other apps come to an open window instead of each opening
        // a new one (SwiftUI opens one only if none exists), then go through
        // the router like everything else.
        .handlesExternalEvents(preferring: externalEvents, allowing: externalEvents)
        .onOpenURL { url in
            appServices.externalURLRouter.open([url], from: .otherApp)
        }
        .confirmationDialog(
            "Delete \u{201C}\(profileToDelete?.name ?? "")\u{201D}?",
            isPresented: isPresent($tabManager.profileToDelete),
            presenting: profileToDelete
        ) { profile in
            Button("Delete Profile", role: .destructive) {
                tabManager.deleteProfile(profile.id)
            }
        } message: { _ in
            Text("This deletes its tabs, history, and site data. Other profiles are not changed.")
        }
        .confirmationDialog(
            "Delete \u{201C}\(documentToDelete?.displayTitle ?? "")\u{201D}?",
            isPresented: isPresent($tabManager.documentToDelete),
            presenting: documentToDelete
        ) { document in
            Button("Delete \(document.kind.name)", role: .destructive) {
                tabManager.deleteDocument(document.id)
            }
        } message: { _ in
            Text("It's removed from every profile, and can't be brought back.")
        }
        .onChange(of: tabManager.hideTabs) { _, hide in
            withAnimation(reduceMotion ? nil : ChromeMotion.shell) {
                areTabsVisible = !hide
            }
        }
        .onChange(of: tabManager.tabLayout) { _, _ in
            withAnimation(reduceMotion ? nil : ChromeMotion.shell) {
                areTabsVisible = !tabManager.hideTabs
            }
        }
    }

    private var documentToDelete: DocumentInfo? {
        tabManager.documentToDelete.flatMap { tabManager.documentStore?.documents[$0] }
    }

    private var profileToDelete: Profile? {
        tabManager.profiles.first { $0.id == tabManager.profileToDelete }
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

    /// The page on screen, or the split holding it, with the drop zones for
    /// splitting and the Peek over all of it; or a note in its place.
    private func activeTabContent(_ tab: TabSession) -> some View {
        Group {
            if let id = tabManager.activeDocumentID, let store = tabManager.documentStore {
                DocumentPage(id: id, store: store, tabManager: tabManager)
                    .id(id)
            } else if let split = tabManager.activeSplit {
                SplitPageView(split: split, tabManager: tabManager, appServices: appServices)
            } else {
                PageView(tab: tab, appServices: appServices, showsLoadingProgress: false)
                    .overlay { BoostEditorOverlay(tabManager: tabManager, page: tab) }
                    .overlay { CaptureOverlay(tabManager: tabManager, page: tab) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transaction { $0.animation = nil }
        .overlay { SplitDropZones(tabManager: tabManager) }
        .overlay { PeekOverlay(tabManager: tabManager, appServices: appServices) }
    }
}
