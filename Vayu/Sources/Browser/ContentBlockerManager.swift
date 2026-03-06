import Foundation
import WebKit

@MainActor
final class ContentBlockerManager {
    static let shared = ContentBlockerManager()

    private static let identifier = "com.vayu.easylist"
    private var ruleList: WKContentRuleList?
    private var pending: [WKUserContentController] = []

    var isLoaded: Bool { ruleList != nil }

    func load() async {
        let store = WKContentRuleListStore.default()!

        // Try cached first
        if let cached = try? await store.contentRuleList(forIdentifier: Self.identifier) {
            ruleList = cached
            flushPending()
            return
        }

        // Compile from bundled JSON
        guard let url = Bundle.main.url(forResource: "easylist", withExtension: "json"),
              let json = try? String(contentsOf: url, encoding: .utf8) else {
            return
        }

        do {
            let compiled = try await store.compileContentRuleList(
                forIdentifier: Self.identifier,
                encodedContentRuleList: json
            )
            ruleList = compiled
            flushPending()
        } catch {}
    }

    func attach(to controller: WKUserContentController) {
        if let ruleList {
            controller.add(ruleList)
        } else {
            pending.append(controller)
        }
    }

    private func flushPending() {
        guard let ruleList else { return }
        for controller in pending {
            controller.add(ruleList)
        }
        pending.removeAll()
    }

    func detach(from controller: WKUserContentController) {
        guard let ruleList else { return }
        controller.remove(ruleList)
    }
}
