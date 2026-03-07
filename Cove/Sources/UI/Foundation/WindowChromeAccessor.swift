import SwiftUI
import AppKit

@MainActor
struct WindowChromeAccessor: NSViewRepresentable {
    @ObservedObject var tabManager: TabManager
    var isVisible: Bool
    var titlebarHeight: Binding<CGFloat>? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WindowChromeTrackingView {
        let view = WindowChromeTrackingView()
        view.coordinator = context.coordinator
        context.coordinator.tabManager = tabManager
        context.coordinator.isVisible = isVisible
        context.coordinator.titlebarHeight = titlebarHeight
        return view
    }

    func updateNSView(_ nsView: WindowChromeTrackingView, context: Context) {
        nsView.coordinator = context.coordinator
        context.coordinator.tabManager = tabManager
        context.coordinator.isVisible = isVisible
        context.coordinator.titlebarHeight = titlebarHeight
        context.coordinator.attach(to: nsView.window)
        context.coordinator.updateWindowChrome()
    }

    static func dismantleNSView(_ nsView: WindowChromeTrackingView, coordinator: Coordinator) {
        coordinator.detach()
        nsView.coordinator = nil
    }

    @MainActor
    final class Coordinator: NSObject {
        private let windowToolbarIdentifier = NSToolbar.Identifier("CoveWindowToolbar")

        weak var window: NSWindow?
        weak var tabManager: TabManager?
        var isVisible = true
        var titlebarHeight: Binding<CGFloat>?

        private let accessoryController = NSTitlebarAccessoryViewController()
        private let hostingView = NSHostingView(rootView: AnyView(EmptyView()))
        private weak var observedWindow: NSWindow?
        private var lastTrafficLightVisibility: Bool?

        override init() {
            super.init()
            accessoryController.layoutAttribute = .left
            accessoryController.fullScreenMinHeight = ChromeMetrics.topBandHeight
            hostingView.wantsLayer = true
            hostingView.layer?.backgroundColor = .clear
            accessoryController.view = hostingView
        }

        func attach(to window: NSWindow?) {
            guard self.window !== window else {
                updateWindowChrome()
                return
            }

            removeObservers()
            uninstallAccessory()
            lastTrafficLightVisibility = nil
            self.window = window

            guard let window else { return }

            configureWindow(window)
            installAccessoryIfNeeded(on: window)
            installObservers(for: window)
            updateWindowChrome()
        }

        func detach() {
            removeObservers()
            uninstallAccessory()
            lastTrafficLightVisibility = nil
            window = nil
        }

        func updateWindowChrome() {
            guard let window else { return }

            measureTitlebar()
            applyButtonVisibilityIfNeeded()
            updateAccessory(in: window)
        }

        private func configureWindow(_ window: NSWindow) {
            window.tabbingMode = .disallowed
            window.styleMask.insert(.fullSizeContentView)
            window.styleMask.insert(.unifiedTitleAndToolbar)
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.titlebarSeparatorStyle = .none
            window.isOpaque = true
            window.backgroundColor = .windowBackgroundColor
            installWindowToolbarIfNeeded(on: window)
            window.toolbarStyle = .unifiedCompact
        }

        private func installWindowToolbarIfNeeded(on window: NSWindow) {
            if let toolbar = window.toolbar, toolbar.identifier == windowToolbarIdentifier {
                toolbar.displayMode = .iconOnly
                toolbar.allowsUserCustomization = false
                toolbar.autosavesConfiguration = false
                toolbar.isVisible = true
                return
            }

            let toolbar = NSToolbar(identifier: windowToolbarIdentifier)
            toolbar.displayMode = .iconOnly
            toolbar.allowsUserCustomization = false
            toolbar.autosavesConfiguration = false
            window.toolbar = toolbar
        }

        private func installAccessoryIfNeeded(on window: NSWindow) {
            let isInstalled = window.titlebarAccessoryViewControllers.contains { controller in
                controller === accessoryController
            }

            if !isInstalled {
                window.addTitlebarAccessoryViewController(accessoryController)
            }
        }

        private func uninstallAccessory() {
            guard let window else { return }
            guard let index = window.titlebarAccessoryViewControllers.firstIndex(where: { controller in
                controller === accessoryController
            }) else { return }

            window.titlebarAccessoryViewControllers.remove(at: index)
        }

        private func updateAccessory(in window: NSWindow) {
            installAccessoryIfNeeded(on: window)

            let accessoryWidth = resolvedAccessoryWidth(for: window)
            let showsTopStrip = tabManager?.tabLayout == .horizontal && isVisible
            if let tabManager, showsTopStrip {
                hostingView.rootView = AnyView(
                    TitlebarTabStripContent(
                        tabManager: tabManager,
                        width: accessoryWidth
                    )
                )
            } else {
                hostingView.rootView = AnyView(Color.clear)
            }

            hostingView.frame = CGRect(
                x: 0,
                y: 0,
                width: accessoryWidth,
                height: ChromeMetrics.topBandHeight
            )
        }

        private func installObservers(for window: NSWindow) {
            observedWindow = window
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
        }

        private func removeObservers() {
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

        private func resolvedAccessoryWidth(for window: NSWindow) -> CGFloat {
            let horizontalChrome = (ChromeMetrics.windowInset * 2) + ChromeMetrics.shellGutter
            let leadingReservation = ChromeMetrics.shellControlsReservedWidth
            let trailingAllowance: CGFloat = 28
            let width = window.frame.width - horizontalChrome - leadingReservation - trailingAllowance
            return max(320, width)
        }

        @objc
        private func windowDidChange(_ notification: Notification) {
            updateWindowChrome()
        }

        private func measureTitlebar() {
            guard let window, let titlebarHeight else { return }
            let resolved = max(0, window.frame.height - window.contentLayoutRect.height)
            guard titlebarHeight.wrappedValue != resolved else { return }
            DispatchQueue.main.async { [weak self] in
                self?.titlebarHeight?.wrappedValue = resolved
            }
        }

        private func applyButtonVisibilityIfNeeded() {
            let animated = lastTrafficLightVisibility != nil && lastTrafficLightVisibility != isVisible
            applyButtonVisibility(animated: animated)
            lastTrafficLightVisibility = isVisible
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
}

final class WindowChromeTrackingView: NSView {
    weak var coordinator: WindowChromeAccessor.Coordinator?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        attachToWindowIfNeeded()
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        attachToWindowIfNeeded()
    }

    private func attachToWindowIfNeeded() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.coordinator?.attach(to: self.window)
        }
    }
}

private struct TitlebarTabStripContent: View {
    @ObservedObject var tabManager: TabManager
    let width: CGFloat

    var body: some View {
        TabStripView(
            tabManager: tabManager,
            laneHeight: ChromeMetrics.topStripLaneHeight
        )
        .padding(.leading, ChromeMetrics.shellControlsGapToTabs + ChromeMetrics.shellControlsEdgeBalanceInset)
        .padding(.trailing, ChromeMetrics.shellGutter)
        .frame(width: width, height: ChromeMetrics.topBandHeight, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.clear)
    }
}
