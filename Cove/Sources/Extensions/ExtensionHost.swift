import AppKit
import Combine
import WebKit
import os

/// Runs the library's enabled extensions for one profile: a
/// `WKWebExtensionController` keeping that profile's extension storage,
/// attached to every web view its tabs make. A private window over the
/// profile shares it; there only extensions allowed in private windows see
/// its tabs, which WebKit enforces once the window says it's private.
@MainActor
final class ExtensionHost: NSObject, ObservableObject {
    let controller: WKWebExtensionController
    let library: ExtensionLibrary
    /// The running extensions, in the order they were added.
    @Published private(set) var contexts: [WKWebExtensionContext] = []

    /// The browser windows showing this profile, most recently focused first.
    private var windows: [ExtensionWindow] = []
    /// Set while the library's grants are being handed to a context, whose
    /// change notifications then aren't news.
    private var isApplyingGrants = false
    private var cancellables: Set<AnyCancellable> = []
    private static let logger = Logger(subsystem: "com.cove.browser", category: "Extensions")

    /// `storageID` keeps a profile's extension data apart; nil is the
    /// default profile's, in WebKit's default place.
    init(storageID: UUID?, dataStore: WKWebsiteDataStore, library: ExtensionLibrary) {
        let configuration = storageID.map(WKWebExtensionController.Configuration.init(identifier:)) ?? .default()
        configuration.defaultWebsiteDataStore = dataStore
        controller = WKWebExtensionController(configuration: configuration)
        self.library = library
        super.init()
        controller.delegate = self

        library.$installed.combineLatest(library.$extensions)
            .sink { [weak self] installed, extensions in self?.reconcile(installed, extensions) }
            .store(in: &cancellables)
        Publishers.MergeMany(Self.grantNotifications.map { NotificationCenter.default.publisher(for: $0) })
            .compactMap { $0.object as? WKWebExtensionContext }
            .sink { [weak self] context in self?.recordGrants(of: context) }
            .store(in: &cancellables)
    }

    /// The extension a page belongs to, for a page at one of its addresses.
    func extensionContext(for url: URL) -> WKWebExtensionContext? {
        controller.extensionContext(for: url)
    }

    func extensionContext(id: String) -> WKWebExtensionContext? {
        contexts.first { $0.uniqueIdentifier == id }
    }

    // MARK: - Running the library's extensions

    /// Starts the enabled extensions that aren't running, stops the ones
    /// turned off or removed, and hands every running one what the user
    /// allowed. A removed extension's storage goes with it.
    private func reconcile(_ installed: [InstalledExtension], _ extensions: [UUID: WKWebExtension]) {
        let running = installed.filter(\.isEnabled).compactMap { record in
            extensions[record.id].map { (record, $0) }
        }
        let runningIDs = Set(running.map(\.0.id.uuidString))
        for context in contexts where !runningIDs.contains(context.uniqueIdentifier) {
            try? controller.unload(context)
        }
        contexts = running.compactMap { record, webExtension in
            guard let context = extensionContext(id: record.id.uuidString) ?? start(webExtension, as: record) else { return nil }
            apply(record, to: context)
            return context
        }
        removeOrphanedData(keeping: Set(installed.map(\.id.uuidString)))
    }

