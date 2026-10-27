import SwiftUI

/// A note in the page card, in the page's place. Links in it open in new tabs.
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
            }
        }
    }
}
