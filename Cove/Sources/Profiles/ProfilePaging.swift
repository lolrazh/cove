import SwiftUI
import QuartzCore

/// A stable list for each lane of the pager. Preparing a neighboring list does
/// not select its profile or load its web pages.
struct ProfileSidebarPage: Identifiable {
    let id: UUID
    let pinned: SidebarTree<TabSession>
    let today: [TodayItem<TabSession>]
    let splits: [TabSplit<UUID>]
    let selection: UUID?
}

/// Distance and release rules shared by the gesture and its tests.
enum ProfileSwipe {
    static func offset(_ translation: CGFloat, width: CGFloat, hasPrevious: Bool, hasNext: Bool) -> CGFloat {
        let limit: CGFloat = translation > 0 ? (hasPrevious ? width : 0) : (hasNext ? width : 0)
        let distance = abs(translation)
        guard distance > limit else { return translation }
        let extra = distance - limit
        let rubber = extra * 0.2 / (1 + extra / max(width, 1))
        return (translation > 0 ? 1 : -1) * (limit + rubber)
    }

    static func destination(translation: CGFloat, velocity: CGFloat, width: CGFloat,
                            hasPrevious: Bool, hasNext: Bool) -> Int {
        guard abs(translation) > 12, width > 0 else { return 0 }
        let projected = translation + velocity * 0.16
        if projected < -width * 0.3, hasNext { return 1 }
        if projected > width * 0.3, hasPrevious { return -1 }
        return 0
    }
}

/// One transaction describes the gesture, its settle, and its final handoff.
/// Revisions invalidate completions from interrupted or cancelled gestures.
struct ProfileTransitionState {
    enum Phase { case idle, tracking, settling }
    var phase: Phase = .idle
    var source: UUID?
    var previous: UUID?
    var next: UUID?
    var position: CGFloat = 0
    var revision: UInt = 0

    var isActive: Bool { phase != .idle }

    mutating func begin(source: UUID, previous: UUID?, next: UUID?, presentedPosition: CGFloat) {
        revision &+= 1
        if !isActive {
            self.source = source
            self.previous = previous
            self.next = next
            position = 0
        } else {
            position = presentedPosition
        }
        phase = .tracking
    }

    mutating func settle(to direction: Int) -> UInt {
        revision &+= 1
        phase = .settling
        return revision
    }

    func canComplete(_ token: UInt) -> Bool { phase == .settling && revision == token }

    mutating func reset() {
        self = ProfileTransitionState(revision: revision &+ 1)
    }

    func weight(for id: UUID, selected: UUID) -> Double {
        guard isActive, let source else { return id == selected ? 1 : 0 }
        let neighbor = position < 0 ? next : previous
        let fraction = neighbor == nil ? 0 : min(abs(position), 1)
        if id == source { return 1 - Double(fraction) }
        return id == neighbor ? Double(fraction) : 0
    }
}

/// Functional dragging follows the fingers directly. Only release is animated:
/// a critically damped spring carries the flick velocity, without overshoot,
/// a slow start, or a minimum wait when the list is already nearly settled.
struct ProfileMotion {
    var position: CGFloat = 0
    var velocity: CGFloat = 0
    var target: CGFloat = 0
    private var settleTime: Double?

    init(position: CGFloat = 0) { self.position = position }

    mutating func track(_ position: CGFloat) {
        self.position = position
        target = position
        velocity = 0
        settleTime = nil
    }

    mutating func settle(to target: CGFloat, initialVelocity: CGFloat = 0) {
        self.target = target
        let distance = target - position
        let omega = Self.frequency
        // At critical damping, this limit preserves momentum without crossing
        // the destination and pulling the sidebar back in the opposite direction.
        let speed = min(max(initialVelocity * (distance < 0 ? -1 : 1), 0), abs(distance) * omega)
        velocity = (distance < 0 ? -1 : 1) * speed
        settleTime = 0
    }

    private static var frequency: CGFloat { 2 * .pi / ChromeMotion.profileSettleResponse }

    /// Exact integration gives the same path at 60 Hz and 120 Hz.
    mutating func advance(_ seconds: Double) -> Bool {
        guard let time = settleTime else { return false }
        let dt = CGFloat(max(seconds, 0))
        let omega = Self.frequency
        let displacement = position - target
        let impulse = velocity + omega * displacement
        let decay = exp(-omega * dt)
        position = target + (displacement + impulse * dt) * decay
        velocity = (velocity - omega * impulse * dt) * decay
        settleTime = time + Double(dt)
        let arrived = abs(position - target) < 0.0025 && abs(velocity) < 0.08
        if arrived || time + Double(dt) >= ChromeMotion.profileSettleMaxDuration {
            position = target
            velocity = 0
            settleTime = nil
            return true
        }
        return false
    }
}

