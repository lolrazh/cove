import SwiftUI
import AppKit

/// Hosts the browser shell edge to edge, under a transparent compact titlebar,
/// and tells it where the native traffic lights ended up.
///
/// The traffic lights are never moved. macOS centers them in the compact titlebar
/// and the shell lays its tabs out around them. Moving them fights AppKit's
/// titlebar layout, which re-places them on resize, activation and full screen.
struct WindowChromeHost<Content: View>: View {
    let showsTrafficLights: Bool
    let content: Content

    @State private var trafficLightInset: CGFloat = 0

    init(showsTrafficLights: Bool, @ViewBuilder content: () -> Content) {
        self.showsTrafficLights = showsTrafficLights
        self.content = content()
    }

    var body: some View {
        content
            .environment(\.trafficLightInset, trafficLightInset)
            .ignoresSafeArea()
            .background {
                WindowChromeAccessor(
                    showsTrafficLights: showsTrafficLights,
                    trafficLightInset: $trafficLightInset
                )
                .allowsHitTesting(false)
            }
    }
}

extension NSToolbar.Identifier {
    /// Every browser window carries this toolbar, which is how other windows
    /// (like History) find one.
    static let browserWindow = NSToolbar.Identifier("CoveWindowToolbar")
}

extension NSApplication {
    var frontmostBrowserWindow: NSWindow? {
        orderedWindows.first { $0.toolbar?.identifier == .browserWindow }
    }
}

extension EnvironmentValues {
    /// Distance from the window's leading edge to just past the zoom button.
    /// Zero in full screen, where macOS hides the traffic lights.
    @Entry var trafficLightInset: CGFloat = 0
}

private struct WindowChromeAccessor: NSViewRepresentable {
    let showsTrafficLights: Bool
    @Binding var trafficLightInset: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WindowTrackingView {
        let view = WindowTrackingView()
        view.onWindowChange = { [coordinator = context.coordinator] window in
            coordinator.attach(to: window)
        }
        return view
    }

    func updateNSView(_ nsView: WindowTrackingView, context: Context) {
        let coordinator = context.coordinator
        let binding = $trafficLightInset
        coordinator.onInsetChange = { inset in
            // Never write SwiftUI state from inside a view update.
            DispatchQueue.main.async {
                if binding.wrappedValue != inset {
                    binding.wrappedValue = inset
                }
            }
        }
        coordinator.setTrafficLightsVisible(showsTrafficLights)
        coordinator.publishInset()
    }

    static func dismantleNSView(_ nsView: WindowTrackingView, coordinator: Coordinator) {
        coordinator.attach(to: nil)
    }

    @MainActor
    final class Coordinator: NSObject {
        var onInsetChange: ((CGFloat) -> Void)?

        private weak var window: NSWindow?
        private var trafficLightsVisible = true
        private let observedNotifications: [Notification.Name] = [
            NSWindow.didResizeNotification,
            NSWindow.didEnterFullScreenNotification,
            NSWindow.didExitFullScreenNotification,
            NSWindow.didChangeScreenNotification,
        ]

        func attach(to newWindow: NSWindow?) {
            guard window !== newWindow else { return }

            if let window {
                for name in observedNotifications {
                    NotificationCenter.default.removeObserver(self, name: name, object: window)
                }
            }

            window = newWindow
            guard let newWindow else { return }

            configure(newWindow)
            for name in observedNotifications {
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(windowGeometryChanged),
                    name: name,
                    object: newWindow
                )
            }
            applyTrafficLightVisibility(animated: false)
            publishInset()
        }

        func setTrafficLightsVisible(_ visible: Bool) {
            guard trafficLightsVisible != visible else { return }
            trafficLightsVisible = visible
            applyTrafficLightVisibility(animated: true)
        }

        private func configure(_ window: NSWindow) {
            window.tabbingMode = .disallowed
            window.styleMask.insert(.fullSizeContentView)
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.titlebarSeparatorStyle = .none
            window.isMovableByWindowBackground = true

            // An empty toolbar is what makes the titlebar compact-height, which is
            // what puts the traffic lights on the tab row's centerline.
            if window.toolbar == nil {
                let toolbar = NSToolbar(identifier: .browserWindow)
                toolbar.allowsUserCustomization = false
                toolbar.autosavesConfiguration = false
                window.toolbar = toolbar
            }
            window.toolbarStyle = .unifiedCompact
        }

        private var trafficLights: [NSButton] {
            guard let window else { return [] }
            return [.closeButton, .miniaturizeButton, .zoomButton].compactMap {
                window.standardWindowButton($0)
            }
        }

        /// Hidden buttons would still take clicks, and they sit right where the
        /// content card's back button is once the tabs are hidden. So after fading
        /// out they are also hidden for real.
        private func applyTrafficLightVisibility(animated: Bool) {
            let visible = trafficLightsVisible
            let buttons = trafficLights

            if visible {
                buttons.forEach { $0.isHidden = false }
            }

            guard animated else {
                buttons.forEach {
                    $0.alphaValue = visible ? 1 : 0
                    $0.isHidden = !visible
                }
                return
            }

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                buttons.forEach { $0.animator().alphaValue = visible ? 1 : 0 }
            } completionHandler: { [weak self] in
                MainActor.assumeIsolated {
                    guard let self, !self.trafficLightsVisible else { return }
                    self.trafficLights.forEach { $0.isHidden = true }
                }
            }
        }

        @objc private func windowGeometryChanged() {
            publishInset()
        }

        func publishInset() {
            guard let window else { return }
            let inset: CGFloat
            if window.styleMask.contains(.fullScreen) {
                inset = 0
            } else if let zoom = window.standardWindowButton(.zoomButton) {
                inset = zoom.convert(zoom.bounds, to: nil).maxX
            } else {
                inset = 0
            }
            onInsetChange?(inset)
        }
    }
}

private final class WindowTrackingView: NSView {
    var onWindowChange: ((NSWindow?) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onWindowChange?(window)
    }
}
