import SwiftUI

/// Capture over the page it was started on: while selecting, a bar to pick
/// region or element mode, and in region mode the page dimmed under a
/// crosshair to drag a rectangle with; once captured, what to do with it.
struct CaptureOverlay: View {
    @ObservedObject var tabManager: TabManager
    let page: TabSession

    var body: some View {
        if let session = tabManager.capture, session.page === page {
            CaptureView(session: session, tabManager: tabManager)
        }
    }
}

private struct CaptureView: View {
    @ObservedObject var session: CaptureSession
    let tabManager: TabManager

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            switch session.phase {
            case .selecting(let mode):
                if mode == .region {
                    RegionSelector { rect in
                        Task { await session.captureRegion(rect) }
                    }
                    .transition(.opacity)
                }
                CaptureModeBar(session: session, onCancel: tabManager.endCapture)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .transition(slide(from: .top))
            case .captured(let capture):
                CaptureResultBar(capture: capture, tabManager: tabManager)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .transition(slide(from: .bottom))
            }
        }
        .animation(reduceMotion ? ChromeMotion.fade : ChromeMotion.appear, value: session.isCaptured)
    }

    private func slide(from edge: Edge) -> AnyTransition {
        reduceMotion ? .opacity : .move(edge: edge).combined(with: .opacity)
    }
}

/// The page dimmed under a crosshair. Dragging cuts a clear rectangle out of
/// the dim, with its size beside it; letting go captures what's inside.
private struct RegionSelector: View {
    let onSelect: (CGRect) -> Void

    @State private var selection: CGRect?

    var body: some View {
        GeometryReader { geometry in
            let bounds = CGRect(origin: .zero, size: geometry.size)
            ZStack(alignment: .topLeading) {
                Path { path in
                    path.addRect(bounds)
                    if let selection { path.addRect(selection) }
                }
                .fill(.black.opacity(0.3), style: FillStyle(eoFill: true))

                if let selection {
                    Rectangle()
                        .stroke(.white.opacity(0.9), lineWidth: 1)
                        .frame(width: selection.width, height: selection.height)
                        .offset(x: selection.minX, y: selection.minY)
                    sizeLabel(selection, in: bounds)
                }
            }
            .contentShape(Rectangle())
            .pointerStyle(.rectSelection)
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { drag in
                        selection = CGRect(corners: drag.startLocation, drag.location).intersection(bounds)
                    }
                    .onEnded { _ in
                        if let selection { onSelect(selection) }
                        selection = nil
                    }
            )
        }
    }

    private func sizeLabel(_ selection: CGRect, in bounds: CGRect) -> some View {
        Text("\(Int(selection.width)) × \(Int(selection.height))")
            .font(.caption.monospacedDigit().weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.black.opacity(0.6), in: Capsule())
            .offset(x: selection.minX, y: selection.maxY + 24 < bounds.maxY ? selection.maxY + 6 : selection.minY - 24)
            .allowsHitTesting(false)
    }
}

/// Region or element, a hint, and Cancel (Escape).
private struct CaptureModeBar: View {
    @ObservedObject var session: CaptureSession
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Picker("Capture", selection: Binding(get: { session.mode ?? .region }, set: session.select)) {
                Label("Region", systemImage: ChromeSymbols.Capture.region).tag(CaptureSession.Mode.region)
                Label("Element", systemImage: ChromeSymbols.Capture.element).tag(CaptureSession.Mode.element)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()

            Text(session.mode == .element ? "Click an element to capture it" : "Drag over the page to capture a region")
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Button(action: onCancel) {
                Image(systemName: ChromeSymbols.Tabs.close)
            }
            .buttonStyle(ChromeButtonStyle(size: .accessory(side: 22)))
            .keyboardShortcut(.cancelAction)
            .help("Cancel Capture")
        }
        .padding(.leading, 8)
        .padding(.trailing, 6)
        .frame(height: 40)
        .chromeFloatingSurface(minimumRadius: ChromeRadius.tile)
        .padding(12)
    }
}

/// The capture's thumbnail, and what to do with it.
private struct CaptureResultBar: View {
    let capture: Capture
    let tabManager: TabManager

    var body: some View {
        HStack(spacing: 4) {
            Image(nsImage: capture.image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 88, maxHeight: 48)
                .clipShape(.rect(cornerRadius: ChromeRadius.accessory))
                .padding(.trailing, 6)

            action("Copy", symbol: ChromeSymbols.Capture.copy) { tabManager.copyCapture(capture) }
            action("Save…", symbol: ChromeSymbols.Capture.save) { tabManager.saveCapture(capture) }
            if tabManager.documentStore != nil {
                send(to: .note)
                send(to: .easel)
            }

            Button(action: tabManager.endCapture) {
                Image(systemName: ChromeSymbols.Tabs.close)
            }
            .buttonStyle(ChromeButtonStyle(size: .accessory(side: 22)))
            .keyboardShortcut(.cancelAction)
            .help("Done")
        }
        .padding(8)
        .chromeFloatingSurface(minimumRadius: ChromeRadius.tile)
        .padding(16)
    }

    /// A new note or easel, or a recent one.
    private func send(to kind: DocumentKind) -> some View {
        Menu {
            Button("New \(kind.name)") { tabManager.sendCapture(capture, to: kind, id: nil) }
            let documents = tabManager.captureDestinations(kind).prefix(8)
            if !documents.isEmpty {
                Divider()
                ForEach(documents) { document in
                    Button(document.displayTitle) { tabManager.sendCapture(capture, to: kind, id: document.id) }
                }
            }
        } label: {
            Label("Send to \(kind.name)", systemImage: kind.symbol)
                .padding(.horizontal, 8)
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(ChromeButtonStyle())
        .fixedSize()
    }

    private func action(_ title: String, symbol: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Label(title, systemImage: symbol)
                .padding(.horizontal, 8)
        }
        .buttonStyle(ChromeButtonStyle())
    }
}

private extension CaptureSession {
    var isCaptured: Bool {
        if case .captured = phase { true } else { false }
    }
}

private extension CGRect {
    /// The rect between two points, whichever way they lie.
    init(corners a: CGPoint, _ b: CGPoint) {
        self.init(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }
}
