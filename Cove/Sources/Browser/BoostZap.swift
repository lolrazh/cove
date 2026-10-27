import WebKit

/// Zap mode: the element under the pointer is outlined, and clicking it hides
/// it for good, by adding a selector for it to the Boost. Escape, or leaving
/// the page, ends it.
///
/// The script runs in the Boosts' content world. It swallows the click and
/// the presses around it, so a zapped link or button does nothing. The
/// selector it reports is meant to find the same element after a reload: a
/// stable id, a test id, or the shortest path of tags and classes that finds
/// it alone, made unique with `:nth-of-type` only where needed. Classes and
/// ids with long runs of digits look generated and are skipped.
@MainActor
final class BoostZap {
    private static let messageName = "boostZap"

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

    private static func script(selector: String) -> String {
        """
        (() => {
            const selectorFor = \(selector);
            const post = (message) => webkit.messageHandlers.\(messageName).postMessage(message);
            const outline = document.createElement("div");
            outline.style.cssText = `position: fixed; z-index: 2147483647; pointer-events: none;
                border: 2px solid #ff4d6d; border-radius: 4px; background: rgb(255 77 109 / 0.15);
                transition: all 80ms ease-out; display: none;`;
            const cursor = document.createElement("style");
            cursor.textContent = "* { cursor: crosshair !important; }";
            document.documentElement.append(outline, cursor);

            let target = null;
            const show = (element) => {
                target = element;
                const box = element.getBoundingClientRect();
                Object.assign(outline.style, {
                    display: "block", left: `${box.left}px`, top: `${box.top}px`,
                    width: `${box.width}px`, height: `${box.height}px`,
                });
            };
            const swallow = (event) => {
                event.preventDefault();
                event.stopImmediatePropagation();
            };
            const listeners = {
                mouseover: (event) => {
                    if (event.target instanceof Element && event.target !== document.documentElement) { show(event.target); }
                },
                scroll: () => target && show(target),
                pointerdown: swallow,
                mousedown: swallow,
                pointerup: swallow,
                mouseup: swallow,
                click: (event) => {
                    swallow(event);
                    if (!target) { return; }
                    post({ selector: selectorFor(target) });
                    outline.style.display = "none";
                    target = null;
                },
                keydown: (event) => {
                    if (event.key !== "Escape") { return; }
                    swallow(event);
                    stop();
                    post({ ended: true });
                },
                pagehide: () => post({ ended: true }),
            };
            const stop = () => {
                for (const [type, listener] of Object.entries(listeners)) {
                    window.removeEventListener(type, listener, true);
                }
                outline.remove();
                cursor.remove();
            };
            for (const [type, listener] of Object.entries(listeners)) {
                window.addEventListener(type, listener, true);
            }
            globalThis.\(messageName) = { stop };
        })();
        """
    }

    private weak var webView: WKWebView?
    private var isRunning = true

    /// Starts zapping in the page. `onZap` gets each selector; `onEnd` is
    /// called when the page ends it, by Escape or by going away.
    init(in webView: WKWebView, onZap: @escaping @MainActor (String) -> Void, onEnd: @escaping @MainActor () -> Void) {
        self.webView = webView
        let relay = Relay { [weak self] message in
            if let selector = message["selector"] as? String, !selector.isEmpty {
                onZap(selector)
            } else if message["ended"] != nil {
                self?.stop()
                onEnd()
            }
        }
        webView.configuration.userContentController.add(relay, contentWorld: BoostInjector.world, name: Self.messageName)
        webView.evaluateJavaScript(Self.script(selector: Self.selectorFunction), in: nil, in: BoostInjector.world)
        // Escape goes to the page from here.
        webView.window?.makeFirstResponder(webView)
    }

    /// Ends zapping; the page is left as it was, less what was zapped.
    func stop() {
        guard isRunning, let webView else { return }
        isRunning = false
        webView.evaluateJavaScript("globalThis.\(Self.messageName)?.stop()", in: nil, in: BoostInjector.world)
        webView.configuration.userContentController.removeScriptMessageHandler(
            forName: Self.messageName,
            contentWorld: BoostInjector.world
        )
    }

    private final class Relay: NSObject, WKScriptMessageHandler {
        private let onMessage: @MainActor ([String: Any]) -> Void

        init(_ onMessage: @escaping @MainActor ([String: Any]) -> Void) {
            self.onMessage = onMessage
        }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any] else { return }
            MainActor.assumeIsolated { onMessage(body) }
        }
    }
}
