import SwiftUI
import Foundation
import Combine

enum TabLayout: String {
    case horizontal
    case sidebar
}

@MainActor
final class TabManager: ObservableObject {
    /// The profile the window shows, whose tabs everything below is about. A
    /// private window has one profile, which it never names or leaves.
    @Published private(set) var activeProfileID: UUID
    /// A profile being named or edited, for the window's profile editor.
    @Published var profileToEdit: UUID?
    /// A profile waiting for its deletion to be confirmed.
    @Published var profileToDelete: UUID?
    /// The profile's Today in display order, shared by the sidebar and top strip.
    /// New tabs append; links open next to their opener. Notes keep their places.
    @Published var today: [TodayItem<TabSession>] = [] {
        // A tab that leaves Today leaves its split.
        didSet { pruneSplits() }
    }
    /// The profile's tabs shown side by side. A split's tabs stay in `tabs`,
    /// kept next to each other, and show as one entry; selecting any of them
    /// shows the split with that pane focused. Changed through the Split View
    /// calls.
    @Published var splits: [TabSplit<UUID>] = []
    /// A live tab for each pin in this profile, with optional folders.
    /// Built from the store, so every window shows the same pins with tabs of
    /// its own.
    @Published private(set) var pinned = SidebarTree<TabSession>()
    /// A folder just made, for the sidebar to offer a name for.
    @Published var folderToName: UUID?
    /// The selected tab, and in a split the focused pane: what navigation,
    /// the URL pill, page tools and site controls act on. The tabs on screen
    /// are always awake; the others may sleep once they've been left alone
    /// long enough.
    @Published var activeTabID: UUID? {
        didSet {
            // Selecting a tab puts its page back on screen.
            activeDocumentID = nil
            // A Peek or a capture belongs to the page it was opened over.
            closePeek()
            endCapture()
            oldValue.flatMap(tab)?.markUsed()
            activeTab?.markUsed()
            shownTabs.forEach { $0.wake() }
        }
    }
    /// The note on screen in place of the active tab's page, if any. Set
    /// through `showDocument`; selecting a tab clears it.
    @Published var activeDocumentID: UUID?
    /// A note waiting for its deletion to be confirmed.
    @Published var documentToDelete: UUID?
    /// The tab being dragged in the sidebar or the strip, for the lists and
    /// the page's split drop zones to follow.
    @Published var draggedTabID: UUID?
    @Published var tabLayout: TabLayout
    @Published private(set) var hideTabs: Bool
    /// The background tab the media player controls.
    @Published private(set) var mediaTab: TabSession?
    /// A link opened over the page, as in Arc's Peek: a tab of its own, in no
    /// list, until it's closed or expanded into Today. Set through
    /// `openPeek`, `closePeek` and `expandPeek`.
    @Published var peek: Peek?
    /// Whether the active page's site controls are open.
    @Published var isShowingSiteControls = false
    /// The Boost editor, open over the page it was opened from.
    @Published var boostEditor: BoostEditor?
    /// Capture, over the page it was started on.
    @Published var capture: CaptureSession?
    /// Confirmations shown over this window's page.
    let toasts = ToastCenter()
    let profileTransition = ProfileTransition()
    /// The window as extensions see it.
    let extensionWindow = ExtensionWindow()

    let settings: BrowserSettingsStore
    private let baseServices: TabSessionServices
    var services: TabSessionServices { services(for: activeProfile) }
    /// Where this window's closed and idle tabs go: the shared archive, or a
    /// private window's own, kept in memory and gone with the window.
    private let baseArchive: TabArchive
    var archive: TabArchive { services.context.profileData?.archive ?? baseArchive }
    /// The shared pins, or a private window's own empty, unsaved ones.
    let pinStore: PinStore
    /// The shared profiles; none in a private window.
    private let profileStore: ProfileStore?
    /// The notes; none in a private window, which keeps nothing.
    private let baseDocuments: DocumentStore?
    var documentStore: DocumentStore? { isPrivate ? nil : services.context.profileData?.documents ?? baseDocuments }
    private var documentChanges: AnyCancellable?
    /// The profiles as last published, which edits are checked against.
    private var knownProfiles: Profiles
    /// The window's other profiles, as it left them.
    private var parkedProfiles: [UUID: ParkedProfile] = [:]
    private let sweepClock = TabSweepClock()
    private var cancellables: Set<AnyCancellable> = []
    /// The live tab behind each pin, by the pin's ID, and what keeps the
    /// store up to date with where it is.
    private var pinnedTabs: [UUID: TabSession] = [:]
    private var pinnedTabRecorders: [UUID: AnyCancellable] = [:]

    /// This window's Command Bar. Lazy only because it needs `self`.
    private(set) lazy var commandBar = CommandBarModel(tabManager: self, settings: settings)
    private(set) lazy var library = LibraryModel(tabManager: self)

    var activeTab: TabSession? {
        activeTabID.flatMap(tab)
    }

    /// Any tab in the profile: in Today, Pinned.
    func tab(_ id: UUID) -> TabSession? {
        allTabs.first { $0.id == id }
    }

