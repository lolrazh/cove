import AppKit
import Combine
import SwiftUI

/// Feedback is a transient event, never restored from download history.
struct DownloadStarted {
    let windowNumber: Int
    let sourceInWindow: CGPoint
    let pageInWindow: CGRect
    let icon: NSImage
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
                                           pageInWindow: event.pageInWindow, icon: event.icon, filename: event.filename))
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
        let start = convert(event.sourceInWindow, from: nil)
        let distance = hypot(end.x - start.x, end.y - start.y)
        // Lift first, then accelerate into the header. The last segment has no pause.
        let lift = min(76, max(28, distance * 0.16))
        let path = CGMutablePath()
        path.move(to: start)
        path.addCurve(to: end,
                      control1: CGPoint(x: start.x + (end.x - start.x) * 0.08, y: start.y - lift),
                      control2: CGPoint(x: end.x, y: end.y + min(60, distance * 0.12)))
        let file = makeCard(for: event)
        file.position = end
        file.shadowColor = NSColor.black.cgColor
        file.shadowOpacity = 0.22
        file.shadowRadius = 10
        file.shadowOffset = CGSize(width: 0, height: 3)
        file.opacity = 0
        layer.addSublayer(file)
        let id = UUID()
        flights[id] = file
        let position = CAKeyframeAnimation(keyPath: "position")
        position.path = path
        position.calculationMode = .paced
        position.timingFunction = CAMediaTimingFunction(controlPoints: 0.77, 0, 0.175, 1)
        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = [0.97, 1, 1, 0.08]
        scale.keyTimes = [0, 0.12, 0.58, 1]
        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [1, 1, 0]
        opacity.keyTimes = [0, 0.88, 1]
        let group = CAAnimationGroup()
        group.animations = [position, scale, opacity]
        group.duration = 0.30
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

    /// Dia's native DownloadItemView is a 220 × 36 pt card, not a loose file icon.
    /// Keep it at readable size until the last part of the flight.
    private func makeCard(for event: DownloadStarted) -> CALayer {
        let scale = window?.backingScaleFactor ?? 2
        let card = CALayer()
        card.bounds = CGRect(x: 0, y: 0, width: 220, height: 36)
        card.cornerRadius = 16
        card.cornerCurve = .continuous
        card.borderWidth = 0.5
        card.contentsScale = scale
        let appearance = window?.effectiveAppearance ?? NSAppearance.currentDrawing()
        appearance.performAsCurrentDrawingAppearance {
            card.backgroundColor = NSColor.windowBackgroundColor.cgColor
            card.borderColor = NSColor.secondarySystemFill.cgColor
            let icon = CALayer()
            icon.frame = CGRect(x: 8, y: 8, width: 20, height: 20)
            icon.contents = event.icon.cgImage(forProposedRect: nil, context: nil, hints: nil)
            icon.contentsGravity = .resizeAspect
            icon.contentsScale = scale
            card.addSublayer(icon)
            for (text, size, y, color, truncation) in [
                (event.filename, 12.0, 3.0, NSColor.labelColor, CATextLayerTruncationMode.middle),
                ("Downloading…", 10.0, 18.0, NSColor.secondaryLabelColor, CATextLayerTruncationMode.end)
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
