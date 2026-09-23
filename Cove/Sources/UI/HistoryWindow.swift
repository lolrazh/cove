import SwiftUI
import AppKit

/// All browsing history, grouped by day and searchable. Opening an entry loads
/// it in a browser window.
struct HistoryWindow: View {
    static let windowID = "history"

    @ObservedObject var historyStore: HistoryStore
    let faviconStore: FaviconStore
    let onOpen: (String) -> Void

    @State private var query = ""
    @State private var days: [HistoryDay] = []
    @State private var selection = Set<HistoryEntry.ID>()

    var body: some View {
        List(selection: $selection) {
            ForEach(days) { day in
                Section(day.title) {
                    ForEach(day.entries) { entry in
                        HistoryRow(entry: entry, favicon: faviconStore.image(forPage: entry.url))
                            .listRowSeparator(.hidden)
                    }
                }
            }
        }
        .contextMenu(forSelectionType: HistoryEntry.ID.self) { ids in
            if !ids.isEmpty {
                Button("Open") { open(ids) }
                Button("Copy Link") { copyLinks(ids) }
                Divider()
                Button("Delete", role: .destructive) { delete(ids) }
            }
        } primaryAction: { ids in
            open(ids)
        }
        .onDeleteCommand { delete(selection) }
        .overlay {
            if days.isEmpty {
                ContentUnavailableView(
                    query.isEmpty ? "No History" : "No Results",
                    systemImage: ChromeSymbols.Navigation.history
                )
            }
        }
        .searchable(text: $query, placement: .toolbar, prompt: "Search History")
        .navigationTitle("History")
        .frame(minWidth: 560, minHeight: 400)
        .task(id: query) { reload() }
        // New visits show up while the window is open.
        .onChange(of: historyStore.recentlyVisited.map(\.id)) { reload() }
    }

    private var entries: [HistoryEntry] {
        days.flatMap(\.entries)
    }

    private func reload() {
        days = HistoryDay.group(historyStore.search(query: query, limit: 1000))
    }

    private func open(_ ids: Set<HistoryEntry.ID>) {
        entries.filter { ids.contains($0.id) }.forEach { onOpen($0.url) }
    }

    private func copyLinks(_ ids: Set<HistoryEntry.ID>) {
        let links = entries.filter { ids.contains($0.id) }.map(\.url)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(links.joined(separator: "\n"), forType: .string)
    }

    private func delete(_ ids: Set<HistoryEntry.ID>) {
        historyStore.delete(ids)
        selection.subtract(ids)
        reload()
    }
}

private struct HistoryRow: View {
    let entry: HistoryEntry
    let favicon: NSImage?

    var body: some View {
        HStack(spacing: 10) {
            Text(entry.visitedAt, format: .dateTime.hour().minute())
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)

            FaviconView(image: favicon, size: 16)

            Text(title)
                .lineLimit(1)

            Text(host)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .help(entry.url)
    }

    private var title: String {
        entry.title.isEmpty ? host : entry.title
    }

    private var host: String {
        guard let host = URL(string: entry.url)?.host() else { return entry.url }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}

private struct HistoryDay: Identifiable {
    let id: Date
    let entries: [HistoryEntry]

    /// "Today – Wednesday, September 23", "Yesterday – …", then plain dates.
    var title: String {
        let calendar = Calendar.current
        let date = id.formatted(.dateTime.weekday(.wide).month(.wide).day())
        if calendar.isDateInToday(id) { return "Today – \(date)" }
        if calendar.isDateInYesterday(id) { return "Yesterday – \(date)" }
        if calendar.isDate(id, equalTo: .now, toGranularity: .year) { return date }
        return id.formatted(.dateTime.weekday(.wide).month(.wide).day().year())
    }

    /// Entries arrive newest first, so days come out newest first too.
    static func group(_ entries: [HistoryEntry]) -> [HistoryDay] {
        let calendar = Calendar.current
        var days: [HistoryDay] = []
        for entry in entries {
            let day = calendar.startOfDay(for: entry.visitedAt)
            if let last = days.last, last.id == day {
                days[days.count - 1] = HistoryDay(id: day, entries: last.entries + [entry])
            } else {
                days.append(HistoryDay(id: day, entries: [entry]))
            }
        }
        return days
    }
}
