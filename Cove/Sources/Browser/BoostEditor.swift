import Foundation

/// The Boost editor for one page's site. Every change is saved as it's made,
/// so the page previews it: styles at once, a script on the next load. A
/// Boost that's still empty isn't kept.
@MainActor
final class BoostEditor: ObservableObject {
    @Published var boost: Boost {
        didSet { store.save(boost) }
    }
    @Published private(set) var isZapping = false

    let page: TabSession
    private let store: BoostStore
    private var zap: BoostZap?

    /// Edits the site's Boost, or the one covering it, or a new one.
    init(page: TabSession, site: Site) {
        self.page = page
        store = page.services.boosts.store
        boost = store.boost(for: site) ?? Boost(site: site)
    }

    /// Whether the Boost is kept, and so can be deleted.
    var isSaved: Bool {
        store.boosts.contains { $0.id == boost.id }
    }

    /// Turns the Boost on or off. Styles follow at once; a script needs the
    /// page loaded again.
    func setEnabled(_ isEnabled: Bool) {
        boost.isEnabled = isEnabled
        if boost.hasScript { page.reload() }
    }

    func reload() {
        page.reload()
    }

    func delete() {
        stopZapping()
        store.remove(boost.id)
        if boost.hasScript { page.reload() }
    }

    // MARK: - Zapping

    func toggleZapping() {
        isZapping ? stopZapping() : startZapping()
    }

    func stopZapping() {
        zap?.stop()
        zap = nil
        isZapping = false
    }

    /// Brings a zapped element back.
    func unhide(_ selector: String) {
        boost.hiddenElements.removeAll { $0 == selector }
    }

    private func startZapping() {
        guard let webView = page.webView else { return }
        isZapping = true
        zap = BoostZap(in: webView) { [weak self] selector in
            guard let self, !boost.hiddenElements.contains(selector) else { return }
            boost.hiddenElements.append(selector)
        } onEnd: { [weak self] in
            self?.zap = nil
            self?.isZapping = false
        }
    }
}
