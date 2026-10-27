import AppKit
import Combine
import WebKit

/// A tab as extensions see it: a stand-in for a `TabSession`, made by its
/// `ExtensionWindow`, answering for the tab and acting through it. A
/// sleeping tab has no web view to offer, so extensions can't reach into it
/// until it wakes.
@MainActor
final class ExtensionTab: NSObject {
    let session: TabSession
    private(set) weak var window: ExtensionWindow?
    private var changes: AnyCancellable?

    init(session: TabSession, window: ExtensionWindow) {
        self.session = session
        self.window = window
        super.init()
        changes = Publishers.MergeMany([
            Self.change(of: session.$currentURL, .URL),
            Self.change(of: session.$pageTitle, .title),
            Self.change(of: session.$isLoading, .loading),
            Self.change(of: session.$isMuted, .muted),
            Self.change(of: session.$isPlayingAudio, .playingAudio),
            Self.change(of: session.$pinnedURL, .pinned),
        ])
        // `@Published` announces changes before making them.
        .receive(on: DispatchQueue.main)
        .sink { [weak self] properties in
            guard let self else { return }
            window.host?.controller.didChangeTabProperties(properties, for: self)
        }
    }

    private static func change<Value: Equatable>(
        of property: Published<Value>.Publisher,
        _ changed: WKWebExtension.TabChangedProperties
    ) -> AnyPublisher<WKWebExtension.TabChangedProperties, Never> {
        property.removeDuplicates().dropFirst().map { _ in changed }.eraseToAnyPublisher()
    }

    private var tabManager: TabManager? {
        window?.tabManager
    }
}

// MARK: - WKWebExtensionTab

extension ExtensionTab: WKWebExtensionTab {
    func window(for context: WKWebExtensionContext) -> (any WKWebExtensionWindow)? {
        window
    }

    func webView(for context: WKWebExtensionContext) -> WKWebView? {
        session.webView
    }

    func title(for context: WKWebExtensionContext) -> String? {
        session.title
    }

    func url(for context: WKWebExtensionContext) -> URL? {
        URL(string: session.currentURL)
    }

    func isLoadingComplete(for context: WKWebExtensionContext) -> Bool {
        !session.isLoading
    }

    func isPinned(for context: WKWebExtensionContext) -> Bool {
        session.pinnedURL != nil
    }

    func setPinned(_ pinned: Bool, for context: WKWebExtensionContext) async throws {
        guard pinned != isPinned(for: context), let tabManager, !tabManager.isPrivate else { return }
        tabManager.togglePinned(session.id)
    }

    func isPlayingAudio(for context: WKWebExtensionContext) -> Bool {
        session.isPlayingAudio
    }

    func isMuted(for context: WKWebExtensionContext) -> Bool {
        session.isMuted
    }

    func setMuted(_ muted: Bool, for context: WKWebExtensionContext) async throws {
        if muted != session.isMuted { session.toggleMuted() }
    }

    func isSelected(for context: WKWebExtensionContext) -> Bool {
        tabManager?.activeTabID == session.id
    }

    func activate(for context: WKWebExtensionContext) async throws {
        tabManager?.selectTab(session.id)
    }

    func loadURL(_ url: URL, for context: WKWebExtensionContext) async throws {
        session.navigate(url.absoluteString)
    }

    func reload(fromOrigin: Bool, for context: WKWebExtensionContext) async throws {
        session.reload()
    }

    func goBack(for context: WKWebExtensionContext) async throws {
        session.goBack()
    }

    func goForward(for context: WKWebExtensionContext) async throws {
        session.goForward()
    }

    func duplicate(using configuration: WKWebExtension.TabConfiguration, for context: WKWebExtensionContext) async throws -> (any WKWebExtensionTab)? {
        guard let tabManager, let window else { return nil }
        tabManager.duplicateTab(session.id)
        return tabManager.activeTab.map { window.extensionTab(for: $0) }
    }

    func close(for context: WKWebExtensionContext) async throws {
        tabManager?.closeTab(session.id)
    }

    /// A click on an extension's button lets it act on the tab it was
    /// clicked for, as `activeTab` promises.
    func shouldGrantPermissionsOnUserGesture(for context: WKWebExtensionContext) -> Bool {
        true
    }
}
