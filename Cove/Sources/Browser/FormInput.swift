import WebKit

/// Reports whether the page holds typed input a reload would lose, so a
/// background tab with a half-written form stays awake.
///
/// A user script in the main frame remembers the fields that got `input`
/// events and, on every input, key or click, posts whether any of them still
/// differs from its default (or, for an editable element, still has text).
/// Checking on keys and clicks catches fields a page empties itself, like a
/// chat composer after Return. The handler relays the answer to the tab.
enum FormInput {
    private static let messageName = "formInput"

    private static let script = """
    (() => {
        const touched = new Set();
        let reported = false;
        const isDirty = (element) => {
            if (element.isContentEditable) { return element.textContent.trim().length > 0; }
            return "defaultValue" in element && element.value !== element.defaultValue;
        };
        const check = () => {
            for (const element of touched) {
                if (!element.isConnected) { touched.delete(element); }
            }
            const dirty = [...touched].some(isDirty);
            if (dirty === reported) { return; }
            reported = dirty;
            webkit.messageHandlers.\(messageName).postMessage(dirty);
        };
        document.addEventListener("input", (event) => {
            if (event.target instanceof Element) { touched.add(event.target); }
            check();
        }, { capture: true, passive: true });
        document.addEventListener("keyup", check, { capture: true, passive: true });
        document.addEventListener("click", check, { capture: true, passive: true });
    })();
    """

    @MainActor
    static func install(in controller: WKUserContentController, onChange: @escaping @MainActor (Bool) -> Void) {
        controller.addUserScript(WKUserScript(
            source: script,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true,
            in: .defaultClient
        ))
        controller.add(Relay(onChange), contentWorld: .defaultClient, name: messageName)
    }

    private final class Relay: NSObject, WKScriptMessageHandler {
        private let onChange: @MainActor (Bool) -> Void

        init(_ onChange: @escaping @MainActor (Bool) -> Void) {
            self.onChange = onChange
        }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            let hasInput = message.body as? Bool ?? false
            MainActor.assumeIsolated { onChange(hasInput) }
        }
    }
}