    /// Today's tabs, oldest first.
    var tabs: [TabSession] {
        today.compactMap(\.tab)
    }

    /// Today as the sidebar and the strip show it, a split as one entry.
    var todayEntries: [TabEntry<TabSession>] {
        today.entries(splits: splits)
    }

    var allTabs: [TabSession] {
        pinned.tabs + tabs
    }

    /// The tabs as they're shown: Pinned, then Today, top to
    /// bottom in the sidebar or left to right in the strip. Switching with
    /// the keyboard, dragging, and Close Tabs Below all follow this order.
    var tabsInDisplayOrder: [TabSession] {
        tabLayout.displayOrder(pinned: pinned, today: tabs)
    }

    /// A private window passes an in-memory archive and no session, profiles
    /// or documents, so nothing of it is written down or comes back. `services`
    /// browse with the default profile, or the private window's own context.
    init(
        settings: BrowserSettingsStore,
        services: TabSessionServices,
        archive: TabArchive,
        pins: PinStore,
        profiles: ProfileStore?,
        documents: DocumentStore?,
        session: SessionStore?
    ) {
        let saved = session?.takeRestorableWindow()
        let knownProfiles = profiles?.profiles ?? Profiles()
        self.settings = settings
        self.baseServices = services
        self.baseArchive = archive
        self.pinStore = pins
        self.profileStore = profiles
        self.baseDocuments = documents
        self.knownProfiles = knownProfiles
        self.activeProfileID = saved.flatMap { knownProfiles.profile($0.activeProfileID)?.id } ?? knownProfiles.profiles[0].id
        self.tabLayout = settings.showsTabsInSidebar ? .sidebar : .horizontal
        self.hideTabs = settings.hideTabs
        bindSettings()
        trackMedia()
        sweepClock.ticks
            .sink { [weak self] underMemoryPressure in self?.sweepIdleTabs(underMemoryPressure: underMemoryPressure) }
            .store(in: &cancellables)
        profiles?.$profiles
            .dropFirst()
            .sink { [weak self] profiles in self?.reconcileProfiles(with: profiles) }
            .store(in: &cancellables)
        pins.$layout
            .sink { [weak self] layout in self?.reconcilePinnedTabs(with: layout) }
            .store(in: &cancellables)
        trackDocuments()

        restore(saved)
        session?.track(self, placement: saved?.placement)
        extensionWindow.track(self)
    }

    /// Restored tabs start asleep; selecting the active one wakes it, so a
    /// launch loads one page per window instead of every page. Profiles deleted
    /// since are left behind, and so are documents.
    private func restore(_ saved: SavedWindow?) {
        var shown: ParkedProfile?
        for savedProfile in saved?.profiles ?? [] {
            guard let profile = knownProfiles.profile(savedProfile.profileID) else { continue }
            let services = services(for: profile)
            let tabs = savedProfile.tabs.map { makeTab(restoring: $0, services: services) }
            let documents = (savedProfile.documents ?? []).filter { services.context.profileData?.documents.documents[$0.id] != nil || baseDocuments?.documents[$0.id] != nil }
            let restored = ParkedProfile(
                today: TodayItem.restoring(tabs: tabs, documents: documents),
                activeTabID: savedProfile.activePinID
                    ?? savedProfile.activeTabIndex.flatMap { tabs.indices.contains($0) ? tabs[$0].id : nil },
                activeDocumentID: savedProfile.activeDocumentID,
                splits: (savedProfile.splits ?? []).compactMap { split in
                    split.map { tabs.indices.contains($0) ? tabs[$0].id : nil }
                }
            )
            if profile.id == activeProfileID {
                shown = restored
            } else {
                parkedProfiles[profile.id] = restored
            }
        }
        unpark(shown)
    }

    var isPrivate: Bool {
        baseServices.context.isPrivate
    }

    var savedWindow: SavedWindow {
        let parked = knownProfiles.profiles.compactMap { profile in
            parkedProfiles[profile.id].map { savedProfile(profile.id, $0) }
        }
        return SavedWindow(
            profiles: [savedProfile(activeProfileID, shownProfile)] + parked,
            activeProfileID: activeProfileID
        )
    }

    private func savedProfile(_ id: UUID, _ profile: ParkedProfile) -> SavedProfile {
        let tabs = profile.today.compactMap(\.tab)
        return SavedProfile(
            profileID: id,
            tabs: tabs.map(\.savedTab),
            activeTabIndex: tabs.firstIndex { $0.id == profile.activeTabID },
            activePinID: profile.activeTabID.flatMap { pinnedTabs[$0] == nil ? nil : $0 },
            splits: profile.splits.compactMap { split in split.map { id in tabs.firstIndex { $0.id == id } } },
            documents: profile.today.documentPlaces(),
            activeDocumentID: profile.activeDocumentID
        )
    }

    func setLayout(_ layout: TabLayout) {
        guard tabLayout != layout else { return }
        tabLayout = layout
        settings.setShowsTabsInSidebar(layout == .sidebar)
    }

