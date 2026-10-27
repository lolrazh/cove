import Foundation

/// Page zoom steps: Safari's, from half size to triple.
enum PageZoom {
    static let levels: [Double] = [0.5, 0.75, 0.85, 1, 1.15, 1.25, 1.5, 1.75, 2, 2.5, 3]

    /// The next step in from `zoom`, or nil at the largest. A zoom between
    /// steps goes to the nearest one in that direction.
    static func zoomedIn(from zoom: Double) -> Double? {
        levels.first { $0 > zoom + tolerance }
    }

    /// The next step out from `zoom`, or nil at the smallest.
    static func zoomedOut(from zoom: Double) -> Double? {
        levels.last { $0 < zoom - tolerance }
    }

    private static let tolerance = 0.001
}

/// The zoom each site was last left at, kept across launches. Sites are hosts,
/// so every page on a site opens at the same size, as in Safari and Chrome.
@MainActor
final class SiteZoomStore {
    private static let key = "browser.siteZoom"

    private let defaults: UserDefaults
    private var zooms: [String: Double]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.zooms = defaults.dictionary(forKey: Self.key) as? [String: Double] ?? [:]
    }

    func zoom(for url: URL?) -> Double {
        url?.host().flatMap { zooms[$0] } ?? 1
    }

    /// Remembers the zoom for the page's site. Actual size is the default, so
    /// it's forgotten rather than stored.
    func setZoom(_ zoom: Double, for url: URL?) {
        guard let host = url?.host() else { return }
        zooms[host] = zoom == 1 ? nil : zoom
        defaults.set(zooms, forKey: Self.key)
    }
}
