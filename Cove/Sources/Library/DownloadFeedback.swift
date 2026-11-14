import AppKit
import Combine
import SwiftUI

/// Feedback is a transient event, never restored from download history.
struct DownloadStarted {
    let windowNumber: Int
    let sourceInWindow: CGPoint
    let pageInWindow: CGRect
    let filename: String
}

struct DownloadButtonAnchor: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? { nil }
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        if let next = nextValue() { value = next }
    }
}

/// One pass-through layer for the window, not one animation per copy of the sidebar.
/// Core Animation moves the file without invalidating the page or the tab layout.
struct DownloadFeedback: NSViewRepresentable {
    let manager: DownloadManager
    let library: LibraryModel
    let destination: CGPoint?
    let reduceMotion: Bool

    func makeNSView(context: Context) -> DownloadFlightView { DownloadFlightView() }

    func updateNSView(_ view: DownloadFlightView, context: Context) {
        view.configure(manager: manager, library: library)
        view.destination = destination
        view.reduceMotion = reduceMotion
        view.launchPending()
    }

    static func dismantleNSView(_ view: DownloadFlightView, coordinator: ()) { view.stop() }
}

@MainActor
final class DownloadFlightView: NSView {
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    var destination: CGPoint?
    var reduceMotion = false
    private weak var manager: DownloadManager?
    private weak var library: LibraryModel?
    private var subscription: AnyCancellable?
    private var mouseMonitor: Any?
    private var lastClick: (point: CGPoint, time: TimeInterval)?
    private var pending: [DownloadStarted] = []
    private var flights: [UUID: CALayer] = [:]
    private var settleTask: Task<Void, Never>?
    private var revealTask: Task<Void, Never>?
    private var awaitingReveal = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        trackClicks()
    }

    private func trackClicks() {
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
        mouseMonitor = nil
        lastClick = nil
        guard window != nil else { return }
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            if let self, event.window === self.window {
                self.lastClick = (event.locationInWindow, ProcessInfo.processInfo.systemUptime)
            }
            return event
        }
    }

    func configure(manager: DownloadManager, library: LibraryModel) {
        guard self.manager !== manager else { return }
        stop()
        self.manager = manager
        self.library = library
        trackClicks()
        subscription = manager.started.sink { [weak self] event in self?.receive(event) }
    }

    private func receive(_ event: DownloadStarted) {
        // Focus may change while the response arrives. Never raise or activate its window.
        guard let window, window.isVisible, !window.isMiniaturized,
              window.windowNumber == event.windowNumber else { return }
        settleTask?.cancel()
        if destination == nil && !awaitingReveal {
            awaitingReveal = true
            revealTask = Task { @MainActor [weak self] in
                // The hidden header slides in over 140 ms. Use its settled anchor.
                try? await Task.sleep(for: .milliseconds(170))
                guard !Task.isCancelled, let self else { return }
                self.awaitingReveal = false
                self.launchPending()
            }
        }
        library?.downloadFeedbackActive = true
        // Capture the click now; another click during reveal must not move this source.
        let source: CGPoint
        if let lastClick, ProcessInfo.processInfo.systemUptime - lastClick.time < 3,
           event.pageInWindow.contains(lastClick.point) {
            source = lastClick.point
        } else {
            source = event.sourceInWindow
        }
        // A burst must not create an unbounded queue or delay later transfers.
        if pending.count < 4 {
            pending.append(DownloadStarted(windowNumber: event.windowNumber, sourceInWindow: source,
                                           pageInWindow: event.pageInWindow, filename: event.filename))
        }
        launchPending()
    }

    func launchPending() {
        guard !awaitingReveal, let destination, !pending.isEmpty else { return }
        let events = pending
        pending.removeAll()
        for event in events {
            if reduceMotion || flights.count >= 4 {
                landed()
                continue
            }
            fly(event, to: destination)
        }
    }

    private func fly(_ event: DownloadStarted, to end: CGPoint) {
        guard let layer else { return }
        let source = convert(event.sourceInWindow, from: nil)
        // Leave room for the card's brief dip, including links near a page edge.
        let start = CGPoint(x: min(max(118, source.x), bounds.width - 118),
                            y: min(max(20, source.y), bounds.height - 64))
        let distance = hypot(end.x - start.x, end.y - start.y)
        let dip = min(42, distance * 0.15)
        let dx = end.x - start.x, dy = end.y - start.y
        // Fitted to the live Dia capture: dip and tilt, then a fast upward sweep.
        // Keep position, scale, tilt, and fade on the same timeline.
        let times: [NSNumber] = [0, 0.10, 0.24, 0.38, 0.62, 0.81, 0.95, 1]
        let points = [
            CGPoint(x: start.x, y: start.y + dip * 0.5),
            CGPoint(x: start.x + dx * 0.007, y: start.y + dip * 0.58),
            CGPoint(x: start.x + dx * 0.036, y: start.y + dip * 0.92),
            CGPoint(x: start.x + dx * 0.065, y: start.y + dip),
            CGPoint(x: start.x + dx * 0.25, y: start.y + dip * 0.29),
            CGPoint(x: start.x + dx * 0.63, y: start.y + dy * 0.46),
            CGPoint(x: start.x + dx * 0.96, y: start.y + dy * 0.93), end
        ]
        let file = DownloadFlightCard.make(filename: event.filename,
            appearance: window?.effectiveAppearance ?? NSAppearance.currentDrawing(),
            scale: window?.backingScaleFactor ?? 2)
        file.position = end
        file.shadowColor = NSColor.black.cgColor
        file.shadowOpacity = 0.28
        file.shadowRadius = 20
        file.shadowOffset = CGSize(width: 0, height: 12)
        file.shadowPath = CGPath(roundedRect: file.bounds, cornerWidth: 16, cornerHeight: 16, transform: nil)
        file.opacity = 0
        layer.addSublayer(file)
        let id = UUID()
        flights[id] = file
        let position = CAKeyframeAnimation(keyPath: "position")
        position.values = points.map { NSValue(point: $0) }
        position.keyTimes = times
        position.calculationMode = .cubic
        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = [0.97, 1.04, 1.06, 1.02, 0.99, 0.88, 0.45, 0.36]
        scale.keyTimes = times
        scale.calculationMode = .cubic
        let tilt = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        let direction = dx <= 0 ? 1.0 : -1.0
        tilt.values = [0, -0.013, -0.057, -0.105, -0.065, -0.009, 0, 0].map { $0 * direction }
        tilt.keyTimes = times
        tilt.calculationMode = .cubic
        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [0, 1, 1, 0.96, 0.12, 0]
        opacity.keyTimes = [0, 0.08, 0.62, 0.81, 0.95, 1]
        let shadow = CAKeyframeAnimation(keyPath: "shadowRadius")
        shadow.values = [0, 20, 20, 0]
        shadow.keyTimes = [0, 0.10, 0.62, 1]
        let group = CAAnimationGroup()
        group.animations = [position, scale, tilt, opacity, shadow]
        group.duration = 0.35
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            Task { @MainActor in
                guard let self, let file = self.flights.removeValue(forKey: id) else { return }
                file.removeFromSuperlayer()
                self.landed()
            }
        }
        file.add(group, forKey: "downloadFlight")
        CATransaction.commit()
    }

    private func landed() {
        // View updates can supply a newly revealed anchor. Publish after that update.
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.library?.downloadPulse += 1
            guard self.flights.isEmpty, self.pending.isEmpty else { return }
            self.settleTask?.cancel()
            self.settleTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(800))
                guard !Task.isCancelled else { return }
                self?.library?.downloadFeedbackActive = false
            }
        }
    }

    func stop() {
        subscription = nil
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
        mouseMonitor = nil
        settleTask?.cancel()
        revealTask?.cancel()
        awaitingReveal = false
        pending.removeAll()
        for flight in flights.values { flight.removeAllAnimations(); flight.removeFromSuperlayer() }
        flights.removeAll()
        let previousLibrary = library
        Task { @MainActor in previousLibrary?.downloadFeedbackActive = false }
        manager = nil
    }
}

