import SwiftUI

struct HistoryView: View {
    let onNavigate: (String) -> Void
    let onDismiss: () -> Void

    @State private var searchText: String = ""
    @State private var entries: [HistoryEntry] = []

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("History")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            // Search
            TextField("Search history", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(0.06))
                )
                .padding(.horizontal, 14)
                .onChange(of: searchText) { _, query in
                    loadHistory(query: query)
                }

            Divider()
                .padding(.top, 8)

            // Results
            if entries.isEmpty {
                Spacer()
                Text(searchText.isEmpty ? "No history yet" : "No results")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(entries) { entry in
                            HistoryRow(entry: entry)
                                .onTapGesture {
                                    onNavigate(entry.url)
                                    onDismiss()
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(width: 340, height: 420)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        .onAppear { loadHistory(query: "") }
    }

    private func loadHistory(query: String) {
        entries = HistoryStore.shared.search(query: query)
    }
}

struct HistoryRow: View {
    let entry: HistoryEntry
    @State private var isHovering = false

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
        .padding(.vertical, 6)
        .background(isHovering ? Color.primary.opacity(0.05) : Color.clear)
        .onHover { isHovering = $0 }
    }

    private func domainFrom(_ urlString: String) -> String {
        URL(string: urlString)?.host ?? urlString
    }
}