    func setHideTabs(_ hide: Bool) {
        guard hideTabs != hide else { return }
        hideTabs = hide
        settings.setHideTabs(hide)
    }

    /// What ⌘T and the New Tab buttons do: ask where to go first, or open a
    /// tab holding the start page, as Settings says.
    func newTab() {
        if settings.newTabPreference == .commandBar {
            commandBar.present(.newTab)
        } else {
            addTab()
        }
    }

    /// ⌘L and the URL pill: the current address, ready to be changed. A
    /// note has no address, so over one it asks where to go in a new tab.
    func editCurrentURL() {
        commandBar.present(activeDocumentID == nil ? .editURL : .newTab)
    }

    /// Opens a tab at the end of the strip or bottom of Today. Tabs
    /// opened from a link instead go next to their opener.
    func addTab(url: String? = nil) {
        let tab: TabSession

        if let url {
            tab = makeTab(initialURL: url, showsStartPage: false)
        } else {
            switch settings.destinationForNewTab() {
            case .startPage:
                tab = makeTab(showsStartPage: true)
            case .url(let destination):
                tab = makeTab(initialURL: destination, showsStartPage: false)
            }
        }

        open(tab)
    }

    func addTab(request: URLRequest, nextTo openerID: UUID? = nil) {
        // A background page can open a child after the user switches profiles.
        // Keep that child with its opener, on the opener's browsing context.
        if let openerID, let owner = profiles.first(where: { profile in
            profile.id != activeProfileID && (parkedProfiles[profile.id]?.today.contains { $0.id == openerID } == true
                || pinStore.pins(in: profile.id).pin(openerID) != nil)
        }) {
            let tab = makeTab(initialRequest: request, showsStartPage: false, services: services(for: owner))
            if parkedProfiles[owner.id] == nil { parkedProfiles[owner.id] = ParkedProfile(today: [], activeTabID: nil, activeDocumentID: nil, splits: []) }
            parkedProfiles[owner.id]?.today.append(.tab(tab))
            if parkedProfiles[owner.id]?.activeTabID == nil { parkedProfiles[owner.id]?.activeTabID = tab.id }
            return
        }
        let tab = makeTab(initialRequest: request, showsStartPage: false)
        open(tab, nextTo: openerID ?? activeTabID)
    }

    /// Opens a link from outside the window in a new tab, reusing the window's
    /// only tab if it's still an untouched start page.
    func openExternalURL(_ url: URL) {
        if let startPage = untouchedStartPage {
            startPage.navigate(url.absoluteString)
        } else {
            addTab(url: url.absoluteString)
        }
    }

    /// Takes in a live tab from a Peek or Little Cove, page and history
    /// included: beside the tab that opened it, or at the top of the profile's
    /// Today, in place of an untouched start page. It's selected. A page
    /// from another profile than the profile's starts again on the profile's.
    func adoptTab(_ tab: TabSession, nextTo openerID: UUID? = nil) {
        let startPage = untouchedStartPage
        let adopted = rehomed(tab, in: activeProfile) ?? tab
        adopted.host = host(for: tab.id)
        open(adopted, nextTo: openerID)
        startPage.map { closeTab($0.id) }
    }

    /// The window's only tab, while it's still a start page nobody has used.
    private var untouchedStartPage: TabSession? {
        guard tabs.count == 1, let tab = tabs.first, tab.id == activeTabID, tab.isNewTabPage, tab.currentURL.isEmpty else { return nil }
        return tab
    }

    private func bindSettings() {
        settings.$showsTabsInSidebar
            .removeDuplicates()
            .sink { [weak self] showsTabsInSidebar in
                guard let self else { return }
                let resolvedLayout: TabLayout = showsTabsInSidebar ? .sidebar : .horizontal
                guard self.tabLayout != resolvedLayout else { return }
                self.tabLayout = resolvedLayout
            }
            .store(in: &cancellables)

        settings.$hideTabs
            .removeDuplicates()
            .sink { [weak self] hideTabs in
                guard let self, self.hideTabs != hideTabs else { return }
                self.hideTabs = hideTabs
            }
            .store(in: &cancellables)
    }

