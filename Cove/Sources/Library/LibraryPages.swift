import SwiftUI

/// Tabs that left Today, newest first. Clicking one brings it back whole.
struct LibraryArchive: View {
    let model: LibraryModel
    @ObservedObject var archive: TabArchive
    @Binding var query: String

    var body: some View {
        let entries = archive.entries.matching(query)

        LibraryToolbar {
            LibrarySearchField(text: $query, prompt: "Search Archive")
        }

        LibraryList(isEmpty: entries.isEmpty, emptyText: query.isEmpty ? "No archived tabs" : "No results") {
            ForEach(entries) { entry in
                LibraryPageRow(title: entry.title, url: entry.url, favicon: model.faviconStore.image(forPage: entry.url)) {
                    model.reopen(entry)
                } accessory: { isHovered in
                    if isHovered {
                        Button { archive.remove(entry.id) } label: {
                            Image(systemName: ChromeSymbols.Tabs.close)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.libraryAccessory)
                        .help("Delete from Archive")
                    } else {
                        Text(entry.archivedAt.formatted(.relative(presentation: .named, unitsStyle: .abbreviated)))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }
                .contextMenu {
                    Button("Reopen Tab") { model.reopen(entry) }
                    Button("Copy Link") { model.copyLink(entry.url) }
                    Divider()
                    Button("Delete from Archive", role: .destructive) { archive.remove(entry.id) }
                }
            }
        }
    }
}

/// Recent history by day, each page once. The History window has every visit.
struct LibraryHistory: View {
    let model: LibraryModel
    @ObservedObject var historyStore: HistoryStore
    @Binding var query: String

    @State private var days: [HistoryDay] = []
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        LibraryToolbar {
            LibrarySearchField(text: $query, prompt: "Search History")

            Button {
                openWindow(id: HistoryWindow.windowID)
            } label: {
                Image(systemName: ChromeSymbols.Navigation.history)
            }
            .buttonStyle(ChromeButtonStyle())
            .help("Show All History")
        }

        LibraryList(isEmpty: days.isEmpty, emptyText: query.isEmpty ? "No history" : "No results") {
            ForEach(days) { day in
                Text(day.title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.top, 8)
                    .padding(.bottom, 2)

                ForEach(day.entries) { entry in
                    LibraryPageRow(title: entry.title, url: entry.url, favicon: model.faviconStore.image(forPage: entry.url)) {
                        model.open(entry.url)
                    } accessory: { _ in
                        Text(entry.visitedAt, format: .dateTime.hour().minute())
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                    .contextMenu {
                        Button("Open in New Tab") { model.open(entry.url) }
                        Button("Copy Link") { model.copyLink(entry.url) }
                    }
                }
            }
        }
        .task(id: query) { reload() }
        // New visits show up while the Library is open.
        .onChange(of: historyStore.recentlyVisited.map(\.id)) { reload() }
    }

    private func reload() {
        days = model.history(matching: query)
    }
}

/// A page in the archive or history: its favicon, title and address.
private struct LibraryPageRow<Accessory: View>: View {
    let title: String
    let url: String
    let favicon: NSImage?
    let action: () -> Void
    @ViewBuilder let accessory: (_ isHovered: Bool) -> Accessory

    var body: some View {
        LibraryRow(title: title.isEmpty ? address : title, action: action) {
            FaviconView(image: favicon, size: 16)
        } detail: {
            Text(address)
        } accessory: { isHovered in
            accessory(isHovered)
        }
        .help(url)
    }

    private var address: String {
        CommandBarResult.displayURL(for: url)
    }
}
