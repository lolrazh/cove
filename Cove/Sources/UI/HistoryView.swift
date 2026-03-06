import SwiftUI

struct HistoryView: View {
    let onNavigate: (String) -> Void
    let onDismiss: () -> Void

    @ObservedObject private var settings = BrowserSettingsStore.shared
    @State private var searchText: String = ""
    @State private var entries: [HistoryEntry] = []
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("History")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: ChromeSymbols.Tabs.close)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(ChromeButtonStyle(kind: .toolbar))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            TextField("Search history", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($isSearchFocused)
                .chromeFieldStyle(focused: isSearchFocused, prominence: .compact)
                .padding(.horizontal, 14)
                .onChange(of: searchText) { _, query in
                    loadHistory(query: query)
                }

            Divider()
                .padding(.top, 8)

            if !settings.saveBrowsingHistory {
                Spacer()
                Text("Browsing history is turned off")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
            } else if entries.isEmpty {
                Spacer()
                Text(searchText.isEmpty ? "No history yet" : "No results")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(entries) { entry in
                            Button {
                                onNavigate(entry.url)
                                onDismiss()
                            } label: {
                                HistoryRow(entry: entry)
                            }
                            .buttonStyle(ChromeButtonStyle(kind: .row))
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                }
            }
        }
        .frame(width: 340, height: 420)
        .chromePanelSurface(.panel, cornerRadius: ChromeMetrics.panelCornerRadius, showsShadow: true)
        .onAppear { loadHistory(query: "") }
    }

    private func loadHistory(query: String) {
        guard settings.saveBrowsingHistory else {
            entries = []
            return
        }

        entries = HistoryStore.shared.search(query: query)
    }
}

struct HistoryRow: View {
    let entry: HistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.title.isEmpty ? entry.url : entry.title)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .foregroundStyle(.primary)

            HStack(spacing: 4) {
                Text(domainFrom(entry.url))
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)

                Text("·")
                    .foregroundStyle(.quaternary)

                Text(entry.visitedAt, style: .relative)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func domainFrom(_ urlString: String) -> String {
        URL(string: urlString)?.host ?? urlString
    }
}
