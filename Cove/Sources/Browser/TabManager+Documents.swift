import Foundation

/// Arc's notes, kept in the sidebar like tabs: made in Today, pinnable in
/// Pinned and its folders, a space's own. One on screen takes the page
/// card's place; the active tab stays selected beneath it, so selecting any
/// tab brings the page back. A private window has none: a note is written
/// down, which a private window promises not to do.
extension TabManager {
    /// The note on screen.
    var activeDocument: DocumentInfo? {
        activeDocumentID.flatMap { documentStore?.documents[$0] }
    }

    func isDocument(_ id: UUID) -> Bool {
        documentStore?.documents[id] != nil
    }

    /// Whether a row or a tab in the strip is the selected one: the note on
    /// screen, or else the active tab.
    func isSelected(_ id: UUID) -> Bool {
        id == (activeDocumentID ?? activeTabID)
    }

    /// New Note: an empty note at the top of Today, on screen.
    func newDocument(_ kind: DocumentKind) {
        guard let document = documentStore?.create(kind) else { return }
        today.append(.document(document.id))
        showDocument(document.id)
    }

    /// Puts a note on screen. One that's in neither Today nor Pinned, as one
    /// found from the Command Bar, comes back into Today first.
    func showDocument(_ id: UUID) {
        guard let documentStore, documentStore.documents[id] != nil else { return }
        if section(of: id) == nil {
            today.append(.document(id))
        }
        closePeek()
        endCapture()
        activeTab?.markUsed()
        documentStore.markUsed(id)
        activeDocumentID = id
    }

    /// A note's close button and ⌘W: it leaves Today, kept for the Command
    /// Bar to find. A pinned note stays where it is; either way the page
    /// beneath comes back.
    func closeDocument(_ id: UUID) {
        if id == activeDocumentID {
            activeDocumentID = nil
        }
        today.removeAll { $0.id == id }
    }

    func renameDocument(_ id: UUID, to title: String) {
        documentStore?.rename(id, to: title.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Deletes a note for good, from every window and space.
    func deleteDocument(_ id: UUID) {
        pinStore.change { $0.removeDocument(id) }
        documentStore?.delete(id)
    }

    // MARK: - Pinning

    /// A note moves from Today into Pinned, kept until it's unpinned.
    func pinDocument(_ id: UUID, at position: SidebarPosition = .end) {
        guard today.contains(where: { $0.id == id }) else { return }
        today.removeAll { $0.id == id }
        pinStore.change(in: pinScope) { $0.addDocument(id, at: position) }
    }

    /// Unpinning puts a note back in Today: at the top, or where it was dropped.
    func unpinDocument(_ id: UUID, onto target: UUID? = nil) {
        guard pinStore.pins(in: pinScope).pinned.documents.contains(id) else { return }
        placeInToday(.document(id), onto: target)
        pinStore.change(in: pinScope) { $0.removeDocument(id) }
    }

    func togglePinnedDocument(_ id: UUID) {
        section(of: id) == .today ? pinDocument(id) : unpinDocument(id)
    }

    // MARK: - Keeping up

    /// Today lets go of notes left alone as long as it archives tabs; they're
    /// kept, and found again from the Command Bar. Pinned notes stay. A note
    /// has no page to sleep.
    func sweepIdleDocuments(policy: TabIdlePolicy, now: Date) {
        guard let documentStore else { return }
        let idle = today.compactMap(\.documentID).filter { id in
            guard let document = documentStore.documents[id] else { return false }
            let note = TabIdlePolicy.Tab(isActive: id == activeDocumentID, isAsleep: true, hasPage: false, isInUse: false, lastUsedAt: document.lastUsedAt)
            return policy.action(for: note, at: now) == .archive
        }
        if !idle.isEmpty {
            today.removeAll { idle.contains($0.id) }
        }
    }

    /// Follows deletions made in any window: a deleted note leaves Today in
    /// every space, and the screen if it was there.
    func reconcileDocuments(with documents: [UUID: DocumentInfo]) {
        let isGone = { (item: TodayItem<TabSession>) in item.documentID.map { documents[$0] == nil } ?? false }
        if today.contains(where: isGone) {
            today.removeAll(where: isGone)
        }
        removeParkedDocuments(where: isGone)
        if let activeDocumentID, documents[activeDocumentID] == nil {
            self.activeDocumentID = nil
        }
    }
}
