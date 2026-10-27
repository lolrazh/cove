import WebKit

/// Reports the link under the pointer, for the preview in the page's corner.
///
/// A user script in every frame watches `mouseover` for anchors and posts the
/// href whenever it changes; a handler relays it to the tab. Both live in
/// WebKit's client content world, out of the page's own scripts' reach.
enum LinkHover {
    private static let messageName = "linkHover"

    private static let script = """
    (() => {
        let current = null;
        const report = (href) => {
            if (href === current) { return; }
            current = href;
            webkit.messageHandlers.\(messageName).postMessage(href ?? "");
        };
        document.addEventListener("mouseover", (event) => {
            const anchor = event.target instanceof Element ? event.target.closest("a[href]") : null;
            report(anchor ? anchor.href : null);
        }, { capture: true, passive: true });
        document.documentElement.addEventListener("mouseleave", () => report(null), { passive: true });
    })();
    """

    static func install(in controller: WKUserContentController, onChange: @escaping @MainActor (URL?) -> Void) {
        controller.addUserScript(WKUserScript(
            source: script,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false,
            in: .defaultClient
        ))
        controller.add(Relay(onChange), contentWorld: .defaultClient, name: messageName)
    }

    private final class Relay: NSObject, WKScriptMessageHandler {
        private let onChange: @MainActor (URL?) -> Void

        init(_ onChange: @escaping @MainActor (URL?) -> Void) {
            self.onChange = onChange
        }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            let href = message.body as? String ?? ""
            let url = href.isEmpty ? nil : URL(string: href)
            MainActor.assumeIsolated { onChange(url) }
        }
    }
}
