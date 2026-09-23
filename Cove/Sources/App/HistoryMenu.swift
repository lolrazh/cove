import SwiftUI
import AppKit

/// The History menu: Safari's navigation items, plus Dia's Recently Visited and
/// Recently Closed sections.
struct HistoryMenu: View {
    let tabManager: TabManager?
    @ObservedObject var historyStore: HistoryStore
    @ObservedObject var recentlyClosed: RecentlyClosedTabs
    let faviconStore: FaviconStore
    let onShowAllHistory: () -> Void

    var body: some View {
        Button("Back") {
            tabManager?.goBack()
        }
        .keyboardShortcut("[", modifiers: .command)
        .disabled(tabManager == nil)

        Button("Forward") {
            tabManager?.goForward()
        }
        .keyboardShortcut("]", modifiers: .command)
        .disabled(tabManager == nil)

        Divider()

        Button("Reopen Last Closed Tab") {
            tabManager?.reopenClosedTab()
        }
        .keyboardShortcut("t", modifiers: [.command, .shift])
        .disabled(tabManager == nil || recentlyClosed.entries.isEmpty)

        if !historyStore.recentlyVisited.isEmpty {
            Section("Recently Visited") {
                ForEach(historyStore.recentlyVisited) { entry in
                    Button {
                        tabManager?.activeTab?.navigate(entry.url)
                    } label: {
                        pageLabel(title: entry.title, url: entry.url)
                    }
                }
            }
            .disabled(tabManager == nil)
        }

        if !recentlyClosed.entries.isEmpty {
            Section("Recently Closed") {
                ForEach(recentlyClosed.entries) { entry in
                    Button {
                        tabManager?.reopenClosedTab(entry.id)
                    } label: {
                        pageLabel(title: entry.title, url: entry.url)
                    }
                }
            }
            .disabled(tabManager == nil)
        }

        Divider()

        Button {
            onShowAllHistory()
        } label: {
            Label("Show All History…", systemImage: ChromeSymbols.Navigation.history)
        }
        .keyboardShortcut("y", modifiers: .command)
    }

    private func pageLabel(title: String, url: String) -> some View {
        Label {
            Text(menuTitle(title: title, url: url))
        } icon: {
            if let favicon = faviconStore.image(forPage: url) {
                Image(nsImage: menuSized(favicon))
            } else {
                Image(systemName: ChromeSymbols.Navigation.globe)
            }
        }
    }

    private func menuTitle(title: String, url: String) -> String {
        let text = title.isEmpty ? (URL(string: url)?.host ?? url) : title
        let limit = 60
        return text.count > limit ? String(text.prefix(limit - 1)) + "…" : text
    }

    /// Favicons are stored at whatever size the site serves; menus want 16pt.
    private func menuSized(_ image: NSImage) -> NSImage {
        let sized = image.copy() as? NSImage ?? image
        sized.size = NSSize(width: 16, height: 16)
        return sized
    }
}
