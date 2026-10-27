import Foundation
import WebKit

/// Extensions in a window: the ones its space's profile runs, their buttons,
/// and the tabs they open. `ExtensionWindow` reports the window's tabs.
extension TabManager {
    /// What runs the window's extensions: its space's profile's host, which
    /// a private window shares with the profile it was opened over.
    var extensionHost: ExtensionHost {
        (activeTab?.services ?? services).context.extensions
    }

    /// The extensions with a button here, in the order they were added. A
    /// private window shows only those allowed in private windows.
    var extensionContexts: [WKWebExtensionContext] {
        extensionHost.contexts.filter { !isPrivate || $0.hasAccessToPrivateData }
    }

    /// An extension's button, from the toolbar, its menu or the Command Bar.
    func performExtensionAction(_ context: WKWebExtensionContext) {
        extensionHost.performAction(of: context, in: extensionWindow)
    }

    /// An extension's options page, in a tab of its own.
    func openOptions(of context: WKWebExtensionContext) {
        guard let url = context.optionsPageURL else { return }
        addTab(url: url.absoluteString)
    }

    /// A tab an extension asked for: a page, or the start page, beside its
    /// parent or at the top of Today, selected only if asked to be.
    func openTab(url: URL?, nextTo parentID: UUID?, selected: Bool) -> TabSession? {
        let previous = activeTabID
        if let url {
            addTab(request: URLRequest(url: url), nextTo: parentID)
        } else {
            addTab()
        }
        let tab = activeTab
        if !selected, let previous {
            selectTab(previous)
        }
        return tab
    }
}
