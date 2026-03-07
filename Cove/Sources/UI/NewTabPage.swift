import SwiftUI
import AppKit

struct NewTabPage: View {
    @ObservedObject private var settingsStore: BrowserSettingsStore
    private let historyStore: HistoryStore
    private let faviconStore: FaviconStore
    let onNavigate: (String) -> Void

    @State private var searchText: String = ""
    @State private var recentSites: [HistoryEntry] = []
    @FocusState private var isSearchFocused: Bool

    init(
        settingsStore: BrowserSettingsStore,
        historyStore: HistoryStore,
        faviconStore: FaviconStore,
        onNavigate: @escaping (String) -> Void
    ) {
        self._settingsStore = ObservedObject(wrappedValue: settingsStore)
        self.historyStore = historyStore
        self.faviconStore = faviconStore
        self.onNavigate = onNavigate
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(minHeight: 80, maxHeight: 160)

            // Title
            Text("Cove")
                .font(.system(size: 28, weight: .thin, design: .default))
                .foregroundStyle(.primary.opacity(0.6))
                .padding(.bottom, 24)

            // Search bar
            HStack(spacing: 10) {
                Image(systemName: ChromeSymbols.Navigation.search)
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
            .chromeFieldStyle(focused: isSearchFocused, prominence: .hero)
            .frame(maxWidth: 520)
            .padding(.horizontal, 40)

            // Recent sites
            if settingsStore.shouldShowRecentSites && !recentSites.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 4)
                        .padding(.top, 28)
                        .padding(.bottom, 4)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                        ForEach(recentSites) { entry in
                            Button {
                                onNavigate(entry.url)
                            } label: {
                                RecentSiteCard(entry: entry, faviconStore: faviconStore)
                            }
                            .buttonStyle(.plain)
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
        .onChange(of: settingsStore.showRecentSites) { _, _ in
            loadRecent()
        }
        .onChange(of: settingsStore.saveBrowsingHistory) { _, _ in
            loadRecent()
        }
    }

    private func loadRecent() {
        guard settingsStore.shouldShowRecentSites else {
            recentSites = []
            return
        }

        let history = historyStore.search(query: "", limit: 100)
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
    private let faviconStore: FaviconStore

    init(entry: HistoryEntry, faviconStore: FaviconStore) {
        self.entry = entry
        self.faviconStore = faviconStore
    }

    var body: some View {
        VStack(spacing: 6) {
            if let favicon {
                FaviconView(image: favicon, size: 28)
                    .frame(width: 36, height: 36)
                    .background(
                        ChromeMetrics.roundedShape(radius: 10)
                            .fill(ChromePalette.tertiaryFill)
                    )
            } else {
                Text(domainInitial)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(
                        ChromeMetrics.roundedShape(radius: 10)
                            .fill(ChromePalette.tertiaryFill)
                    )
            }

            Text(domainName)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .chromeInteractiveSurface(cornerRadius: 14, showsBorder: true)
    }

    private var domainName: String {
        guard let host = URL(string: entry.url)?.host else { return entry.url }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    private var domainInitial: String {
        String(domainName.prefix(1)).uppercased()
    }

    private var favicon: NSImage? {
        faviconStore.get(domain: domainName)
    }
}