/// Shared by the flight and the local still-card preview renderer.
@MainActor
enum DownloadFlightCard {
    /// Dia's native DownloadItemView is a 220 × 36 pt card, not a loose file icon.
    /// Keep it at readable size until the last part of the flight.
    static func make(filename: String, appearance: NSAppearance, scale: CGFloat,
                     cornerRadius: CGFloat = 16) -> CALayer {
        let card = CALayer()
        card.bounds = CGRect(x: 0, y: 0, width: 220, height: 36)
        card.cornerRadius = cornerRadius
        card.cornerCurve = .continuous
        card.borderWidth = 0.5
        card.contentsScale = scale
        appearance.performAsCurrentDrawingAppearance {
            card.backgroundColor = NSColor.windowBackgroundColor.cgColor
            card.borderColor = NSColor.secondarySystemFill.cgColor
            let titleColor: NSColor = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .white : .black
            let icon = CALayer()
            icon.frame = CGRect(x: 8, y: 8, width: 20, height: 20)
            let image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(paletteColors: [NSColor.secondaryLabelColor]))
            icon.contents = image?.cgImage(forProposedRect: nil, context: nil, hints: nil)
            icon.contentsGravity = .resizeAspect
            icon.contentsScale = scale
            card.addSublayer(icon)
            for (text, size, y, color, truncation) in [
                (filename, 12.0, 3.0, titleColor, CATextLayerTruncationMode.middle),
                ("Downloading…", 10.0, 18.0, titleColor.withAlphaComponent(0.7), CATextLayerTruncationMode.end)
            ] {
                let label = CATextLayer()
                label.frame = CGRect(x: 36, y: y, width: 176, height: size + 3)
                label.string = text
                label.font = NSFont.systemFont(ofSize: size)
                label.fontSize = size
                label.foregroundColor = color.cgColor
                label.truncationMode = truncation
                label.contentsScale = scale
                card.addSublayer(label)
            }
        }
        return card
    }
}
