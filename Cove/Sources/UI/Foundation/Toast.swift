import SwiftUI

/// A short confirmation over the page, like "Copied URL". One window shows one
/// at a time; a new toast replaces the last and restarts its clock.
@MainActor
final class ToastCenter: ObservableObject {
    struct Toast: Equatable {
        let message: String
        let symbol: String
    }

    @Published private(set) var current: Toast?
    private var dismissal: Task<Void, Never>?

    func show(_ message: String, symbol: String) {
        current = Toast(message: message, symbol: symbol)
        dismissal?.cancel()
        dismissal = Task {
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            current = nil
        }
    }
}

/// Shows the center's toast as a capsule at the top of whatever it overlays.
struct ToastOverlay: View {
    @ObservedObject var center: ToastCenter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack {
            if let toast = center.current {
                Label(toast.message, systemImage: toast.symbol)
                    .font(.callout.weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background {
                        Capsule()
                            .fill(.regularMaterial)
                            .chromeShadow(.floating)
                    }
                    .transition(transition)
            }
        }
        .padding(.top, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(reduceMotion ? ChromeMotion.fade : ChromeMotion.appear, value: center.current)
        .allowsHitTesting(false)
    }

    private var transition: AnyTransition {
        reduceMotion ? .opacity : .scale(scale: 0.9, anchor: .top).combined(with: .opacity)
    }
}