@MainActor
final class ProfileTransition: NSObject, ObservableObject {
    @Published private(set) var state = ProfileTransitionState()
    private(set) var isCommitting = false
    private var gestureOrigin: CGFloat = 0
    private var motion = ProfileMotion()
    private var link: CADisplayLink?
    private weak var clockView: NSView?
    private var lastTime: CFTimeInterval?
    private var completion: (() -> Void)?

    func attach(to view: NSView) {
        guard view.window != nil, clockView !== view else { return }
        link?.invalidate()
        clockView = view
        let driver = view.displayLink(target: self, selector: #selector(tick(_:)))
        driver.isPaused = !state.isActive
        driver.add(to: .main, forMode: .common)
        link = driver
        lastTime = nil
    }

    func detach(from view: NSView) {
        guard clockView === view else { return }
        link?.invalidate()
        link = nil
        clockView = nil
        reset()
    }

    func begin(source: UUID, previous: UUID?, next: UUID?) {
        completion = nil
        var value = state
        value.begin(source: source, previous: previous, next: next, presentedPosition: motion.position)
        if !state.isActive { motion = ProfileMotion() }
        gestureOrigin = value.position
        motion.track(value.position)
        state = value
        lastTime = nil
        link?.isPaused = true
    }

    func follow(_ translation: CGFloat, width: CGFloat) {
        guard state.phase == .tracking, width > 0 else { return }
        motion.track(ProfileSwipe.offset(gestureOrigin * width + translation, width: width,
                                      hasPrevious: state.previous != nil, hasNext: state.next != nil) / width)
        state.position = motion.position
    }

    func finish(_ translation: CGFloat, velocity: CGFloat, cancelled: Bool, width: CGFloat,
                reduceMotion: Bool, commit: @escaping (UUID) -> Void) {
        guard state.phase == .tracking, let source = state.source else { return }
        let direction = cancelled ? 0 : ProfileSwipe.destination(
            translation: gestureOrigin * width + translation, velocity: velocity, width: width,
            hasPrevious: state.previous != nil, hasNext: state.next != nil)
        let destination = (direction < 0 ? state.previous : direction > 0 ? state.next : source) ?? source
        var value = state
        let token = value.settle(to: direction)
        state = value
        motion.settle(to: -CGFloat(direction),
                      initialVelocity: cancelled || width <= 0 ? 0 : velocity / width)
        completion = { [weak self] in
            guard let self, state.canComplete(token) else { return }
            isCommitting = true
            commit(destination)
            isCommitting = false
            if direction != 0 {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .drawCompleted)
            }
            reset()
        }
        if reduceMotion {
            state.position = -CGFloat(direction)
            completion?()
        } else {
            lastTime = nil
            link?.isPaused = false
        }
    }

    @objc private func tick(_ driver: CADisplayLink) {
        guard state.phase == .settling else { driver.isPaused = true; return }
        let now = driver.timestamp
        let delta = lastTime.map { min(now - $0, 1.0 / 15) } ?? driver.duration
        lastTime = now
        let finished = motion.advance(delta)
        var value = state
        value.position = motion.position
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) { state = value }
        if finished {
            let action = completion
            completion = nil
            action?()
        }
    }

    func reset() {
        link?.isPaused = true
        completion = nil
        var value = state
        value.reset()
        state = value
        motion = ProfileMotion()
        gestureOrigin = 0
        lastTime = nil
    }
}

/// Sidebar, frame, heading, and footer use this same transition. Only the
/// web page waits for the settle to finish; scrubbing never swaps websites.
struct ProfilePager<Page: View>: View {
    @ObservedObject var tabManager: TabManager
    @ObservedObject private var transition: ProfileTransition
    let isEnabled: Bool
    @ViewBuilder let page: (ProfileSidebarPage) -> Page
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lanes: [ProfileSidebarPage] = []
    @State private var swipeSelection: UUID?

    init(tabManager: TabManager, isEnabled: Bool, @ViewBuilder page: @escaping (ProfileSidebarPage) -> Page) {
        self.tabManager = tabManager
        self.transition = tabManager.profileTransition
        self.isEnabled = isEnabled
        self.page = page
    }

