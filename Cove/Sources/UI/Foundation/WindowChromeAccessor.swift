import SwiftUI
import AppKit

struct WindowChromeAccessor: NSViewRepresentable {
    var isVisible: Bool
    var titlebarHeight: Binding<CGFloat>? = nil

    func makeNSView(context: Context) -> WindowChromeMeasureView {
        let view = WindowChromeMeasureView()
        view.isVisible = isVisible
        view.titlebarHeight = titlebarHeight
        return view
    }

    func updateNSView(_ nsView: WindowChromeMeasureView, context: Context) {
        nsView.isVisible = isVisible
        nsView.titlebarHeight = titlebarHeight
    }
}

final class WindowChromeMeasureView: NSView {
    var isVisible: Bool = true {
        didSet {
            guard oldValue != isVisible else { return }
            applyButtonVisibility(animated: true)
        }
    }

    var titlebarHeight: Binding<CGFloat>?

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
        measureTitlebar()
    }

    deinit {
        stopObservingWindow()
    }

    @objc
    private func windowDidChange(_ notification: Notification) {
        measureTitlebar()
    }

    private func bindWindowObservation() {
        guard observedWindow !== window else {
            measureTitlebar()
            applyButtonVisibility(animated: false)
            return
        }

        stopObservingWindow()
        observedWindow = window
        guard let window else { return }

        for name in [
            NSWindow.didResizeNotification,
            NSWindow.didEndLiveResizeNotification,
            NSWindow.didChangeScreenNotification
        ] {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidChange(_:)),
                name: name,
                object: window
            )
        }

        measureTitlebar()
        applyButtonVisibility(animated: false)
    }

    private func stopObservingWindow() {
        guard let observedWindow else { return }
        for name in [
            NSWindow.didResizeNotification,
            NSWindow.didEndLiveResizeNotification,
            NSWindow.didChangeScreenNotification
        ] {
            NotificationCenter.default.removeObserver(self, name: name, object: observedWindow)
        }
        self.observedWindow = nil
    }

    private func measureTitlebar() {
        guard let window, let titlebarHeight else { return }
        let resolved = max(0, window.frame.height - window.contentLayoutRect.height)
        guard titlebarHeight.wrappedValue != resolved else { return }
        DispatchQueue.main.async {
            self.titlebarHeight?.wrappedValue = resolved
        }
    }

    private func applyButtonVisibility(animated: Bool) {
        guard let window else { return }
        let targetAlpha: CGFloat = isVisible ? 1 : 0

        for type: NSWindow.ButtonType in [.closeButton, .miniaturizeButton, .zoomButton] {
            guard let button = window.standardWindowButton(type) else { continue }
            if animated {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.18
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    button.animator().alphaValue = targetAlpha
                }
            } else {
                button.alphaValue = targetAlpha
            }
        }
    }
}
