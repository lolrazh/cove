import Foundation
import WebKit

@MainActor
final class ContentBlockerManager {
    static let shared = ContentBlockerManager()

    private static let identifier = "com.vayu.easylist"
    private var ruleList: WKContentRuleList?

    var isLoaded: Bool { ruleList != nil }

    /// Compile or load cached content blocking rules.
    /// Call once at app launch; await before creating WebViews for best results.
    func load() async {
        let store = WKContentRuleListStore.default()!

        // Try cached first
        if let cached = try? await store.contentRuleList(forIdentifier: Self.identifier) {
            ruleList = cached
            print("[ContentBlocker] Loaded cached rules")
            return
        }

        // Compile from bundled JSON
        guard let url = Bundle.main.url(forResource: "easylist", withExtension: "json"),
              let json = try? String(contentsOf: url, encoding: .utf8) else {
            print("[ContentBlocker] Failed to read bundled easylist.json")
            return
        }

        do {
            let compiled = try await store.compileContentRuleList(
                forIdentifier: Self.identifier,
                encodedContentRuleList: json
            )
            ruleList = compiled
            print("[ContentBlocker] Compiled and cached rules")
        } catch {
            print("[ContentBlocker] Compilation failed: \(error)")
        }
    }

    /// Attach compiled rules to a WKUserContentController.
    func attach(to controller: WKUserContentController) {
        guard let ruleList else { return }
        controller.add(ruleList)
    }

    /// Remove rules from a WKUserContentController.
    func detach(from controller: WKUserContentController) {
        guard let ruleList else { return }
        controller.remove(ruleList)
    }
}