    private func start(_ webExtension: WKWebExtension, as record: InstalledExtension) -> WKWebExtensionContext? {
        let context = WKWebExtensionContext(for: webExtension)
        // Fixed, so the extension finds its storage again on every launch.
        context.uniqueIdentifier = record.id.uuidString
        context.baseURL = URL(string: "webkit-extension://\(record.id.uuidString.lowercased())/")!
        context.isInspectable = true
        context.inspectionName = record.name
        apply(record, to: context)
        do {
            try controller.load(context)
            return context
        } catch {
            Self.logger.error("Couldn't start \(record.name, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func apply(_ record: InstalledExtension, to context: WKWebExtensionContext) {
        isApplyingGrants = true
        defer { isApplyingGrants = false }
        if ExtensionGrants(permissions: context.grantedPermissions, sites: context.grantedPermissionMatchPatterns) != record.granted {
            context.grantedPermissions = record.granted.webKitPermissions
            context.grantedPermissionMatchPatterns = record.granted.webKitSites
        }
        if ExtensionGrants(permissions: context.deniedPermissions, sites: context.deniedPermissionMatchPatterns) != record.denied {
            context.deniedPermissions = record.denied.webKitPermissions
            context.deniedPermissionMatchPatterns = record.denied.webKitSites
        }
        if context.hasAccessToPrivateData != record.allowsPrivateBrowsing {
            context.hasAccessToPrivateData = record.allowsPrivateBrowsing
        }
    }

    /// An extension's permissions changed here, by a prompt or its own
    /// `permissions` calls: the library keeps them for every profile.
    private func recordGrants(of context: WKWebExtensionContext) {
        guard !isApplyingGrants, contexts.contains(context), let id = UUID(uuidString: context.uniqueIdentifier) else { return }
        library.update(id) { record in
            record.granted = ExtensionGrants(permissions: context.grantedPermissions, sites: context.grantedPermissionMatchPatterns)
            record.denied = ExtensionGrants(permissions: context.deniedPermissions, sites: context.deniedPermissionMatchPatterns)
        }
    }

    private static let grantNotifications: [Notification.Name] = [
        WKWebExtensionContext.permissionsWereGrantedNotification,
        WKWebExtensionContext.permissionsWereDeniedNotification,
        WKWebExtensionContext.grantedPermissionsWereRemovedNotification,
        WKWebExtensionContext.deniedPermissionsWereRemovedNotification,
        WKWebExtensionContext.permissionMatchPatternsWereGrantedNotification,
        WKWebExtensionContext.permissionMatchPatternsWereDeniedNotification,
        WKWebExtensionContext.grantedPermissionMatchPatternsWereRemovedNotification,
        WKWebExtensionContext.deniedPermissionMatchPatternsWereRemovedNotification,
    ]

    /// Forgets what removed extensions stored, including ones removed while
    /// this profile wasn't open.
    private func removeOrphanedData(keeping kept: Set<String>) {
        let types = WKWebExtensionController.allExtensionDataTypes
        controller.fetchDataRecords(ofTypes: types) { [controller] records in
            let orphans = records.filter { !kept.contains($0.uniqueIdentifier) }
            guard !orphans.isEmpty else { return }
            controller.removeData(ofTypes: types, from: orphans) {}
        }
    }

    // MARK: - Windows

    /// A browser window now shows this profile.
    func add(_ window: ExtensionWindow) {
        guard !windows.contains(window) else { return }
        windows.append(window)
        controller.didOpenWindow(window)
    }

    /// A browser window closed, or moved to another profile's space.
    func remove(_ window: ExtensionWindow) {
        guard windows.contains(window) else { return }
        windows.removeAll { $0 === window }
        controller.didCloseWindow(window)
    }

    func didFocus(_ window: ExtensionWindow) {
        guard windows.first !== window, windows.contains(window) else { return }
        windows.removeAll { $0 === window }
        windows.insert(window, at: 0)
        controller.didFocusWindow(window)
    }

    private var focusedWindow: ExtensionWindow? {
        windows.first { $0.window?.isKeyWindow == true } ?? windows.first
    }

    // MARK: - Actions

    /// What clicking an extension's button does in a window: its popup, or
    /// its `action.onClicked`, for the window's active tab.
    func performAction(of context: WKWebExtensionContext, in window: ExtensionWindow) {
        context.performAction(for: window.activeTab)
    }
}

// MARK: - WKWebExtensionControllerDelegate

extension ExtensionHost: WKWebExtensionControllerDelegate {
    func webExtensionController(_ controller: WKWebExtensionController, openWindowsFor extensionContext: WKWebExtensionContext) -> [any WKWebExtensionWindow] {
        guard let focusedWindow else { return windows }
        return [focusedWindow] + windows.filter { $0 !== focusedWindow }
    }

    func webExtensionController(_ controller: WKWebExtensionController, focusedWindowFor extensionContext: WKWebExtensionContext) -> (any WKWebExtensionWindow)? {
        focusedWindow
    }

    func webExtensionController(
        _ controller: WKWebExtensionController,
        openNewTabUsing configuration: WKWebExtension.TabConfiguration,
        for extensionContext: WKWebExtensionContext
    ) async throws -> (any WKWebExtensionTab)? {
        guard let window = configuration.window as? ExtensionWindow ?? focusedWindow else { return nil }
        return window.openTab(
            url: configuration.url,
            nextTo: configuration.parentTab as? ExtensionTab,
            selected: configuration.shouldBeActive
        )
    }

    func webExtensionController(
        _ controller: WKWebExtensionController,
        openNewWindowUsing configuration: WKWebExtension.WindowConfiguration,
        for extensionContext: WKWebExtensionContext
    ) async throws -> (any WKWebExtensionWindow)? {
        guard let window = await library.openWindow(isPrivate: configuration.shouldBePrivate) else { return nil }
        window.open(configuration.tabURLs)
        return window
    }

    func webExtensionController(
        _ controller: WKWebExtensionController,
        promptForPermissions permissions: Set<WKWebExtension.Permission>,
        in tab: (any WKWebExtensionTab)?,
        for extensionContext: WKWebExtensionContext
    ) async -> (Set<WKWebExtension.Permission>, Date?) {
        let request = ExtensionPermissionRequest(extensionContext.webExtension, permissions: permissions.map(\.rawValue))
        return await ask(request, in: tab) ? (permissions, nil) : ([], nil)
    }

    func webExtensionController(
        _ controller: WKWebExtensionController,
        promptForPermissionToAccess urls: Set<URL>,
        in tab: (any WKWebExtensionTab)?,
        for extensionContext: WKWebExtensionContext
    ) async -> (Set<URL>, Date?) {
        let request = ExtensionPermissionRequest(extensionContext.webExtension, sites: urls.compactMap { $0.host() })
        return await ask(request, in: tab) ? (urls, nil) : ([], nil)
    }

    func webExtensionController(
        _ controller: WKWebExtensionController,
        promptForPermissionMatchPatterns matchPatterns: Set<WKWebExtension.MatchPattern>,
        in tab: (any WKWebExtensionTab)?,
        for extensionContext: WKWebExtensionContext
    ) async -> (Set<WKWebExtension.MatchPattern>, Date?) {
        let request = ExtensionPermissionRequest(extensionContext.webExtension, sites: matchPatterns.map(\.string))
        return await ask(request, in: tab) ? (matchPatterns, nil) : ([], nil)
    }

    /// Asks in the tab's window, or the focused one; with no window to ask
    /// in, the answer is no.
    private func ask(_ request: ExtensionPermissionRequest, in tab: (any WKWebExtensionTab)?) async -> Bool {
        guard let window = (tab as? ExtensionTab)?.window?.window ?? focusedWindow?.window else { return false }
        return await ExtensionPermissionPrompt.ask(request, in: window)
    }

    /// An extension changed its button's icon, title or badge.
    func webExtensionController(_ controller: WKWebExtensionController, didUpdate action: WKWebExtension.Action, forExtensionContext context: WKWebExtensionContext) {
        objectWillChange.send()
    }

    func webExtensionController(
        _ controller: WKWebExtensionController,
        presentActionPopup action: WKWebExtension.Action,
        for context: WKWebExtensionContext
    ) async throws {
        guard let popover = action.popupPopover,
              let window = (action.associatedTab as? ExtensionTab)?.window ?? focusedWindow else { return }
        window.present(popover, for: context)
    }
}

