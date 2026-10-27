import Foundation
import WebKit
import Combine

/// Blocks ads and trackers with EasyList, in every web view, except on sites
/// the user turned it off for in site controls.
///
/// A rule list can't be told to skip a site after it's compiled, and an
/// `ignore-previous-rules` exception only reaches rules in its own list, so
/// recompiling EasyList would be the only way to write exceptions into rules.
/// Each web view has its own content controller instead, so a page on an
/// excepted site simply goes without the list.
@MainActor
final class ContentBlockerManager {
    private static let identifier = "com.cove.easylist"
    private static let exceptionsKey = "browser.contentBlockingExceptions"

    private let settings: BrowserSettingsStore
    private let defaults: UserDefaults
    private var ruleList: WKContentRuleList?
    private var trackedControllers = NSHashTable<WKUserContentController>.weakObjects()
    private var pendingControllers = NSHashTable<WKUserContentController>.weakObjects()
    /// Controllers whose page is on a site with blocking turned off.
    private var exemptControllers = NSHashTable<WKUserContentController>.weakObjects()
    /// Sites with blocking turned off, by domain.
    private var exceptions: Set<String>
    private var cancellables: Set<AnyCancellable> = []

    var isLoaded: Bool { ruleList != nil }

    /// Whether blocking is on in Settings, for every site.
    var isEnabled: Bool { settings.contentBlockingEnabled }

    init(settings: BrowserSettingsStore, defaults: UserDefaults = .standard) {
        self.settings = settings
        self.defaults = defaults
        self.exceptions = Set(defaults.stringArray(forKey: Self.exceptionsKey) ?? [])
        settings.$contentBlockingEnabled
            .removeDuplicates()
            .sink { [weak self] isEnabled in
                guard let self else { return }
                if isEnabled {
                    Task { await self.load() }
                } else {
                    self.detachFromTrackedControllers()
                }
            }
            .store(in: &cancellables)
    }

    func load() async {
        guard settings.contentBlockingEnabled else { return }

        if let ruleList {
            attachRuleListToTrackedControllers(ruleList)
            return
        }

        let store = WKContentRuleListStore.default()!

        if let cached = try? await store.contentRuleList(forIdentifier: Self.identifier) {
            ruleList = cached
            attachRuleListToTrackedControllers(cached)
            return
        }

        guard let url = Bundle.main.url(forResource: "easylist", withExtension: "json"),
              let json = try? String(contentsOf: url, encoding: .utf8) else {
            return
        }

        if let compiled = try? await store.compileContentRuleList(
            forIdentifier: Self.identifier,
            encodedContentRuleList: json
        ) {
            ruleList = compiled
            attachRuleListToTrackedControllers(compiled)
        }
    }

    // MARK: - Sites

    /// Whether blocking applies on the page's site, as far as site controls
    /// go; Settings can still turn it off everywhere.
    func blocks(on url: URL?) -> Bool {
        guard let host = url?.host() else { return true }
        return !exceptions.contains { Site(domain: $0).contains(host) }
    }

    /// Turns blocking on or off for the page's site. Turning it on also lifts
    /// an exception made for a parent site, which covered this one.
    func setBlocks(_ blocks: Bool, on url: URL?) {
        guard let site = Site(url) else { return }
        if blocks {
            exceptions = exceptions.filter { !Site(domain: $0).contains(site.domain) }
        } else {
            exceptions.insert(site.domain)
        }
        defaults.set(exceptions.sorted(), forKey: Self.exceptionsKey)
    }

    /// Gives the controller's web view the list or takes it away, for the site
    /// it's about to load. Called as each main-frame navigation is decided, so
    /// the page loads with the change.
    func update(_ controller: WKUserContentController, for url: URL?) {
        let isExempt = !blocks(on: url)
        guard isExempt != exemptControllers.contains(controller) else { return }

        if isExempt {
            exemptControllers.add(controller)
            pendingControllers.remove(controller)
            ruleList.map(controller.remove)
        } else {
            exemptControllers.remove(controller)
            attach(to: controller)
        }
    }

    // MARK: - Controllers

    func attach(to controller: WKUserContentController) {
        trackedControllers.add(controller)

        guard settings.contentBlockingEnabled, !exemptControllers.contains(controller) else { return }

        if let ruleList {
            attach(ruleList, to: controller)
        } else {
            pendingControllers.add(controller)
        }
    }

    func detach(from controller: WKUserContentController) {
        trackedControllers.remove(controller)
        guard let ruleList else { return }
        controller.remove(ruleList)
    }

    private func attachRuleListToTrackedControllers(_ ruleList: WKContentRuleList) {
        guard settings.contentBlockingEnabled else { return }

        for controller in trackedControllers.allObjects where !exemptControllers.contains(controller) {
            attach(ruleList, to: controller)
        }

        for controller in pendingControllers.allObjects {
            attach(ruleList, to: controller)
        }
        pendingControllers.removeAllObjects()
    }

    private func attach(_ ruleList: WKContentRuleList, to controller: WKUserContentController) {
        controller.remove(ruleList)
        controller.add(ruleList)
    }

    private func detachFromTrackedControllers() {
        pendingControllers.removeAllObjects()
        guard let ruleList else { return }

        for controller in trackedControllers.allObjects {
            controller.remove(ruleList)
        }
    }
}
