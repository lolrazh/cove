import SwiftUI

struct HistoryView: View {
    @ObservedObject private var settingsStore: BrowserSettingsStore
    private let historyStore: HistoryStore
    let onNavigate: (String) -> Void
    let onDismiss: () -> Void

    @State private var searchText: String = ""
    @State private var entries: [HistoryEntry] = []
    @FocusState private var isSearchFocused: Bool

    init(
        settingsStore: BrowserSettingsStore,
        historyStore: HistoryStore,
        onNavigate: @escaping (String) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self._settingsStore = ObservedObject(wrappedValue: settingsStore)
        self.historyStore = historyStore
        self.onNavigate = onNavigate
        self.onDismiss = onDismiss
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search History", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .focused($isSearchFocused)
                .padding([.horizontal, .top], 12)
                .onChange(of: searchText) { _, query in
                    loadHistory(query: query)
                }

            Divider()
                .padding(.top, 8)

            if !settingsStore.saveBrowsingHistory {
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
                            .buttonStyle(ChromeButtonStyle(size: .row))
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                }
            }
        }
        .frame(width: 340, height: 420)
        .onAppear {
            isSearchFocused = true
            loadHistory(query: "")
        }
    }

    private func loadHistory(query: String) {
        guard settingsStore.saveBrowsingHistory else {
            entries = []
            return
        }

        entries = historyStore.search(query: query)
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
