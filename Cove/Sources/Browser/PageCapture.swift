import AppKit
import WebKit

/// Where a capture came from: the page, and the region of it the capture
/// shows, in CSS pixels from the top left of the document, with the width of
/// the page's viewport at the time. Enough to show the same region again
/// live, as an easel's web clipping does.
struct CaptureSource: Codable, Hashable {
    let url: URL
    let title: String
    let rect: CGRect
    let viewportWidth: Double

    /// "Capture of" the page's title, or its site.
    var name: String {
        "Capture of \(title.isEmpty ? Site(url)?.domain ?? "Page" : title)"
    }
}

/// A region of a page, caught as an image.
struct Capture {
    let image: NSImage
    let source: CaptureSource

    /// The image as PNG, at the screen's resolution and marked with it, so
    /// it opens at the size it was on screen.
    var pngData: Data? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        bitmap.size = image.size
        return bitmap.representation(using: .png, properties: [:])
    }
}

/// How a page's CSS pixels sit in its web view at a moment: how far the page
/// is scrolled, and how many CSS pixels wide its viewport is against the
/// view's width in points, which says how far it's zoomed.
struct PageGeometry: Equatable {
    /// The scroll offset, in CSS pixels.
    let scroll: CGPoint
    let viewportWidth: Double
    /// The web view's width, in points.
    let viewWidth: Double

    /// Points per CSS pixel.
    var scale: Double {
        viewportWidth > 0 ? viewWidth / viewportWidth : 1
    }

    /// A rect in the view's points, from its top left, as the region of the
    /// document it covers.
    func pageRect(forViewRect rect: CGRect) -> CGRect {
        CGRect(
            x: rect.minX / scale + scroll.x,
            y: rect.minY / scale + scroll.y,
            width: rect.width / scale,
            height: rect.height / scale
        )
    }

    /// A rect in the viewport's CSS pixels, as `getBoundingClientRect`
    /// reports one, in the view's points.
    func viewRect(forClientRect rect: CGRect) -> CGRect {
        CGRect(x: rect.minX * scale, y: rect.minY * scale, width: rect.width * scale, height: rect.height * scale)
    }
}

/// Capture over one page: a region dragged out over it, or an element picked
/// on it, becomes an image, then waits to be copied, saved or sent on.
@MainActor
final class CaptureSession: ObservableObject {
    enum Mode: CaseIterable {
        /// Drag out a rectangle over the page.
        case region
        /// Click an element; it's outlined under the pointer first.
        case element
    }

    enum Phase {
        case selecting(Mode)
        case captured(Capture)
    }

    @Published private(set) var phase: Phase = .selecting(.region)

    /// The page being captured: the overlay shows over it alone.
    let page: TabSession
    private let onEnd: () -> Void
    private var picker: ElementPicker?

    /// Capture's own content world, so the page can't see or tamper with it.
    private static let world = WKContentWorld.world(name: "Capture")

    /// The page's scroll offset and viewport width, which place a rect of
    /// the view on the document.
    private static let geometryScript = "({ x: scrollX, y: scrollY, width: innerWidth })"

    /// What an element pick reports: its rect in the viewport.
    private static let elementReport = """
    (element) => {
        const box = element.getBoundingClientRect();
        return { x: box.left, y: box.top, width: box.width, height: box.height };
    }
    """

    /// `onEnd` is called when the page ends the capture, as Escape in element
    /// mode does.
    init(page: TabSession, onEnd: @escaping () -> Void) {
        self.page = page
        self.onEnd = onEnd
    }

    var mode: Mode? {
        if case .selecting(let mode) = phase { mode } else { nil }
    }

    func select(_ mode: Mode) {
        stopPicking()
        phase = .selecting(mode)
        guard mode == .element, let webView = page.webView else { return }
        picker = ElementPicker(
            in: webView,
            world: Self.world,
            name: "capture",
            tint: "#0a84ff",
            report: Self.elementReport
        ) { [weak self] picked in
            guard let self, let box = picked as? [String: Double] else { return }
            stopPicking()
            Task { await self.captureElement(CGRect(x: box["x"] ?? 0, y: box["y"] ?? 0, width: box["width"] ?? 0, height: box["height"] ?? 0)) }
        } onEnd: { [weak self] in
            self?.onEnd()
        }
    }

    /// Captures a region of the page, in the web view's points from its top
    /// left; the part outside the view is left out.
    func captureRegion(_ rect: CGRect) async {
        guard let webView = page.webView else { return }
        let rect = rect.intersection(webView.bounds).integral
        guard rect.width >= 2, rect.height >= 2, let geometry = await geometry(of: webView) else { return }

        let configuration = WKSnapshotConfiguration()
        configuration.rect = rect
        guard let image = try? await webView.takeSnapshot(configuration: configuration),
              let url = webView.url else { return }
        let source = CaptureSource(
            url: url,
            title: page.pageTitle,
            rect: geometry.pageRect(forViewRect: rect),
            viewportWidth: geometry.viewportWidth
        )
        phase = .captured(Capture(image: image, source: source))
    }

    /// Ends picking; the page is left as it was.
    func stopPicking() {
        picker?.stop()
        picker = nil
    }

    private func captureElement(_ clientRect: CGRect) async {
        guard let webView = page.webView, let geometry = await geometry(of: webView) else { return }
        await captureRegion(geometry.viewRect(forClientRect: clientRect))
    }

    private func geometry(of webView: WKWebView) async -> PageGeometry? {
        guard let value = try? await webView.evaluateJavaScript(Self.geometryScript, contentWorld: Self.world) as? [String: Double],
              let width = value["width"] else { return nil }
        return PageGeometry(
            scroll: CGPoint(x: value["x"] ?? 0, y: value["y"] ?? 0),
            viewportWidth: width,
            viewWidth: webView.bounds.width
        )
    }
}
