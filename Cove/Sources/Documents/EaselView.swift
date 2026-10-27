import SwiftUI
import UniformTypeIdentifiers
import WebKit

/// An easel in the page card: a bar with its title, the tools, the ink and
/// zoom, over the canvas. Pinching and scrolling also zoom and pan.
struct EaselView: View {
    let id: UUID
    @ObservedObject var easel: Easel
    @ObservedObject var store: DocumentStore
    let dataStore: WKWebsiteDataStore
    let onOpenURL: (URL) -> Void

    @State private var tool = EaselTool.select
    @State private var ink = EaselInk.label
    @State private var scrollView: NSScrollView?

    var body: some View {
        VStack(spacing: 0) {
            bar
            Divider()
            EaselCanvas(easel: easel, tool: $tool, ink: ink, dataStore: dataStore, onOpenURL: onOpenURL) { scrollView = $0 }
        }
        .background(ChromePalette.content)
    }

    private var bar: some View {
        HStack(spacing: 2) {
            TextField(
                DocumentKind.easel.untitledName,
                text: Binding(get: { store.documents[id]?.title ?? "" }, set: { store.rename(id, to: $0) })
            )
            .textFieldStyle(.plain)
            .font(.headline)
            .frame(maxWidth: 240)
            .padding(.leading, 12)

            Spacer(minLength: 12)

            toolButton(.select, "Select", symbol: "cursorarrow")
            toolButton(.text, "Text", symbol: "textformat")
            toolButton(.draw, "Draw", symbol: "pencil.tip")
            inkMenu
            button("Add Image", symbol: "photo", action: addImage)

            Divider().frame(height: 16).padding(.horizontal, 6)

            button("Zoom Out", symbol: "minus.magnifyingglass") { zoom(by: 1 / 1.25) }
            button("Actual Size", symbol: "1.magnifyingglass") { zoom(to: 1) }
            button("Zoom In", symbol: "plus.magnifyingglass") { zoom(by: 1.25) }
        }
        .padding(.trailing, 8)
        .frame(height: ChromeMetrics.navigationBarHeight)
    }

    private func toolButton(_ value: EaselTool, _ title: String, symbol: String) -> some View {
        Button { tool = value } label: {
            Image(systemName: symbol)
                .foregroundStyle(tool == value ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
        }
        .buttonStyle(ChromeButtonStyle())
        .background(tool == value ? AnyShapeStyle(ChromePalette.resting) : AnyShapeStyle(.clear), in: .chrome(minimum: ChromeRadius.control))
        .help(title)
    }

    private var inkMenu: some View {
        Menu {
            ForEach(EaselInk.allCases, id: \.self) { ink in
                Button(ink.rawValue.capitalized) { self.ink = ink }
            }
        } label: {
            Circle()
                .fill(Color(nsColor: ink.color))
                .frame(width: 14, height: 14)
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(ChromeButtonStyle())
        .fixedSize()
        .help("Ink")
    }

    private func button(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
        }
        .buttonStyle(ChromeButtonStyle())
        .help(title)
    }

    private func zoom(by factor: CGFloat) {
        zoom(to: (scrollView?.magnification ?? 1) * factor)
    }

    private func zoom(to magnification: CGFloat) {
        guard let scrollView else { return }
        let center = CGPoint(x: scrollView.documentVisibleRect.midX, y: scrollView.documentVisibleRect.midY)
        scrollView.animator().setMagnification(magnification, centeredAt: center)
    }

    /// An open panel for images; each lands in the middle of the view.
    private func addImage() {
        guard let scrollView, let window = scrollView.window else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        Task {
            guard await panel.beginSheetModal(for: window) == .OK else { return }
            let visible = scrollView.documentVisibleRect
            for (offset, url) in panel.urls.enumerated() {
                guard let image = NSImage(contentsOf: url) else { continue }
                easel.add(image, at: CGPoint(x: visible.midX - 120 + CGFloat(offset * 24), y: visible.midY - 90 + CGFloat(offset * 24)))
            }
        }
    }
}

/// The canvas in a scroll view that pans and pinch-zooms.
private struct EaselCanvas: NSViewRepresentable {
    let easel: Easel
    @Binding var tool: EaselTool
    let ink: EaselInk
    let dataStore: WKWebsiteDataStore
    let onOpenURL: (URL) -> Void
    let onMake: (NSScrollView) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let canvas = EaselCanvasView(easel: easel, dataStore: dataStore)
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.25
        scrollView.maxMagnification = 3
        scrollView.documentView = canvas
        DispatchQueue.main.async {
            // Keys go to the canvas, not the title, until something else is clicked.
            scrollView.window?.makeFirstResponder(canvas)
            onMake(scrollView)
        }
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let canvas = scrollView.documentView as? EaselCanvasView else { return }
        canvas.tool = tool
        canvas.ink = ink
        canvas.onOpenURL = onOpenURL
        canvas.onToolChange = { tool = $0 }
    }
}
