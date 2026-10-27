import WebKit

/// Zap mode: the element under the pointer is outlined, and clicking it hides
/// it for good, by adding a selector for it to the Boost. Escape, or leaving
/// the page, ends it.
///
/// The picker runs in the Boosts' content world. The selector it reports is
/// meant to find the same element after a reload: a stable id, a test id, or
/// the shortest path of tags and classes that finds it alone, made unique
/// with `:nth-of-type` only where needed. Classes and ids with long runs of
/// digits look generated and are skipped.
@MainActor
enum BoostZap {
    /// Returns a selector that finds the element alone in its document.
    static let selectorFunction = """
    (element) => {
        const stable = (name) => /^[A-Za-z_-][\\w-]*$/.test(name) && !/\\d{3,}/.test(name);
        const unique = (selector) => {
            try { return document.querySelectorAll(selector).length === 1; } catch { return false; }
        };
        const step = (node) => {
            if (node.id && stable(node.id)) { return `#${CSS.escape(node.id)}`; }
            const testID = node.getAttribute("data-testid");
            if (testID) { return `${node.localName}[data-testid="${CSS.escape(testID)}"]`; }
            const classes = [...node.classList].filter(stable).slice(0, 3);
            return node.localName + classes.map((name) => `.${CSS.escape(name)}`).join("");
        };
        const position = (node) => {
            const twins = [...node.parentElement.children].filter((child) => child.localName === node.localName);
            return twins.length > 1 ? `:nth-of-type(${twins.indexOf(node) + 1})` : "";
        };

        // Bare tags alone could match anything a page adds later, so a path
        // needs an id, test id or class in it, or must start at the body.
        const path = [];
        let anchored = false;
        for (let node = element; node && node !== document.documentElement; node = node.parentElement) {
            const name = step(node);
            anchored ||= name !== node.localName;
            path.unshift(name);
            const done = () => unique(path.join(" > ")) && (anchored || node === document.body);
            if (done()) { break; }
            if (!name.startsWith("#")) { path[0] += position(node); }
            if (done()) { break; }
        }
        return path.join(" > ");
    }
    """

    /// Starts zapping in the page. `onZap` gets each selector; `onEnd` is
    /// called when the page ends it, by Escape or by going away.
    static func start(
        in webView: WKWebView,
        onZap: @escaping @MainActor (String) -> Void,
        onEnd: @escaping @MainActor () -> Void
    ) -> ElementPicker {
        ElementPicker(
            in: webView,
            world: BoostInjector.world,
            name: "boostZap",
            tint: "#ff4d6d",
            report: selectorFunction,
            onPick: { picked in
                if let selector = picked as? String, !selector.isEmpty { onZap(selector) }
            },
            onEnd: onEnd
        )
    }
}
