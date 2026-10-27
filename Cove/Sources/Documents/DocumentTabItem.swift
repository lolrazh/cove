import SwiftUI

/// A note in the sidebar or the strip, shown like a tab: its kind's glyph and
/// its title, a close button in Today, renaming in place, and a menu of its
/// own. Dragged like a tab, between Today, Pinned and folders.
struct DocumentTabItem: View {
    let id: UUID
    @ObservedObject var store: DocumentStore
    let tabManager: TabManager
    let presentation: ChromeTabPresentation
    let isActive: Bool
    var width: CGFloat? = nil

    @State private var isHovered = false
    @State private var isRenaming = false
    @State private var draftTitle = ""

    var body: some View {
        if let document = store.documents[id] {
            HStack(spacing: 8) {
                Image(systemName: document.kind.symbol)
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 16)

                if presentation != .compact {
                    titleView(document)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    closeButton
                }
            }
            .padding(.leading, presentation == .compact ? 0 : 8)
            .padding(.trailing, presentation == .compact ? 0 : ChromeMetrics.tabAccessoryInset)
            .chromeTabSurface(presentation, isActive: isActive, isHovered: isHovered, width: width)
            .animation(ChromeMotion.hover, value: isHovered)
            .onHover { isHovered = $0 }
            .onTapGesture { tabManager.showDocument(id) }
            .simultaneousGesture(TapGesture(count: 2).onEnded { beginRenaming(document) })
            .help(presentation == .compact ? document.displayTitle : "")
            .contextMenu {
                DocumentActions(document: document, tabManager: tabManager) { beginRenaming(document) }
            }
        }
    }

    @ViewBuilder
    private func titleView(_ document: DocumentInfo) -> some View {
        if isRenaming {
            RenameField(prompt: "Title", text: $draftTitle, onCommit: finishRenaming) { isRenaming = false }
                .font(.callout)
        } else {
            Text(document.displayTitle)
                .font(.callout)
                .foregroundStyle(isActive || isHovered ? .primary : .secondary)
                .lineLimit(1)
        }
    }

    private func beginRenaming(_ document: DocumentInfo) {
        draftTitle = document.title
        isRenaming = true
    }

    private func finishRenaming() {
        guard isRenaming else { return }
        isRenaming = false
        tabManager.renameDocument(id, to: draftTitle)
    }

    /// Today's notes close out of Today; a pinned one only while it's on screen.
    private var closeButton: some View {
        let isVisible = isHovered && (isActive || tabManager.section(of: id) == .today)

        return Button { tabManager.closeDocument(id) } label: {
            Image(systemName: ChromeSymbols.Tabs.close)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(presentation.accessoryStyle)
        .help("Close")
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(isVisible)
        .animation(ChromeMotion.hover, value: isVisible)
    }
}

/// What can be done to a note: its context menu, and the Tab menu's half
/// while it's on screen.
struct DocumentActions: View {
    let document: DocumentInfo
    let tabManager: TabManager
    /// Renaming in place, where the note is shown; nil in the menu bar.
    var rename: (() -> Void)?

    var body: some View {
        if tabManager.section(of: document.id) == .today {
            Button("Pin \(document.kind.name)") {
                tabManager.pinDocument(document.id)
            }
        } else {
            Button("Unpin \(document.kind.name)") {
                tabManager.unpinDocument(document.id)
            }
        }

        if let rename {
            Button("Rename \(document.kind.name)…", action: rename)
        }

        Divider()

        if tabManager.section(of: document.id) == .today {
            Button("Close \(document.kind.name)") {
                tabManager.closeDocument(document.id)
            }
        }

        Button("Delete \(document.kind.name)…") {
            tabManager.documentToDelete = document.id
        }
    }
}

/// The note on screen in the URL pill's place: its glyph and title.
struct DocumentLabel: View {
    let id: UUID
    @ObservedObject var store: DocumentStore

    var body: some View {
        if let document = store.documents[id] {
            HStack(spacing: 8) {
                Image(systemName: document.kind.symbol)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text(document.displayTitle)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }
}
