import SwiftUI

/// One tab's page with everything that belongs to it: the start page or the
/// web view, the error page, the loading line, the hovered link's address and
/// the find bar. The browser window shows one, or one per split pane; a Peek
/// and Little Cove show one each.
struct PageView: View {
    @ObservedObject var tab: TabSession
    let appServices: AppServices
    var showsLoadingProgress = true

    var body: some View {
        ZStack(alignment: .top) {
            page
                .overlay {
                    // WebKit's initial canvas can use the system color before
                    // the document is ready. Keep its known surface over that gap.
                    if tab.isAwaitingInitialContent, !tab.isNewTabPage,
                       tab.loadFailure == nil, let color = tab.pageBackgroundColor {
                        Color(nsColor: color).allowsHitTesting(false)
                    }
                }
            if showsLoadingProgress {
                PageProgressBar(progress: tab.estimatedProgress, isLoading: tab.isLoading)
                    .id(tab.id)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay { LinkPreview(url: tab.hoveredLink) }
        .overlay {
            if !tab.isNewTabPage {
                FindBar(find: tab.findInPage)
            }
        }
    }

    @ViewBuilder
    private var page: some View {
        if tab.isNewTabPage {
            NewTabPage(
                settingsStore: appServices.settingsStore,
                historyStore: tab.services.historyStore,
                faviconStore: tab.services.faviconStore
            ) { input in
                tab.navigate(input)
            }
        } else if case .awake(let webView) = tab.page {
            // Only tabs on screen are shown, and they're always awake.
            WebViewRepresentable(webView: webView, onAppear: tab.pageDidAppear)
                .overlay {
                    if let failure = tab.loadFailure {
                        LoadFailurePage(failure: failure, onRetry: tab.retry)
                    }
                }
        }
    }
}
