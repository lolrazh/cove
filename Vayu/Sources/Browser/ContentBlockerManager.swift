import Foundation
import WebKit
import os.log

private let log = Logger(subsystem: "com.vayu.browser", category: "ContentBlocker")

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
            log.info("Loaded cached rules")
            return
        }

        // Compile from bundled JSON
        guard let url = Bundle.main.url(forResource: "easylist", withExtension: "json") else {
            log.error("easylist.json not found in bundle")
            return
        }

        guard let json = try? String(contentsOf: url, encoding: .utf8) else {
            log.error("Failed to read easylist.json")
            return
        }

        log.info("Compiling \(json.count) chars of rules...")

        do {
            let compiled = try await store.compileContentRuleList(
                forIdentifier: Self.identifier,
                encodedContentRuleList: json
            )
            ruleList = compiled
            flushPending()
            log.info("Compiled and cached rules successfully")
        } catch {
            log.error("Compilation failed: \(error.localizedDescription)")
        }
    }

    func attach(to controller: WKUserContentController) {
        if let ruleList {
            controller.add(ruleList)
            log.debug("Attached rules to controller")
        } else {
            pending.append(controller)
            log.debug("Queued controller (rules not ready, \(self.pending.count) pending)")
        }
    }

    private func flushPending() {
        guard let ruleList else { return }
        let count = pending.count
        for controller in pending {
            controller.add(ruleList)
        }
        pending.removeAll()
        if count > 0 {
            log.info("Flushed rules to \(count) pending controller(s)")
        }
    }

    func detach(from controller: WKUserContentController) {
        guard let ruleList else { return }
        controller.remove(ruleList)
    }
}
