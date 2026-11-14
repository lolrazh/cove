import WebKit

/// The document owns its color. Attaching, parking, and selecting a WKWebView
/// must not overwrite that color with the compositor's temporary canvas color.
enum PageBackground {
    private static let messageName = "pageBackground"

    static func rgbValue(of color: NSColor) -> Int? {
        guard let rgb = color.usingColorSpace(.sRGB) else { return nil }
        let components = [rgb.redComponent, rgb.greenComponent, rgb.blueComponent]
        guard components.allSatisfy({ $0.isFinite }) else { return nil }
        return components.reduce(0) { ($0 << 8) | Int((min(1, max(0, $1)) * 255).rounded()) }
    }

    static func color(rgbValue value: Int) -> NSColor? {
        guard (0...0xffffff).contains(value) else { return nil }
        return NSColor(srgbRed: CGFloat((value >> 16) & 255) / 255,
                       green: CGFloat((value >> 8) & 255) / 255,
                       blue: CGFloat(value & 255) / 255, alpha: 1)
    }

    private static let script = """
    (() => {
        const root = document.documentElement;
        if (!root) return;
        const canvas = document.createElement('canvas');
        canvas.width = canvas.height = 1;
        const context = canvas.getContext('2d', {willReadFrequently: true});
        const dark = matchMedia('(prefers-color-scheme: dark)');
        let last = '', scheduled = false;
        let watched = new Set([root]);
        const paint = () => {
            scheduled = false;
            const style = getComputedStyle(root);
            const schemes = style.colorScheme.split(/\\s+/);
            const darkCanvas = schemes.includes('dark') &&
                (!schemes.includes('light') || dark.matches);
            context.fillStyle = darkCanvas ? '#000' : '#fff';
            context.fillRect(0, 0, 1, 1);
            // App shells and headers often cover an otherwise white body.
            // Follow the top edge's ancestors, ignoring small controls/images.
            const ancestors = [];
            for (let element = document.elementFromPoint(innerWidth / 2, 4);
                 element; element = element.parentElement) ancestors.unshift(element);
            const layers = new Set([root, document.body]);
            for (const element of ancestors) {
                const rect = element.getBoundingClientRect();
                if (rect.left <= innerWidth * 0.1 && rect.right >= innerWidth * 0.9 && rect.height >= 24) {
                    layers.add(element);
                }
            }
            watched = new Set([...layers, ...ancestors, ...(document.body?.children || [])]);
            for (const element of layers) {
                if (!element) continue;
                context.fillStyle = getComputedStyle(element).backgroundColor;
                context.fillRect(0, 0, 1, 1);
            }
            const rgb = Array.from(context.getImageData(0, 0, 1, 1).data).slice(0, 3);
            const key = rgb.join(',');
            if (key === last) return;
            last = key;
            webkit.messageHandlers.\(messageName).postMessage({rgb, url: location.href});
        };
        const schedule = () => {
            if (scheduled) return;
            scheduled = true;
            // Timers also run for parked pages; animation frames may be suspended.
            setTimeout(paint, 0);
        };
        // Sites also use data-theme/data-color-mode and custom CSS selectors.
        const attributes = {attributes: true};
        // Observe changes to the sampled surface and its mount points. Text
        // edits or animations elsewhere do not invalidate the cached color.
        new MutationObserver(records => {
            if (records.some(record => watched.has(record.target))) schedule();
        }).observe(root, {...attributes, childList: true, subtree: true});
        if (document.head) new MutationObserver(schedule)
            .observe(document.head, {subtree: true, childList: true, attributes: true, characterData: true});
        document.addEventListener('load', e => {
            if (e.target instanceof HTMLLinkElement) schedule();
        }, true);
        window.addEventListener('resize', schedule);
        window.addEventListener('pageshow', schedule);
        dark.addEventListener('change', schedule);
        for (const event of ['transitionend', 'animationend']) {
            document.addEventListener(event, e => {
                if (watched.has(e.target)) schedule();
            }, true);
        }
        schedule();
    })();
    """

    @MainActor
    static func install(in controller: WKUserContentController,
                        onChange: @escaping @MainActor (WKWebView, NSColor) -> Void) {
        controller.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentEnd,
                                             forMainFrameOnly: true, in: .defaultClient))
        controller.add(Relay(onChange), contentWorld: .defaultClient, name: messageName)
    }

    private final class Relay: NSObject, WKScriptMessageHandler {
        private let onChange: @MainActor (WKWebView, NSColor) -> Void

        init(_ onChange: @escaping @MainActor (WKWebView, NSColor) -> Void) {
            self.onChange = onChange
        }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.frameInfo.isMainFrame, let webView = message.webView,
                  let body = message.body as? [String: Any],
                  let url = body["url"] as? String, url == webView.url?.absoluteString,
                  let rgb = body["rgb"] as? [Double], rgb.count == 3,
                  rgb.allSatisfy({ $0.isFinite && (0...255).contains($0) }) else { return }
            let color = NSColor(srgbRed: rgb[0] / 255, green: rgb[1] / 255,
                                blue: rgb[2] / 255, alpha: 1)
            MainActor.assumeIsolated { onChange(webView, color) }
        }
    }
}

/// Shared only within one browsing context. Reopening a tab reuses its last
/// resolved color until that document reports a real change. No disk writes.
@MainActor
final class PageBackgroundCache {
    private let capacity: Int
    private var colors: [String: NSColor] = [:]
    private var order: [String] = []

    init(capacity: Int = 128) { self.capacity = max(1, capacity) }

    func color(for url: String) -> NSColor? { colors[url] }

    func store(_ color: NSColor, for url: String) {
        guard !url.isEmpty else { return }
        colors[url] = color
        order.removeAll { $0 == url }
        order.append(url)
        if order.count > capacity { colors.removeValue(forKey: order.removeFirst()) }
    }
}
