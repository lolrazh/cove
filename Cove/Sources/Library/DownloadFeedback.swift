import AppKit
import Combine
import SwiftUI

/// Feedback is a transient event, never restored from download history.
struct DownloadStarted {
    let windowNumber: Int
    let sourceInWindow: CGPoint
    let pageInWindow: CGRect
    let icon: NSImage
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
                                           pageInWindow: event.pageInWindow, icon: event.icon))
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
        let file = CALayer()
        file.bounds = CGRect(x: 0, y: 0, width: 36, height: 36)
        file.position = end
        file.contents = event.icon.cgImage(forProposedRect: nil, context: nil, hints: nil)
        file.contentsGravity = .resizeAspect
        file.contentsScale = window?.backingScaleFactor ?? 2
        file.shadowColor = NSColor.black.cgColor
        file.shadowOpacity = 0.22
        file.shadowRadius = 8
        file.shadowOffset = CGSize(width: 0, height: 3)
        file.opacity = 0
        layer.addSublayer(file)
        let id = UUID()
        flights[id] = file
        let position = CAKeyframeAnimation(keyPath: "position")
        position.path = path
        position.calculationMode = .paced
        position.timingFunction = CAMediaTimingFunction(controlPoints: 0.45, 0, 0.75, 1)
        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = [0.65, 1.15, 1, 0.3]
        scale.keyTimes = [0, 0.22, 0.5, 1]
        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [0, 1, 1, 0]
        opacity.keyTimes = [0, 0.1, 0.87, 1]
        let group = CAAnimationGroup()
        group.animations = [position, scale, opacity]
        group.duration = 0.62
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
