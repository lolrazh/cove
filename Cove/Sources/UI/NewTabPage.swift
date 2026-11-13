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
                .frame(minHeight: 80, maxHeight: 200)

            HStack(spacing: 10) {
                Image(systemName: ChromeSymbols.Navigation.search)
                    .foregroundStyle(.tertiary)

                TextField("Search or enter URL", text: $searchText)
                    .textFieldStyle(.plain)
                    .accessibilityLabel("Search or enter URL")
                    .focused($isSearchFocused)
                    .onSubmit {
                        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        onNavigate(searchText)
                    }
            }
            .font(.title3)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .chromeFieldStyle(focused: isSearchFocused, minimumRadius: ChromeRadius.tile)
            .background(ChromePalette.content.opacity(0.85), in: .chrome(minimum: ChromeRadius.tile))
            .frame(maxWidth: 520)
            .padding(.horizontal, 40)

            if settingsStore.shouldShowRecentSites && !recentSites.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
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
                            .help(entry.url)
                        }
                    }
                }
                .frame(maxWidth: 520)
                .padding(.horizontal, 40)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { NewTabLight() }
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

/// A brief wash of the profile's color. The search field is ready immediately;
/// this decorative layer never moves controls or receives input.
private struct NewTabLight: View {
    @Environment(\.chromeTheme) private var theme
    @Environment(\.chromePrimaryLight) private var primary
    @Environment(\.chromeSecondaryLight) private var secondary
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasSettled = false

    var body: some View {
        GeometryReader { geometry in
            let tint = primary ?? theme.primaryLight
            let second = secondary ?? theme.secondaryLight
            let settled = hasSettled || reduceMotion
            ZStack {
                ChromePalette.content
                if contrast != .increased {
                    ZStack {
                        Ellipse()
                            .fill(RadialGradient(colors: [tint.opacity(0.15), .clear],
                                center: .center, startRadius: 0, endRadius: geometry.size.width * 0.6))
                            .frame(width: geometry.size.width * 1.2, height: geometry.size.width * 1.2)
                            .scaleEffect(x: 1, y: 0.78)
                            .position(x: geometry.size.width * 0.35, y: geometry.size.height * 1.02)
                        Ellipse()
                            .fill(RadialGradient(colors: [second.opacity(0.10), .clear],
                                center: .center, startRadius: 0, endRadius: geometry.size.width * 0.5))
                            .frame(width: geometry.size.width, height: geometry.size.width)
                            .scaleEffect(x: 1, y: 0.82)
                            .position(x: geometry.size.width * 0.8, y: geometry.size.height * 1.04)
                    }
                    // A fixed mask keeps even a very wide window's wash away
                    // from the toolbar. The page-color cache needs no special case.
                    .mask(LinearGradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .clear, location: 0.25),
                        .init(color: .white, location: 0.80),
                        .init(color: .white, location: 1),
                    ], startPoint: .top, endPoint: .bottom))
                    .opacity(settled ? 1 : 0)
                    .offset(y: settled ? 0 : 16)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            guard !hasSettled else { return }
            if reduceMotion { hasSettled = true; return }
            await Task.yield()
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 1.2)) { hasSettled = true }
        }
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
            Group {
                if let favicon {
                    FaviconView(image: favicon, size: 28)
                } else {
                    SiteMonogram(host: domainName, size: 28)
                }
            }
            .frame(width: 36, height: 36)

            Text(domainName)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .chromeHoverSurface(restingFill: true, minimumRadius: ChromeRadius.tile)
    }

    private var domainName: String {
        guard let host = URL(string: entry.url)?.host else { return entry.url }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    private var favicon: NSImage? {
        faviconStore.get(domain: domainName)
    }
}
