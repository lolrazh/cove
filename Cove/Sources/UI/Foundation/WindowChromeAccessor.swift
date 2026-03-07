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
            guard oldValue != controlsStyle else { return }
            applyControlsIfPossible(animated: true, force: true)
        }
    }

    var titlebarHeight: Binding<CGFloat>?

    private weak var observedWindow: NSWindow?
    private var lastAppliedStyle: WindowChromeControlsStyle?
    private var lastAppliedTitlebarHeight: CGFloat?

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
        applyControlsIfPossible(animated: false, force: false)
    }

    deinit {
        stopObservingWindow()
    }

    @objc
    private func windowFrameDidChange(_ notification: Notification) {
        applyControlsIfPossible(animated: false, force: true)
    }

    private func bindWindowObservation() {
        guard observedWindow !== window else {
            applyControlsIfPossible(animated: false, force: true)
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

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowFrameDidChange(_:)),
            name: NSWindow.didChangeScreenNotification,
            object: window
        )

        applyControlsIfPossible(animated: false, force: true)
    }

    private func stopObservingWindow() {
        guard let observedWindow else { return }
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResizeNotification, object: observedWindow)
        NotificationCenter.default.removeObserver(self, name: NSWindow.didBecomeKeyNotification, object: observedWindow)
        NotificationCenter.default.removeObserver(self, name: NSWindow.didEndLiveResizeNotification, object: observedWindow)
        NotificationCenter.default.removeObserver(self, name: NSWindow.didChangeScreenNotification, object: observedWindow)
        self.observedWindow = nil
    }

    private func applyControlsIfPossible(animated: Bool, force: Bool) {
        guard let window else { return }
        let buttonTypes: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
        let buttons = buttonTypes.compactMap { window.standardWindowButton($0) }

        let resolvedTitlebarHeight = resolvedTitlebarHeight(for: window, buttons: buttons)
        reportTitlebarHeight(resolvedTitlebarHeight)

        if !force,
           lastAppliedStyle == controlsStyle,
           lastAppliedTitlebarHeight == resolvedTitlebarHeight {
            return
        }

        lastAppliedStyle = controlsStyle
        lastAppliedTitlebarHeight = resolvedTitlebarHeight

        WindowChromeController.applyControls(
            buttons: buttons,
            style: controlsStyle,
            titlebarHeight: resolvedTitlebarHeight,
            animated: animated
        )
    }

    private func resolvedTitlebarHeight(for window: NSWindow, buttons: [NSButton]) -> CGFloat {
        if let containerHeight = buttons.first?.superview?.bounds.height, containerHeight > 0 {
            return containerHeight
        }

        return max(0, window.frame.height - window.contentLayoutRect.height)
    }

    private func reportTitlebarHeight(_ resolvedHeight: CGFloat) {
        guard let titlebarHeight else { return }
        guard titlebarHeight.wrappedValue != resolvedHeight else { return }

        DispatchQueue.main.async {
            self.titlebarHeight?.wrappedValue = resolvedHeight
        }
    }
}

enum WindowChromeController {
    static func applyControls(
        buttons: [NSButton],
        style: WindowChromeControlsStyle,
        titlebarHeight: CGFloat,
        animated: Bool
    ) {
        guard buttons.count == 3 else { return }
        var nextX = style.leadingInset
        let buttonHeight = buttons[0].frame.height
        let baseY = resolvedBaseY(
            style: style,
            titlebarHeight: titlebarHeight,
            buttonHeight: buttonHeight
        )
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

    private static func resolvedBaseY(
        style: WindowChromeControlsStyle,
        titlebarHeight: CGFloat,
        buttonHeight: CGFloat
    ) -> CGFloat {
        max(0, (titlebarHeight - buttonHeight) / 2) + style.verticalOffset
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
