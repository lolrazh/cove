import Foundation
import WebKit
import Combine

@MainActor
final class ContentBlockerManager {
    static let shared = ContentBlockerManager(settings: .shared)

    private static let identifier = "com.cove.easylist"

    private let settings: BrowserSettingsStore
    private var ruleList: WKContentRuleList?
    private var trackedControllers = NSHashTable<WKUserContentController>.weakObjects()
    private var pendingControllers = NSHashTable<WKUserContentController>.weakObjects()
    private var cancellables: Set<AnyCancellable> = []

    var isLoaded: Bool { ruleList != nil }

    init(settings: BrowserSettingsStore) {
        self.settings = settings
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

    func attach(to controller: WKUserContentController) {
        trackedControllers.add(controller)

        guard settings.contentBlockingEnabled else { return }

        if let ruleList {
            attach(ruleList, to: controller)
        } else {
            pendingControllers.add(controller)
        }
    }

    func detach(from controller: WKUserContentController) {
        trackedControllers.add(controller)
        guard let ruleList else { return }
        controller.remove(ruleList)
    }

    private func attachRuleListToTrackedControllers(_ ruleList: WKContentRuleList) {
        guard settings.contentBlockingEnabled else { return }

        for controller in trackedControllers.allObjects {
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
