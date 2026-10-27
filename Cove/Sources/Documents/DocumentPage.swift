import SwiftUI

/// A note or easel in the page card, in the page's place. Links in it, and
/// clippings' pages, open in new tabs.
struct DocumentPage: View {
    let id: UUID
    @ObservedObject var store: DocumentStore
    let tabManager: TabManager

    var body: some View {
        if let document = store.documents[id] {
            switch document.kind {
            case .note:
                if let note = store.note(id) {
                    NoteView(id: id, note: note, store: store) { tabManager.addTab(url: $0.absoluteString) }
                }
            case .easel:
                if let easel = store.easel(id) {
                    EaselView(id: id, easel: easel, store: store, dataStore: tabManager.clippingDataStore) {
                        tabManager.addTab(url: $0.absoluteString)
                    }
                }
            }
        }
    }
}
