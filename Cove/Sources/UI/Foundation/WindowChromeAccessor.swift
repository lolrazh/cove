import SwiftUI
import AppKit

struct WindowChromeControlsStyle: Equatable {
    var leadingInset: CGFloat
    var interButtonSpacing: CGFloat
    var verticalOffset: CGFloat
    var isVisible: Bool
}

struct WindowChromeAccessor: NSViewRepresentable {
    let controlsStyle: WindowChromeControlsStyle
    var titlebarHeight: Binding<CGFloat>? = nil

    func makeNSView(context: Context) -> WindowChromeTrackingView {
        let view = WindowChromeTrackingView()
        view.controlsStyle = controlsStyle
        view.titlebarHeight = titlebarHeight
        return view
    }

    func updateNSView(_ nsView: WindowChromeTrackingView, context: Context) {
        nsView.controlsStyle = controlsStyle
        nsView.titlebarHeight = titlebarHeight
    }
}

final class WindowChromeTrackingView: NSView {
    var controlsStyle = WindowChromeControlsStyle(
        leadingInset: ChromeMetrics.shellControlsLeadingInset,
        interButtonSpacing: ChromeMetrics.shellControlsInterButtonSpacing,
        verticalOffset: ChromeMetrics.shellControlsVerticalOffset,
        isVisible: true
    ) {
        didSet {
            let shouldAnimate = oldValue != controlsStyle
            applyControlsIfPossible(animated: shouldAnimate)
        }
    }

    var titlebarHeight: Binding<CGFloat>?

    private weak var observedWindow: NSWindow?
    private var buttonMetrics: WindowChromeButtonMetrics?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        bindWindowObservation()
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        bindWindowObservation()
    }

    override func layout() {
        super.layout()
        applyControlsIfPossible(animated: false)
    }

    deinit {
        stopObservingWindow()
    }

    @objc
    private func windowFrameDidChange(_ notification: Notification) {
        applyControlsIfPossible(animated: false)
    }

    private func bindWindowObservation() {
        guard observedWindow !== window else {
            applyControlsIfPossible(animated: false)
            return
        }

        stopObservingWindow()
        observedWindow = window
        buttonMetrics = nil

        guard let window else { return }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowFrameDidChange(_:)),
            name: NSWindow.didResizeNotification,
            object: window
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowFrameDidChange(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: window
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowFrameDidChange(_:)),
            name: NSWindow.didEndLiveResizeNotification,
            object: window
        )

        applyControlsIfPossible(animated: false)
    }

    private func stopObservingWindow() {
        guard let observedWindow else { return }
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResizeNotification, object: observedWindow)
        NotificationCenter.default.removeObserver(self, name: NSWindow.didBecomeKeyNotification, object: observedWindow)
        NotificationCenter.default.removeObserver(self, name: NSWindow.didEndLiveResizeNotification, object: observedWindow)
        self.observedWindow = nil
    }

    private func applyControlsIfPossible(animated: Bool) {
        guard let window else { return }
        reportTitlebarHeight(for: window)
        captureButtonMetricsIfNeeded(for: window)

        guard let buttonMetrics else { return }

        WindowChromeController.applyControls(
            to: window,
            style: controlsStyle,
            metrics: buttonMetrics,
            animated: animated
        )
    }

    private func captureButtonMetricsIfNeeded(for window: NSWindow) {
        guard buttonMetrics == nil else { return }

        let buttonTypes: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
        let buttons = buttonTypes.compactMap { window.standardWindowButton($0) }

        guard buttons.count == buttonTypes.count else { return }

        buttonMetrics = WindowChromeButtonMetrics(
            baseY: buttons[0].frame.origin.y,
            widths: buttons.map { $0.frame.width }
        )
    }

    private func reportTitlebarHeight(for window: NSWindow) {
        guard let titlebarHeight else { return }

        let resolvedHeight = max(0, window.frame.height - window.contentLayoutRect.height)
        guard titlebarHeight.wrappedValue != resolvedHeight else { return }

        DispatchQueue.main.async {
            self.titlebarHeight?.wrappedValue = resolvedHeight
        }
    }
}

struct WindowChromeButtonMetrics {
    let baseY: CGFloat
    let widths: [CGFloat]
}

enum WindowChromeController {
    static func applyControls(
        to window: NSWindow,
        style: WindowChromeControlsStyle,
        metrics: WindowChromeButtonMetrics,
        animated: Bool
    ) {
        let buttonTypes: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
        let buttons = buttonTypes.compactMap { window.standardWindowButton($0) }

        guard buttons.count == buttonTypes.count else { return }

        var nextX = style.leadingInset
        let baseY = metrics.baseY + style.verticalOffset
        let hiddenOffset: CGFloat = 10

        for (index, button) in buttons.enumerated() {
            let visibleOrigin = CGPoint(
                x: round(nextX),
                y: round(baseY)
            )
            let hiddenOrigin = CGPoint(
                x: round(nextX),
                y: round(baseY + hiddenOffset)
            )

            if style.isVisible {
                show(button: button, at: visibleOrigin, animated: animated)
            } else {
                hide(button: button, at: hiddenOrigin, animated: animated)
            }

            nextX += metrics.widths[index] + style.interButtonSpacing
        }
    }

    private static func show(button: NSButton, at origin: CGPoint, animated: Bool) {
        if animated {
            if button.isHidden {
                button.alphaValue = 0
                button.isHidden = false
                button.setFrameOrigin(CGPoint(x: origin.x, y: origin.y + 10))
            }

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                button.animator().alphaValue = 1
                button.animator().setFrameOrigin(origin)
            }
        } else {
            button.isHidden = false
            button.alphaValue = 1
            button.setFrameOrigin(origin)
        }
    }

    private static func hide(button: NSButton, at origin: CGPoint, animated: Bool) {
        guard !button.isHidden else {
            button.setFrameOrigin(origin)
            return
        }

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                button.animator().alphaValue = 0
                button.animator().setFrameOrigin(origin)
            } completionHandler: {
                button.isHidden = true
            }
        } else {
            button.alphaValue = 0
            button.setFrameOrigin(origin)
            button.isHidden = true
        }
    }
}
