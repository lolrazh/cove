import SwiftUI
import AppKit

struct WindowChromeControlsStyle: Equatable {
    var leadingInset: CGFloat
    var interButtonSpacing: CGFloat
    var verticalOffset: CGFloat
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
        verticalOffset: ChromeMetrics.shellControlsVerticalOffset
    ) {
        didSet {
            applyControlsIfPossible()
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
        applyControlsIfPossible()
    }

    deinit {
        stopObservingWindow()
    }

    @objc
    private func windowFrameDidChange(_ notification: Notification) {
        applyControlsIfPossible()
    }

    private func bindWindowObservation() {
        guard observedWindow !== window else {
            applyControlsIfPossible()
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

        applyControlsIfPossible()
    }

    private func stopObservingWindow() {
        guard let observedWindow else { return }
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResizeNotification, object: observedWindow)
        NotificationCenter.default.removeObserver(self, name: NSWindow.didBecomeKeyNotification, object: observedWindow)
        NotificationCenter.default.removeObserver(self, name: NSWindow.didEndLiveResizeNotification, object: observedWindow)
        self.observedWindow = nil
    }

    private func applyControlsIfPossible() {
        guard let window else { return }
        WindowChromeController.applyControls(to: window, style: controlsStyle)
    }
}

enum WindowChromeController {
    static func applyControls(to window: NSWindow, style: WindowChromeControlsStyle) {
        let buttonTypes: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
        let buttons = buttonTypes.compactMap { window.standardWindowButton($0) }

        guard buttons.count == buttonTypes.count else { return }

        var nextX = style.leadingInset
        let baseY = buttons[0].frame.origin.y + style.verticalOffset

        for button in buttons {
            button.setFrameOrigin(
                CGPoint(
                    x: round(nextX),
                    y: round(baseY)
                )
            )

            nextX += button.frame.width + style.interButtonSpacing
        }
    }
}
