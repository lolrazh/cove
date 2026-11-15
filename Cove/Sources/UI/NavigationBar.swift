import SwiftUI

/// The toolbar in the page card, in every tab layout: navigation, the address
/// field, extensions' buttons, the media player and the Library. The field only shows the URL behind
/// the site controls glyph; clicking the URL opens the Command Bar, where all
/// editing happens.
struct NavigationBar: View {
    @ObservedObject var session: TabSession
    @ObservedObject private var tabManager: TabManager
    private let presentsSiteControls: Bool
    @State private var toolbarWidth: CGFloat = 900
    @State private var isAddressHovered = false
    @State private var showsBookmarks = false
    @State private var showsSplitControls = false
    private enum AddressAction: Hashable { case bookmark, site, split }
    @FocusState private var focusedAction: AddressAction?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var systemColorScheme

    init(
        session: TabSession,
        tabManager: TabManager,
        presentsSiteControls: Bool
    ) {
        self._session = ObservedObject(wrappedValue: session)
        self._tabManager = ObservedObject(wrappedValue: tabManager)
        self.presentsSiteControls = presentsSiteControls
    }

    var body: some View {
        HStack(spacing: ChromeMetrics.navigationSpacing) {
            if tabManager.activeSplit?.panes.first == nil || tabManager.activeSplit?.panes.first == session.id {
            Button {
                tabManager.setHideTabs(!tabManager.hideTabs)
            } label: {
                Image(systemName: ChromeSymbols.Tabs.sidebarLayout)
            }
            .buttonStyle(ChromeButtonStyle())
            .help(tabManager.hideTabs ? "Show tabs" : "Hide tabs")

            }
            NavigationControls(session: session, compact: toolbarWidth < 360)
                .disabled(tabManager.activeDocumentID != nil)
            addressField
            if tabManager.isPrivate {
                PrivateBadge()
            }
            if tabManager.activeSplit == nil {
                ExtensionToolbar(tabManager: tabManager)
            } else {
                Button {
                    tabManager.closeTab(session.id)
                } label: { Image(systemName: "xmark") }
                .buttonStyle(ChromeButtonStyle())
                .help("Close pane")
                .accessibilityLabel("Close pane")
            }
            if tabManager.tabLayout == .horizontal {
                MediaPlayer(tabManager: tabManager, style: .compact)
                LibraryButton(library: tabManager.library, popoverEdge: .bottom)
            }
        }
        .onGeometryChange(for: CGFloat.self, of: \.size.width) { toolbarWidth = $0 }
        .padding(.horizontal, 6)
        .frame(height: ChromeMetrics.navigationBarHeight)
        .background {
            Color(nsColor: pageBackground ?? .textBackgroundColor)
        }
        .environment(\.colorScheme, pageBackground.map {
            PageChromeContrast.scheme(for: $0, fallback: systemColorScheme)
        } ?? systemColorScheme)
    }

    private var pageBackground: NSColor? {
        guard tabManager.activeDocumentID == nil, !session.isNewTabPage,
              session.loadFailure == nil else { return nil }
        return session.pageBackgroundColor
    }

    private var addressField: some View {
        HStack(spacing: ChromeMetrics.navigationSpacing) {
            // A note on screen in place of the page shows its title.
            if let id = tabManager.activeDocumentID, let store = tabManager.documentStore {
                DocumentLabel(id: id, store: store)
                    .padding(.leading, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Button {
                    tabManager.selectTab(session.id)
                    tabManager.editCurrentURL()
                } label: {
                    Text(displayAddress)
                    .foregroundStyle(session.currentURL.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.leading, 6)
                .accessibilityLabel("Edit address")
                AddressZoomIndicator(zoom: session.zoomFeedback)
                    .id(session.id)

            }
        }
        .overlay(alignment: .trailing) {
            if tabManager.activeDocumentID == nil {
                HStack(spacing: 0) {
                    BookmarkButton(tabManager: tabManager, page: session, isPresented: $showsBookmarks)
                        .focused($focusedAction, equals: .bookmark)
                    SiteControlsButton(tabManager: tabManager, page: session, presentsControls: presentsSiteControls)
                        .focused($focusedAction, equals: .site)
                    SplitControl(tabManager: tabManager, page: session, isPresented: $showsSplitControls)
                        .focused($focusedAction, equals: .split)
                }
                .background(Color(nsColor: pageBackground ?? .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .focusSection()
                .opacity(isAddressHovered || focusedAction != nil || showsBookmarks || showsSplitControls || tabManager.isShowingSiteControls ? 1 : 0.001)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isAddressHovered)
            }
        }
        .padding(.horizontal, 4)
        .frame(height: ChromeMetrics.addressFieldHeight)
        .chromeHoverSurface(restingFill: true)
        .overlay {
            if tabManager.activeDocumentID == nil && !session.isNewTabPage {
                PageProgressBar(
                    progress: session.estimatedProgress,
                    isLoading: session.isLoading,
                    inAddressField: true
                )
                .id(session.id)
                // Use the field's own corner shape to cut the light at the left.
                // The noninteractive overlay avoids the concentric hit-area issue.
                .clipShape(.chrome())
            }
        }
        .contentShape(Rectangle())
        .onHover { isAddressHovered = $0 }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Edit address") {
            tabManager.selectTab(session.id)
            tabManager.editCurrentURL()
        }
    }

    /// Keep the resting address short; editing always receives the full URL.
    private var displayAddress: String {
        guard let url = URL(string: session.currentURL), !session.currentURL.isEmpty else {
            return "Search or enter URL"
        }
        if let name = session.services.context.extensions.pageName(for: url) { return name }
        return Site(url)?.domain ?? url.absoluteString
    }
}
