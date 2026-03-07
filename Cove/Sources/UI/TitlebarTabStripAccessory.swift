import SwiftUI
import AppKit

@MainActor
struct TitlebarTabStripAccessory: NSViewRepresentable {
    @ObservedObject var tabManager: TabManager
    let isVisible: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> TitlebarAccessoryTrackingView {
        let view = TitlebarAccessoryTrackingView()
        view.coordinator = context.coordinator
        context.coordinator.tabManager = tabManager
        context.coordinator.isVisible = isVisible
        return view
    }

    func updateNSView(_ nsView: TitlebarAccessoryTrackingView, context: Context) {
        nsView.coordinator = context.coordinator
        context.coordinator.tabManager = tabManager
        context.coordinator.isVisible = isVisible
        context.coordinator.attach(to: nsView.window)
        context.coordinator.updateAccessory()
    }

    static func dismantleNSView(_ nsView: TitlebarAccessoryTrackingView, coordinator: Coordinator) {
        coordinator.detach()
        nsView.coordinator = nil
    }

    @MainActor
    final class Coordinator: NSObject {
        weak var window: NSWindow?
        weak var tabManager: TabManager?
        var isVisible = false

        private let accessoryController = NSTitlebarAccessoryViewController()
        private let hostingView = NSHostingView(rootView: AnyView(EmptyView()))
        private weak var observedWindow: NSWindow?

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
                updateAccessory()
                return
            }

            removeObservers()
            uninstallAccessory()
            self.window = window

            guard let window else { return }

            installAccessoryIfNeeded(on: window)
            installObservers(for: window)
            updateAccessory()
        }

        func detach() {
            removeObservers()
            uninstallAccessory()
            window = nil
        }

        func updateAccessory() {
            guard let window else { return }

            installAccessoryIfNeeded(on: window)

            let accessoryWidth = resolvedAccessoryWidth(for: window)
            if let tabManager, isVisible {
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

        private func installObservers(for window: NSWindow) {
            observedWindow = window
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidResize(_:)),
                name: NSWindow.didResizeNotification,
                object: window
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidResize(_:)),
                name: NSWindow.didEndLiveResizeNotification,
                object: window
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidResize(_:)),
                name: NSWindow.didChangeScreenNotification,
                object: window
            )
        }

        private func removeObservers() {
            guard let observedWindow else { return }
            NotificationCenter.default.removeObserver(
                self,
                name: NSWindow.didResizeNotification,
                object: observedWindow
            )
            NotificationCenter.default.removeObserver(
                self,
                name: NSWindow.didEndLiveResizeNotification,
                object: observedWindow
            )
            NotificationCenter.default.removeObserver(
                self,
                name: NSWindow.didChangeScreenNotification,
                object: observedWindow
            )
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
        private func windowDidResize(_ notification: Notification) {
            updateAccessory()
        }
    }
}

final class TitlebarAccessoryTrackingView: NSView {
    weak var coordinator: TitlebarTabStripAccessory.Coordinator?

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
        .padding(.leading, ChromeMetrics.shellControlsLeadingInset + ChromeMetrics.shellControlsClusterWidth + ChromeMetrics.shellControlsGapToTabs)
        .padding(.trailing, ChromeMetrics.shellGutter)
        .frame(width: width, height: ChromeMetrics.topBandHeight, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.clear)
    }
}
