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

    func makeNSView(context: Context) -> WindowChromeTrackingView {
        let view = WindowChromeTrackingView()
        view.controlsStyle = controlsStyle
        return view
    }

    func updateNSView(_ nsView: WindowChromeTrackingView, context: Context) {
        nsView.controlsStyle = controlsStyle
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

    private weak var observedWindow: NSWindow?

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
        WindowChromeController.applyControls(to: window, style: controlsStyle, animated: animated)
    }
}

enum WindowChromeController {
    static func applyControls(to window: NSWindow, style: WindowChromeControlsStyle, animated: Bool) {
        let buttonTypes: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
        let buttons = buttonTypes.compactMap { window.standardWindowButton($0) }

        guard buttons.count == buttonTypes.count else { return }

        var nextX = style.leadingInset
        let baseY = buttons[0].frame.origin.y + style.verticalOffset
        let hiddenOffset: CGFloat = 10

        for button in buttons {
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

            nextX += button.frame.width + style.interButtonSpacing
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
