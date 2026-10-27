import SwiftUI

extension View {
    /// Pages between spaces with a two-finger horizontal swipe, as in Arc:
    /// the page follows the fingers, resists where there's no space to go to,
    /// and a swipe past `threshold` switches. Under Reduce Motion the page
    /// stays put and the switch crossfades.
    func spacePaging(_ tabManager: TabManager) -> some View {
        modifier(SpacePaging(tabManager: tabManager))
    }

    /// Each space's tabs as a page of their own: the next space slides in from
    /// the side it lies on.
    func spacePage(_ tabManager: TabManager) -> some View {
        modifier(SpacePage(tabManager: tabManager))
    }
}

private struct SpacePage: ViewModifier {
    @ObservedObject var tabManager: TabManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        ZStack {
            content
                .id(tabManager.activeSpaceID)
                .transition(transition)
        }
        .clipped()
    }

    private var transition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let forward = tabManager.spacePagingDirection > 0
        return .asymmetric(
            insertion: .move(edge: forward ? .trailing : .leading),
            removal: .move(edge: forward ? .leading : .trailing)
        )
    }
}

private struct SpacePaging: ViewModifier {
    @ObservedObject var tabManager: TabManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset: CGFloat = 0

    /// How far a swipe goes before it switches.
    private let threshold: CGFloat = 60
    /// How much of the swipe the page follows with nowhere to go.
    private let resistance: CGFloat = 0.2

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .background {
                HorizontalSwipeReader(onChanged: follow, onEnded: finish)
            }
            .onChange(of: tabManager.activeSpaceID) {
                withAnimation(ChromeMotion.page) { offset = 0 }
            }
    }

    /// Fingers moving left bring the next space, as content follows them.
    private func direction(of translation: CGFloat) -> Int {
        translation < 0 ? 1 : -1
    }

    private func follow(_ translation: CGFloat) {
        guard !reduceMotion else { return }
        let canMove = tabManager.adjacentSpace(direction(of: translation)) != nil
        offset = canMove ? translation : translation * resistance
    }

    private func finish(_ translation: CGFloat) {
        let direction = direction(of: translation)
        if abs(translation) > threshold, tabManager.adjacentSpace(direction) != nil {
            tabManager.switchToAdjacentSpace(direction)
        } else {
            withAnimation(ChromeMotion.page) { offset = 0 }
        }
    }
}

/// Reports two-finger horizontal scrolls over its area, and keeps them from
/// the views underneath; vertical scrolls pass through to the scroll view as
/// usual. SwiftUI has no gesture for trackpad scrolling, so this watches the
/// window's scroll events while it's in one.
private struct HorizontalSwipeReader: NSViewRepresentable {
    let onChanged: (CGFloat) -> Void
    let onEnded: (CGFloat) -> Void

    func makeNSView(context: Context) -> SwipeView {
        SwipeView()
    }

    func updateNSView(_ view: SwipeView, context: Context) {
        view.onChanged = onChanged
        view.onEnded = onEnded
    }

    final class SwipeView: NSView {
        var onChanged: (CGFloat) -> Void = { _ in }
        var onEnded: (CGFloat) -> Void = { _ in }

        private enum Axis { case horizontal, vertical }

        private var monitor: Any?
        /// Decided by the first few points of movement in each gesture.
        private var axis: Axis?
        private var translation: CGFloat = 0
        /// Swallows the momentum after a horizontal swipe.
        private var swallowsMomentum = false

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            guard window != nil else { return }
            // Local monitors run on the main thread.
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                nonisolated(unsafe) let event = event
                let isSwipe = MainActor.assumeIsolated { self?.consumes(event) ?? false }
                return isSwipe ? nil : event
            }
        }

        /// Whether the event is part of a horizontal swipe over this view.
        private func consumes(_ event: NSEvent) -> Bool {
            guard event.window === window else { return false }

            if !event.momentumPhase.isEmpty {
                return swallowsMomentum
            }

            switch event.phase {
            case .began:
                guard bounds.contains(convert(event.locationInWindow, from: nil)) else {
                    axis = .vertical
                    return false
                }
                axis = nil
                translation = 0
                swallowsMomentum = false
                return follow(event)
            case .changed:
                return follow(event)
            case .ended, .cancelled:
                defer { axis = nil }
                guard axis == .horizontal else { return false }
                swallowsMomentum = true
                onEnded(translation)
                return true
            default:
                return false
            }
        }

        private func follow(_ event: NSEvent) -> Bool {
            if axis == nil {
                let dx = abs(event.scrollingDeltaX), dy = abs(event.scrollingDeltaY)
                guard dx + dy > 0 else { return false }
                axis = dx > dy ? .horizontal : .vertical
            }
            guard axis == .horizontal else { return false }
            translation += event.scrollingDeltaX
            onChanged(translation)
            return true
        }
    }
}