    /// Keeps `mediaTab` current as tabs play, pause, open, close and get
    /// selected. `@Published` announces a change before making it, so the
    /// pick waits a turn of the main queue to see it.
    private func trackMedia() {
        let mediaChanged = Publishers.CombineLatest($today, $pinned)
            .map { today, pinned in
                Publishers.MergeMany((pinned.tabs + today.compactMap(\.tab)).map { $0.$nowPlaying.map { _ in } })
            }
            .switchToLatest()
        Publishers.Merge(mediaChanged, $activeTabID.map { _ in })
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.updateMediaTab() }
            .store(in: &cancellables)
    }

    private func updateMediaTab() {
        let tab = tabsInDisplayOrder
            .filter { $0.id != activeTabID }
            .preferringPlaying(\.nowPlaying)
        if tab !== mediaTab {
            mediaTab = tab
        }
    }

    /// A tab in the profile shown, unless the services of another are given.
    private func makeTab(
        id tabID: UUID = UUID(),
        initialURL: String? = nil,
        initialRequest: URLRequest? = nil,
        showsStartPage: Bool = false,
        restoring saved: SavedTab? = nil,
        services tabServices: TabSessionServices? = nil
    ) -> TabSession {
        TabSession(
            id: tabID,
            initialURL: initialURL,
            initialRequest: initialRequest,
            restoring: saved,
            showsStartPage: saved.map { $0.url.isEmpty } ?? showsStartPage,
            settings: settings,
            services: tabServices ?? services(for: activeProfile),
            host: host(for: tabID)
        )
    }

    /// What a tab in this window does when it needs to be on screen or opens
    /// a page: it's selected, pages open beside it or in a Peek, and its
    /// context menu captures it.
    private func host(for tabID: UUID) -> TabSession.Host {
        TabSession.Host(
            select: { [weak self] in self?.selectTab(tabID) },
            openInNewTab: { [weak self] request in self?.addTab(request: request, nextTo: tabID) },
            peek: { [weak self] request in self?.openPeek(request, from: tabID) },
            capture: { [weak self] in
                self?.selectTab(tabID)
                self?.startCapture()
            }
        )
    }

    /// Next to the opener goes past the rest of its split, which stays together.
    private func open(_ tab: TabSession, nextTo openerID: UUID? = nil) {
        if let openerID,
           let openerIndex = today.lastIndex(where: { splitGroup(of: openerID).contains($0.id) }) {
            today.insert(.tab(tab), at: openerIndex + 1)
        } else {
            today.append(.tab(tab))
        }

        activeTabID = tab.id
    }

    /// Closes a Today tab. The last tab leaves a fresh start page. The next
    /// newer tab takes its place on screen, else the next older, else the
    /// pinned tab nearest Today. A pinned tab is kept: closing it resets it.
    func closeTab(_ id: UUID) {
        if let tab = pinnedTabs[id] {
            closePinnedTab(tab)
            return
        }
        guard let index = today.firstIndex(where: { $0.id == id }), let tab = today[index].tab else { return }
        if allTabs.count == 1 {
            // Install the start page first so observers never see an invalid selection.
            open(makeTab(showsStartPage: true))
        }

        let wasActive = (id == activeTabID)
        // In a split, the neighboring pane takes the focus.
        let neighbor = split(containing: id)?.neighbor(of: id)
            ?? tabs.neighborWhenClosing(id)?.id
        // Into the archive, as in Arc, where it keeps its back/forward list
        // for Reopen Last Closed Tab.
        if wasActive {
            activeTabID = neighbor ?? allTabs.first(where: { $0.id != id })?.id
        }
        today.remove(at: index)
        retire(tab, reason: .closed)
    }

    /// Today tabs can always close. A pinned tab resets while awake or away from its pin.
    func canCloseTab(_ id: UUID) -> Bool {
        if let tab = pinnedTabs[id] { return !tab.isAsleep || tab.isAwayFromPin }
        return today.contains { $0.id == id && $0.tab != nil }
    }

    /// Reopens the most recently closed tab.
    func reopenClosedTab() {
        guard let closed = archive.lastClosed else { return }
        reopenArchivedTab(closed.id)
    }

    // MARK: - Idle tabs

    /// Sleeps background tabs idle past the setting and archives Today tabs
    /// idle past theirs; pinned tabs sleep but stay. Short of
    /// memory, every background tab that can sleep does.
    func sweepIdleTabs(underMemoryPressure: Bool = false, now: Date = .now) {
        var policy = TabIdlePolicy(
            sleepAfter: settings.sleepTabsAfter.interval,
            archiveAfter: isPrivate ? nil : settings.archiveTabsAfter.interval
        )
        if underMemoryPressure {
            policy = policy.underMemoryPressure
        }

        for tab in tabs {
            switch policy.action(for: TabIdlePolicy.Tab(tab, isActive: isShown(tab.id)), at: now) {
            case .sleep: tab.sleep()
            case .archive: archiveTab(tab.id)
            case nil: break
            }
        }
        // Other profiles' tabs aren't on screen, their selected ones included.
        for id in parkedProfiles.keys {
            parkedProfiles[id]?.today.removeAll { item in
                guard let tab = item.tab else { return false }
                let action = policy.action(for: TabIdlePolicy.Tab(tab, isActive: false), at: now)
                if action == .sleep { tab.sleep() }
                if action == .archive { retire(tab, reason: .idle) }
                return action == .archive
            }
        }
        sweepIdleDocuments(policy: policy, now: now)
        for tab in pinnedTabs.values
        where policy.neverArchiving.action(for: TabIdlePolicy.Tab(tab, isActive: isShown(tab.id)), at: now) == .sleep {
            tab.sleep()
        }
    }

    /// Moves a background tab out of Today and into the archive, with its
    /// back/forward list, so it can come back whole.
    private func archiveTab(_ id: UUID) {
        guard !isShown(id), let index = today.firstIndex(where: { $0.id == id }), let tab = today[index].tab else { return }
        today.remove(at: index)
        retire(tab, reason: .idle)
    }

    /// A tab leaving the window goes into the archive.
    private func retire(_ tab: TabSession, reason: ArchivedTab.Reason) {
        tab.close()
        (tab.services.context.profileData?.archive ?? baseArchive).add(tab.savedTab, reason: reason)
    }

    /// Brings an archived tab back into Today, selected.
    func reopenArchivedTab(_ id: UUID) {
        guard let saved = archive.take(id) else { return }
        open(makeTab(restoring: saved))
    }

    /// Selects a tab, first switching to its profile if it's in another.
    func selectTab(_ id: UUID) {
        guard id != activeTabID || activeDocumentID != nil else { return }
        if tab(id) == nil, let profile = parkedProfiles.first(where: { $0.value.today.contains { $0.id == id } })?.key {
            show(profile)
        }
        // A closing row can deliver its click after the tab has left Today.
        guard tab(id) != nil else { return }
        activeTabID = id
    }

    /// Selects the tab if it's in the profile, or else the newest Today tab, or
    /// else a new one.
    private func select(_ id: UUID?) {
        if let id, tab(id) != nil {
            selectTab(id)
        } else if let newest = tabs.last {
            selectTab(newest.id)
        } else {
            addTab()
        }
    }

    /// ⌃Tab and ⌃⇧Tab: the next or previous tab as shown, wrapping around.
    func selectAdjacentTab(_ offset: Int) {
        guard let activeTabID, let tab = tabsInDisplayOrder.element(offset, from: activeTabID) else { return }
        selectTab(tab.id)
    }

    /// ⌘1 to ⌘8 select a tab by its place, ⌘9 the last one.
    func selectTab(forShortcut number: Int) {
        guard let tab = tabsInDisplayOrder.element(forShortcut: number) else { return }
        selectTab(tab.id)
    }

    /// A copy of the tab beside it in Today, back and forward history included.
    func duplicateTab(_ id: UUID) {
        guard let tab = tab(id) else { return }
        open(makeTab(restoring: tab.savedTab), nextTo: id)
    }

    /// ⌘W: the note on screen, or else the active tab.
    func closeActiveTab() {
        if let activeDocumentID {
            closeDocument(activeDocumentID)
        } else if let activeTabID {
            closeTab(activeTabID)
        }
    }

    /// Closes every tab but this one, which stays as the active tab.
    func closeOtherTabs(keeping id: UUID) {
        selectTab(id)
        for tab in tabs where tab.id != id {
            closeTab(tab.id)
        }
    }

    /// Closes the Today tabs shown after this one: below it in the sidebar, to
    /// its right in the strip. It becomes active if the active tab is among them.
    func closeTabs(below id: UUID) {
        let closing = tabsInDisplayOrder.elements(after: id).filter { pinnedTabs[$0.id] == nil }
        if closing.contains(where: { $0.id == activeTabID }) {
            selectTab(id)
        }
        for tab in closing {
            closeTab(tab.id)
        }
    }

    /// ⌘⇧C, the Command Bar and a tab's Copy Link: the page's address to the
    /// pasteboard, the active tab's unless another is given.
    func copyURL(of tab: TabSession? = nil) {
        guard let url = (tab ?? activeTab)?.currentURL, !url.isEmpty else { return }
        copyLink(url)
    }

    /// Any page's address to the pasteboard, like the Library's Copy Link.
    func copyLink(_ url: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
        toasts.show("Copied URL", symbol: ChromeSymbols.Navigation.link)
    }

    // MARK: - Pinned tabs

    enum TabSection {
        case pinned
        case today
    }

    func section(of id: UUID) -> TabSection? {
        switch pinStore.pins(in: activeProfileID).section(of: id) {
        case .pinned: .pinned
        case nil: today.contains { $0.id == id } ? .today : nil
        }
    }

    /// ⌘D and Pin Tab: a Today tab moves into Pinned, where
    /// it's kept across launches. A start page has nothing to pin.
    func pinTab(_ id: UUID, to section: Pins.Section = .pinned, at position: SidebarPosition = .end) {
        guard let index = today.firstIndex(where: { $0.id == id }), let tab = today[index].tab, !tab.currentURL.isEmpty else { return }
        today.remove(at: index)
        tab.pinnedURL = tab.currentURL
        adoptPinnedTab(tab)
        pinStore.change(in: activeProfileID) { $0.add(Pin(id: id, url: tab.currentURL, title: tab.pageTitle), to: section, at: position) }
    }

    /// Unpin Tab: the live tab goes back to Today, at the top, or in the
    /// place of the tab it was dropped on.
    func unpinTab(_ id: UUID, onto target: UUID? = nil) {
        guard let tab = pinnedTabs[id] else { return }
        releasePinnedTab(tab, onto: target)
        pinStore.change(in: activeProfileID) { $0.remove(id) }
    }

    func togglePinned(_ id: UUID) {
        pinnedTabs[id] == nil ? pinTab(id) : unpinTab(id)
    }

    /// Drag and drop: the dragged tab takes the place of the one under it,
    /// moving between Pinned and Today as needed.
    func moveTab(_ id: UUID, onto target: UUID) {
        guard id != target, let from = section(of: id), let to = section(of: target) else { return }
        switch (from, to) {
        case (.today, .today): today.move(splitGroup(of: id), onto: splitGroup(of: target))
        case (.today, .pinned) where isDocument(id): pinDocument(id, at: .before(target))
        case (.today, .pinned): pinTab(id, to: .pinned, at: .before(target))
        case (.pinned, .today) where isDocument(id): unpinDocument(id, onto: target)
        case (.pinned, .today): unpinTab(id, onto: target)
        case (.pinned, _): pinStore.change(in: activeProfileID) { $0.move(id, onto: target) }
        }
    }

    /// A tab dropped on a folder goes in at the end of it.
    func moveTab(_ id: UUID, into folderID: UUID) {
        moveTab(id, to: .pinned, at: .into(folderID))
    }

    /// A tab dropped on a section's empty space goes to the end of it.
    func moveTab(_ id: UUID, toEndOf section: Pins.Section) {
        moveTab(id, to: section, at: .end)
    }

    /// Documents go in Pinned only.
    private func moveTab(_ id: UUID, to section: Pins.Section, at position: SidebarPosition) {
        if self.section(of: id) != .today {
            pinStore.change(in: activeProfileID) { $0.move(id, to: section, at: position) }
        } else if !isDocument(id) {
            pinTab(id, to: section, at: position)
        } else if section == .pinned {
            pinDocument(id, at: position)
        }
    }

    /// Closing a pinned tab keeps it: the next tab takes its place on screen
    /// and it goes back to its pinned address, asleep.
    private func closePinnedTab(_ tab: TabSession) {
        if tab.id == activeTabID, let next = tabsInDisplayOrder.element(1, from: tab.id), next.id != tab.id {
            selectTab(next.id)
        }
        tab.resetToPin(title: pinStore.layout.pin(tab.id)?.title ?? "")
        if tab.id == activeTabID {
            tab.wake()
        }
    }

    // MARK: Folders

    /// New Folder: an empty folder at the end of Pinned, or inside another,
    /// or one made around a pinned tab in its place. The sidebar then asks
    /// for its name.
    func newFolder(in parentID: UUID? = nil, around tabID: UUID? = nil) {
        let folder = SidebarFolder<Pin>(name: "New Folder")
        pinStore.change(in: activeProfileID) { pins in
            if let tabID, pins.section(of: tabID) == .pinned {
                pins.addFolder(folder, at: .before(tabID))
                pins.move(tabID, to: .pinned, at: .into(folder.id))
            } else {
                pins.addFolder(folder, at: parentID.map(SidebarPosition.into) ?? .end)
            }
        }
        folderToName = folder.id
    }

    /// An empty name leaves the folder as it was.
    func renameFolder(_ id: UUID, to name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        pinStore.change(in: activeProfileID) { $0.updateFolder(id) { $0.name = name } }
    }

    func toggleFolderCollapsed(_ id: UUID) {
        pinStore.change(in: activeProfileID) { $0.updateFolder(id) { $0.isCollapsed.toggle() } }
    }

    /// Deleting a folder unpins what it held: the tabs and notes go back to
    /// Today.
    func deleteFolder(_ id: UUID) {
        let contents = pinStore.pins(in: activeProfileID).pinned.folder(id)?.contents ?? SidebarTree()
        for pin in contents.tabs {
            pinnedTabs[pin.id].map { releasePinnedTab($0) }
        }
        for document in contents.documents {
            placeInToday(.document(document))
        }
        pinStore.change(in: activeProfileID) { _ = $0.removeFolder(id) }
    }

    /// File › Import Bookmarks…: another browser's bookmark file, chosen in
    /// an open panel, becomes a folder in Pinned.
    func importBookmarks() {
        guard let window = activeTab?.webView?.window ?? NSApp.keyWindow else { return }
        let panel = NSOpenPanel()
        panel.message = "Choose Safari's Bookmarks.plist or Chrome's Bookmarks file."
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Safari")
        Task {
            guard await panel.beginSheetModal(for: window) == .OK, let url = panel.url else { return }
            guard let data = try? Data(contentsOf: url), let bookmarks = try? BookmarkImport.bookmarks(from: data) else {
                toasts.show("Couldn't Read Bookmarks", symbol: ChromeSymbols.Navigation.loadFailed)
                return
            }
            let folder = SidebarFolder(
                name: "Imported from \(BookmarkImport.source(of: data).rawValue)",
                contents: SidebarTree(bookmarks.map(SidebarItem.init))
            )
            pinStore.change(in: activeProfileID) { $0.addFolder(folder) }
            toasts.show("Imported \(folder.contents.tabs.count) Bookmarks", symbol: ChromeSymbols.Tabs.folder)
        }
    }

    // MARK: Live tabs for the store's pins

    /// Matches the live tabs to the profile's pins: a tab for each new pin,
    /// built asleep where it was left, and the tabs of pins that are gone
    /// closed, unless they're back in Today, as after an unpin here.
    private func reconcilePinnedTabs(with layout: PinLayout) {
        let pins = layout[activeProfileID]
        pinned = pins.pinned.map(liveTab)

        for (id, tab) in pinnedTabs where layout.pin(id) == nil {
            pinnedTabs[id] = nil
            pinnedTabRecorders[id] = nil
            guard !tabs.contains(where: { $0.id == id }) else { continue }
            tab.close()
            if id == activeTabID {
                if let next = tabsInDisplayOrder.first {
                    selectTab(next.id)
                } else {
                    addTab()
                }
            }
        }
    }

    /// A pin's tab browses with its profile's profile; one left on another
    /// profile's data store, as after the profile changed profile, is rebuilt.
    private func liveTab(for pin: Pin) -> TabSession {
        liveTab(for: pin, in: activeProfile)
    }

    private func liveTab(for pin: Pin, in profile: Profile?) -> TabSession {
        let services = services(for: profile)
        let existing = pinnedTabs[pin.id]
        if let tab = existing, tab.services.context === services.context {
            if tab.pinnedURL != pin.url { tab.pinnedURL = pin.url }
            return tab
        }
        let saved = existing.map(retireFromProfile)
            ?? pinStore.savedTab(for: pin.id)
            ?? SavedTab(url: pin.url, title: pin.title, customTitle: nil, interactionState: nil, lastUsedAt: nil)
        let tab = makeTab(id: pin.id, restoring: saved, services: services)
        tab.pinnedURL = pin.url
        adoptPinnedTab(tab)
        return tab
    }

    /// Takes a live tab in as a pin's, and keeps the store told where it is
    /// and what the pinned page is called. `@Published` announces a change
    /// before making it, so the record waits a turn of the main queue.
    private func adoptPinnedTab(_ tab: TabSession) {
        pinnedTabs[tab.id] = tab
        pinnedTabRecorders[tab.id] = tab.savedTabChanges
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak tab] in
                guard let self, let tab else { return }
                pinStore.record(tab.savedTab, for: tab.id)
                if !tab.isAwayFromPin, !tab.pageTitle.isEmpty {
                    pinStore.change { $0.update(tab.id) { $0.title = tab.pageTitle } }
                }
            }
    }

    /// Hands a pin's live tab back to Today.
    private func releasePinnedTab(_ tab: TabSession, onto target: UUID? = nil) {
        tab.pinnedURL = nil
        placeInToday(.tab(tab), onto: target)
    }

    /// Puts something unpinned in Today: at the top, or where it was dropped,
    /// on the side of the target it came from.
    func placeInToday(_ item: TodayItem<TabSession>, onto target: UUID? = nil) {
        if let target, let index = today.firstIndex(where: { $0.id == target }) {
            today.insert(item, at: tabLayout == .sidebar ? index : index + 1)
        } else {
            today.append(item)
        }
    }

    // MARK: - Profiles

    /// The window's state in a profile it isn't showing.
    private struct ParkedProfile {
        var today: [TodayItem<TabSession>]
        var activeTabID: UUID?
        var activeDocumentID: UUID?
        var splits: [TabSplit<UUID>]
    }

    /// The profile on screen, as it would be parked.
    private var shownProfile: ParkedProfile {
        ParkedProfile(today: today, activeTabID: activeTabID, activeDocumentID: activeDocumentID, splits: splits)
    }

    /// The profiles to switch between, in order; none in a private window.
    var profiles: [Profile] {
        profileStore == nil ? [] : knownProfiles.profiles
    }

    var activeProfile: Profile? {
        profileStore == nil ? nil : knownProfiles.profile(activeProfileID)
    }

    /// Today tabs this window has open in its other profiles, in profile order.
    var tabsInOtherProfiles: [TabSession] {
        knownProfiles.profiles.flatMap { parkedProfiles[$0.id]?.today.compactMap(\.tab) ?? [] }
    }

    var activeSidebarPage: ProfileSidebarPage {
        ProfileSidebarPage(id: activeProfileID, pinned: pinned,
                         today: today, splits: splits, selection: activeDocumentID ?? activeTabID)
    }

    /// Prepare a neighboring sidebar without selecting it or waking its pages.
    /// Called once when a gesture starts, never from a view's render pass.
    func sidebarPage(for profile: Profile) -> ProfileSidebarPage {
        if profile.id == activeProfileID { return activeSidebarPage }
        let pins = pinStore.layout[profile.id]
        let parked = parkedProfiles[profile.id]
        return ProfileSidebarPage(
            id: profile.id,
            pinned: pins.pinned.map { liveTab(for: $0, in: profile) },
            today: parked?.today ?? [], splits: parked?.splits ?? [],
            selection: parked?.activeDocumentID ?? parked?.activeTabID
        )
    }

    /// Footer icons, the Profiles menu (⌃1–9) and the Command Bar: shows another
    /// profile, with its Today and selected tab as this window left them.
    func switchToProfile(_ id: UUID) {
        guard profileStore != nil, knownProfiles.profile(id) != nil else { return }
        page(to: id)
    }

    /// ⌘⌥← and →, and swiping the sidebar: the profile beside this one.
    func switchToAdjacentProfile(_ offset: Int) {
        guard let profile = adjacentProfile(offset) else { return }
        page(to: profile.id)
    }

    func adjacentProfile(_ offset: Int) -> Profile? {
        profileStore == nil ? nil : knownProfiles.profile(offset, from: activeProfileID)
    }

    /// New Profile: another profile in this one's profile, shown at once, with
    /// the editor open to name it.
    func newProfile() {
        guard let profileStore else { return }
        var profile: Profile?
        profileStore.change { profile = $0.addProfile() }
        guard let profile else { return }
        page(to: profile.id)
        profileToEdit = profile.id
    }

    func moveProfile(_ id: UUID, by offset: Int) {
        profileStore?.change { $0.moveProfile(id, by: offset) }
    }

    /// Deletes a profile in every window: its Today tabs go to the archive and
    /// its Pinned with it. This window moves to the profile before it.
    func deleteProfile(_ id: UUID) {
        guard let profileStore, profiles.count > 1 else { return }
        if id == activeProfileID, let neighbor = adjacentProfile(-1) ?? adjacentProfile(1) {
            show(neighbor.id)
        }
        profileStore.deleteProfile(id)
    }

    /// What a profile's tabs browse with: its profile's context. A private
    /// window's tabs browse with its own.
    private func services(for profile: Profile?) -> TabSessionServices {
        guard let profileStore, let profile else { return baseServices }
        return baseServices.with(profileStore.context(for: profile))
    }

    /// Change selection synchronously. Each visual surface owns its motion;
    /// delayed model changes can replay an older click after a rapid reversal.
    private func page(to id: UUID) {
        guard knownProfiles.profile(id) != nil else { return }
        show(id)
    }

    private func show(_ id: UUID) {
        if profileTransition.state.isActive && !profileTransition.isCommitting { profileTransition.reset() }
        guard id != activeProfileID else { return }
        activeTab?.markUsed()
        parkedProfiles[activeProfileID] = shownProfile
        let next = parkedProfiles.removeValue(forKey: id)
        commandBar.dismiss()
        library.dismiss()
        activeProfileID = id
        trackDocuments()
        reconcilePinnedTabs(with: pinStore.layout)
        unpark(next)
        if let documents = documentStore?.documents { reconcileDocuments(with: documents) }
    }

    /// Puts a profile's Today on screen with what it had selected.
    private func unpark(_ profile: ParkedProfile?) {
        // The splits first: setting Today drops those whose tabs were
        // archived while the profile was parked.
        splits = profile?.splits ?? []
        today = profile?.today ?? []
        select(profile?.activeTabID)
        if let document = profile?.activeDocumentID, section(of: document) != nil {
            showDocument(document)
        }
    }

    /// Deleted profiles close their pages without moving their data elsewhere.
    private func reconcileProfiles(with profiles: Profiles) {
        knownProfiles = profiles
        if profiles.profile(activeProfileID) == nil { show(profiles.profiles[0].id) }
        for id in parkedProfiles.keys where profiles.profile(id) == nil {
            parkedProfiles.removeValue(forKey: id)?.today.compactMap(\.tab).forEach { $0.close() }
        }
        reconcilePinnedTabs(with: pinStore.layout)
    }

    private func trackDocuments() {
        documentChanges = documentStore?.$documents.dropFirst().sink { [weak self] documents in
            self?.reconcileDocuments(with: documents)
        }
    }

    private func rehomed(_ tab: TabSession, in profile: Profile?) -> TabSession? {
        let target = services(for: profile)
        guard tab.services.context !== target.context else { return nil }
        return makeTab(id: tab.id, restoring: retireFromProfile(tab), services: target)
    }

    /// Lets go of a tab's page on its old profile's data store, and returns
    /// where it was, to rebuild it from.
    private func retireFromProfile(_ tab: TabSession) -> SavedTab {
        let saved = tab.savedTab
        tab.close()
        tab.sleep()
        return saved
    }

    /// Loads a page in the active tab, bringing it back from under a note.
    func navigateActiveTab(to input: String) {
        guard let activeTab else { return }
        selectTab(activeTab.id)
        activeTab.navigate(input)
    }

    /// Navigation acts on the page on screen, not one a note covers.
    private var browsedTab: TabSession? {
        activeDocumentID == nil ? activeTab : nil
    }

    func goBack() {
        browsedTab?.goBack()
    }

    func goForward() {
        browsedTab?.goForward()
    }

    func reloadOrStop() {
        guard let tab = browsedTab else { return }
        tab.isLoading ? tab.stopLoading() : tab.reload()
    }

}

private extension TabIdlePolicy.Tab {
    @MainActor
    init(_ tab: TabSession, isActive: Bool) {
        self.init(
            isActive: isActive,
            isAsleep: tab.isAsleep,
            hasPage: !tab.currentURL.isEmpty,
            isInUse: tab.isInUse,
            lastUsedAt: tab.lastUsedAt
        )
    }
}
