import SwiftUI

struct NewTabPage: View {
    let onNavigate: (String) -> Void
    @State private var searchText: String = ""
    @State private var recentSites: [HistoryEntry] = []
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(minHeight: 80, maxHeight: 160)

            // Title
            Text("Vayu")
                .font(.system(size: 28, weight: .thin, design: .default))
                .foregroundStyle(.primary.opacity(0.6))
                .padding(.bottom, 24)

            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(.tertiary)

                TextField("Search or enter URL", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .focused($isSearchFocused)
                    .onSubmit {
                        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        onNavigate(searchText)
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        isSearchFocused ? Color.accentColor.opacity(0.4) : Color.primary.opacity(0.06),
                        lineWidth: 1
                    )
            )
            .frame(maxWidth: 520)
            .padding(.horizontal, 40)

            // Recent sites
            if !recentSites.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 4)
                        .padding(.top, 28)
                        .padding(.bottom, 4)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                        ForEach(recentSites) { entry in
                            RecentSiteCard(entry: entry)
                                .onTapGesture { onNavigate(entry.url) }
                        }
                    }
                }
                .frame(maxWidth: 520)
                .padding(.horizontal, 40)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            isSearchFocused = true
            loadRecent()
        }
    }

    private func loadRecent() {
        let history = HistoryStore.shared.search(query: "", limit: 100)
        // Deduplicate by domain, keep most recent
        var seen = Set<String>()
        var unique: [HistoryEntry] = []
        for entry in history {
            let domain = URL(string: entry.url)?.host ?? entry.url
            if !seen.contains(domain) {
                seen.insert(domain)
                unique.append(entry)
            }
            if unique.count >= 8 { break }
        }
        recentSites = unique
    }
}

struct RecentSiteCard: View {
    let entry: HistoryEntry
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 6) {
            // Domain initial as placeholder
            Text(domainInitial)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.06))
                )

            Text(domainName)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovering ? Color.primary.opacity(0.04) : Color.clear)
        )
        .animation(.easeInOut(duration: 0.12), value: isHovering)
        .onHover { isHovering = $0 }
    }

    private var domainName: String {
        guard let host = URL(string: entry.url)?.host else { return entry.url }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    private var domainInitial: String {
        String(domainName.prefix(1)).uppercased()
    }
}
