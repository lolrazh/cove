import WebKit

/// Picks elements on a page: the element under the pointer is outlined, and
/// a click reports it. Escape, or leaving the page, ends it. Boosts' Zap and
/// Capture's element mode both pick this way.
///
/// The script runs in the content world it's given, apart from the page's
/// own scripts. It swallows the click and the presses around it, so a picked
/// link or button does nothing. What a pick reports is the picker's to say:
/// a JavaScript function from the element to any value a message can carry.
@MainActor
final class ElementPicker {
    private static func script(name: String, tint: String, report: String) -> String {
        """
        (() => {
            const report = \(report);
            const post = (message) => webkit.messageHandlers.\(name).postMessage(message);
            const outline = document.createElement("div");
            outline.style.cssText = `position: fixed; z-index: 2147483647; pointer-events: none;
                border: 2px solid \(tint); border-radius: 4px;
                background: color-mix(in srgb, \(tint) 15%, transparent);
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
                    outline.style.display = "none";
                    post({ picked: report(target) });
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
            globalThis.\(name) = { stop };
        })();
        """
    }

    private weak var webView: WKWebView?
    private let name: String
    private let world: WKContentWorld
    private var isRunning = true

    /// Starts picking in the page. `name` names the message handler and must
    /// be a JavaScript identifier; `tint` is the outline's CSS color. `onPick`
    /// gets what `report` returned for each element clicked; `onEnd` is called
    /// when the page ends picking, by Escape or by going away.
    init(
        in webView: WKWebView,
        world: WKContentWorld,
        name: String,
        tint: String,
        report: String,
        onPick: @escaping @MainActor (Any) -> Void,
        onEnd: @escaping @MainActor () -> Void
    ) {
        self.webView = webView
        self.name = name
        self.world = world
        let relay = Relay { [weak self] message in
            if let picked = message["picked"] {
                onPick(picked)
            } else if message["ended"] != nil {
                self?.stop()
                onEnd()
            }
        }
        webView.configuration.userContentController.add(relay, contentWorld: world, name: name)
        webView.evaluateJavaScript(Self.script(name: name, tint: tint, report: report), in: nil, in: world)
        // Escape goes to the page from here.
        webView.window?.makeFirstResponder(webView)
    }

    /// Ends picking; the page is left as it was.
    func stop() {
        guard isRunning, let webView else { return }
        isRunning = false
        webView.evaluateJavaScript("globalThis.\(name)?.stop()", in: nil, in: world)
        webView.configuration.userContentController.removeScriptMessageHandler(forName: name, contentWorld: world)
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
