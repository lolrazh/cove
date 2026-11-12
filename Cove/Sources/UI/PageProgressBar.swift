import SwiftUI

/// Actual page progress, with soft theme-colored light emitted from the thin line itself.
/// Main windows place this inside the address field. Standalone pages and
/// unfocused split panes retain a line at their page edge.
struct PageProgressBar: View {
    let progress: Double
    let isLoading: Bool
    var inAddressField = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.chromeTheme) private var theme
    @State private var shownProgress: Double = 0
    @State private var isVisible = false
    @State private var wasLoading = false

    private var tint: Color { theme.tint ?? Color(red: 0.16, green: 0.46, blue: 0.96) }

    private struct LoadState: Equatable {
        let progress: Double
        let isLoading: Bool
    }

    private var loadState: LoadState {
        LoadState(progress: progress.isFinite ? min(max(progress, 0), 1) : 0, isLoading: isLoading)
    }

    var body: some View {
        LoadingTrack(tint: tint, progress: shownProgress, showsGlow: inAddressField)
            .frame(height: inAddressField ? ChromeMetrics.addressFieldHeight : ChromeMetrics.progressHeight)
            .opacity(isVisible ? 1 : 0)
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Loading page")
            .accessibilityValue(Text(loadState.progress, format: .percent.precision(.fractionLength(0))))
            .accessibilityHidden(!isLoading)
            // A new update cancels the previous completion delay. An old load must
            // never fade out the indicator for a newer navigation.
            .task(id: loadState) {
                let state = loadState
                let startsLoad = state.isLoading && !wasLoading
                wasLoading = state.isLoading
                let advances = state.progress > shownProgress && !startsLoad
                withAnimation(advances && !reduceMotion ? ChromeMotion.progress : nil) {
                    shownProgress = state.progress
                }
                if state.isLoading {
                    withAnimation(nil) { isVisible = true }
                } else {
                    // Only a completed load reaches 100%; stop and failure do not.
                    do {
                        if state.progress == 1 && !reduceMotion {
                            try await Task.sleep(for: .milliseconds(200))
                        }
                        try Task.checkCancellation()
                        withAnimation(reduceMotion ? nil : ChromeMotion.fade) { isVisible = false }
                    } catch { /* Superseded by a new load or removed from the view. */ }
                }
            }
    }
}

/// Chosen in Glow Lab. The upward spread is slightly higher than the selected
/// 31-point preview; the soft tip shape and other light values are unchanged.
private enum LoadingLight {
    static let upwardSpread = 34.0
    static let strength = 0.19
    static let rightSpread = 8.26
    static let base = 0.45
    static let curve = 1.4
    static let lineStrength = 0.9
}

// The emitter ends at progress. A small diffuse blur wraps around its tip,
// then widens gently with height. The rounded spread balances a constant-width
// tail and a sharp fan. The address surface clips the whole light field.
private struct LoadingTrack: View, Animatable {
    let tint: Color
    nonisolated var progress: Double
    let showsGlow: Bool
    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    /// Integral of a normalized Gaussian over the finite emitting segment.
    /// Outside the source this decreases monotonically; no new source appears.
    private func coverage(at x: Double, end: Double, sigma: Double) -> Double {
        let scale = max(0.15, sigma) * sqrt(2)
        return max(0, 0.5 * (erf(x / scale) - erf((x - end) / scale)))
    }

    var body: some View {
        Canvas { context, size in
            guard progress > 0, size.width > 0 else { return }
            let end = size.width * min(1, max(0, progress))
            let verticalSigma = LoadingLight.upwardSpread / 2.5
            if showsGlow {
                // Half-point rows retain a smooth falloff at Retina scale.
                for row in 0..<Int(ceil(size.height * 2)) {
                    let y = Double(row) / 2
                    let height = max(0, size.height - y - 0.25 - ChromeMetrics.progressHeight / 2)
                    let broad = LoadingLight.strength * exp(-0.5 * pow(height / verticalSigma, 2))
                    let close = 0.13 * exp(-0.5 * pow(height / 2.2, 2))
                    // A small base radius rounds the tip instead of pinching it to
                    // a wedge. The height term is gentler than the previous fan.
                    let broadSigma = max(0.15, LoadingLight.rightSpread * hypot(0.6, 0.55 * height / verticalSigma))
                    let closeSigma = max(0.15, min(1.5, LoadingLight.rightSpread / 6) * hypot(0.6, 0.4 * height / 2.2))
                    let extent = min(size.width, end + max(broadSigma, closeSigma) * 4)
                    // Sample the body and both ends, including the narrow close halo.
                    // Dense endpoint stops avoid a polygon edge as the fan opens.
                    var positions = (0...32).map { Double($0) / 32 * end }
                    for sigma in [broadSigma, closeSigma] {
                        for step in -16...16 {
                            let offset = Double(step) / 4 * sigma
                            positions.append(min(extent, max(0, end + offset)))
                            positions.append(min(extent, max(0, offset)))
                        }
                    }
                    positions.append(extent)
                    let stops = Set(positions).sorted().map { x -> Gradient.Stop in
                        let position = min(1, max(0, x / end))
                        let emission = LoadingLight.base + (1 - LoadingLight.base) * pow(position, LoadingLight.curve)
                        let energy = broad * coverage(at: x, end: end, sigma: broadSigma)
                            + close * coverage(at: x, end: end, sigma: closeSigma)
                        return .init(color: tint.opacity(emission * energy), location: x / extent)
                    }
                    let glow = GraphicsContext.Shading.linearGradient(
                        Gradient(stops: stops), startPoint: .zero, endPoint: CGPoint(x: extent, y: 0)
                    )
                    context.fill(Path(CGRect(x: 0, y: y, width: extent, height: 0.5)), with: glow)
                }
            }
            let lineStops = (0...32).map { step -> Gradient.Stop in
                let x = Double(step) / 32
                return .init(color: tint.opacity(LoadingLight.lineStrength * (LoadingLight.base + (1 - LoadingLight.base) * pow(x, LoadingLight.curve))), location: x)
            }
            let core = Path(CGRect(x: 0, y: size.height - ChromeMetrics.progressHeight, width: end, height: ChromeMetrics.progressHeight))
            context.fill(core, with: .linearGradient(Gradient(stops: lineStops), startPoint: .zero, endPoint: CGPoint(x: end, y: 0)))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