    private var originIndex: Int { lanes.firstIndex { $0.id == transition.state.source } ?? 0 }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .topLeading) {
                ForEach(!transition.state.isActive || lanes.isEmpty ? [tabManager.activeSidebarPage] : lanes) { item in
                    page(item)
                        .frame(width: width, height: geometry.size.height)
                        .offset(x: reduceMotion ? 0 : laneOffset(item.id, width: width))
                        .opacity(reduceMotion && item.id != tabManager.activeProfileID ? 0 : 1)
                        .allowsHitTesting(!transition.state.isActive || lanes.isEmpty)
                        .accessibilityHidden(item.id != tabManager.activeProfileID)
                        .transition(lanes.isEmpty && swipeSelection != tabManager.activeProfileID ? .opacity : .identity)
                }
            }
            .clipped()
            .background {
                if isEnabled && tabManager.profiles.count > 1 {
                    HorizontalSwipeReader(
                        transition: transition,
                        onBegan: begin,
                        onChanged: { translation in transition.follow(translation, width: width) },
                        onEnded: { translation, velocity, cancelled in
                            transition.finish(translation, velocity: velocity, cancelled: cancelled,
                                              width: width, reduceMotion: reduceMotion) { destination in
                                swipeSelection = destination
                                tabManager.switchToProfile(destination)
                            }
                        }
                    )
                }
            }
            .animation(lanes.isEmpty && swipeSelection != tabManager.activeProfileID ? ChromeMotion.profileChange : nil,
                       value: tabManager.activeProfileID)
        }
        .onChange(of: transition.state.isActive) { _, active in
            if !active { lanes = [] }
        }
        .onChange(of: isEnabled) { _, enabled in
            if !enabled, !lanes.isEmpty { transition.reset(); lanes = [] }
        }
        .onDisappear {
            if !lanes.isEmpty { transition.reset() }
        }
    }

    private func laneOffset(_ id: UUID, width: CGFloat) -> CGFloat {
        guard transition.state.isActive, !lanes.isEmpty, let index = lanes.firstIndex(where: { $0.id == id }) else { return 0 }
        return (CGFloat(index - originIndex) + transition.state.position) * width
    }

    private func begin() {
        if lanes.isEmpty {
            lanes = [tabManager.adjacentProfile(-1).map(tabManager.sidebarPage),
                     tabManager.activeSidebarPage,
                     tabManager.adjacentProfile(1).map(tabManager.sidebarPage)].compactMap { $0 }
        }
        transition.begin(source: tabManager.activeProfileID,
                         previous: tabManager.adjacentProfile(-1)?.id,
                         next: tabManager.adjacentProfile(1)?.id)
    }
}

/// Locks an intentional horizontal gesture, leaving vertical scrolling alone.
/// Momentum after release belongs to the settle, not another profile change.
private struct HorizontalSwipeReader: NSViewRepresentable {
    let transition: ProfileTransition
    let onBegan: () -> Void
    let onChanged: (CGFloat) -> Void
    let onEnded: (CGFloat, CGFloat, Bool) -> Void

    func makeNSView(context: Context) -> SwipeView { SwipeView() }

    func updateNSView(_ view: SwipeView, context: Context) {
        view.transition = transition
        transition.attach(to: view)
        view.onBegan = onBegan
        view.onChanged = onChanged
        view.onEnded = onEnded
    }

    static func dismantleNSView(_ view: SwipeView, coordinator: ()) {
        view.transition?.detach(from: view)
        view.removeMonitor()
    }

    final class SwipeView: NSView {
        weak var transition: ProfileTransition?
        var onBegan: () -> Void = {}
        var onChanged: (CGFloat) -> Void = { _ in }
        var onEnded: (CGFloat, CGFloat, Bool) -> Void = { _, _, _ in }
        private enum Axis { case horizontal, vertical }
        private var monitor: Any?
        private var axis: Axis?
        private var translation: CGFloat = 0
        private var vertical: CGFloat = 0
        private var velocity: CGFloat = 0
        private var lastTime: TimeInterval = 0
        private var swallowsMomentum = false

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            removeMonitor()
            guard window != nil else { transition?.detach(from: self); return }
            transition?.attach(to: self)
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                nonisolated(unsafe) let event = event
                let consumed = MainActor.assumeIsolated { self?.consumes(event) ?? false }
                return consumed ? nil : event
            }
        }

        func removeMonitor() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }

        private func consumes(_ event: NSEvent) -> Bool {
            guard event.window === window else { return false }
            if !event.momentumPhase.isEmpty { return swallowsMomentum }
            switch event.phase {
            case .began:
                swallowsMomentum = false
                translation = 0
                vertical = 0
                velocity = 0
                lastTime = event.timestamp
                axis = bounds.contains(convert(event.locationInWindow, from: nil)) ? nil : .vertical
                return follow(event)
            case .changed:
                return follow(event)
            case .ended, .cancelled:
                defer { axis = nil }
                guard axis == .horizontal else { return false }
                swallowsMomentum = true
                onEnded(translation, event.timestamp - lastTime > 0.08 ? 0 : velocity, event.phase == .cancelled)
                return true
            default:
                return false
            }
        }

        private func follow(_ event: NSEvent) -> Bool {
            translation += event.scrollingDeltaX
            vertical += event.scrollingDeltaY
            if axis == nil {
                // Do not let one tiny diagonal event decide the entire gesture.
                guard max(abs(translation), abs(vertical)) >= 6 else { return false }
                axis = abs(translation) > abs(vertical) ? .horizontal : .vertical
                if axis == .horizontal { onBegan() }
            }
            guard axis == .horizontal else { return false }
            let dt = event.timestamp - lastTime
            if dt > 0, dt < 0.1 {
                velocity = velocity * 0.25 + event.scrollingDeltaX / dt * 0.75
            }
            lastTime = event.timestamp
            onChanged(translation)
            return true
        }
    }
}
