import WebKit

/// Find in page for one tab: whether its find bar is up, what it's looking
/// for, and whether the page has it. WebKit selects each match and scrolls to
/// it; it doesn't say how many there are, so the bar doesn't either.
@MainActor
final class FindInPage: ObservableObject {
    @Published private(set) var isPresented = false
    @Published var query = "" {
        didSet {
            guard query != oldValue else { return }
            // WebKit searches on from the end of the selection, so a longer
            // query would skip the match it extends. Start from its beginning.
            webView().evaluateJavaScript("getSelection().rangeCount && getSelection().collapseToStart()", in: nil, in: .defaultClient)
            find(backwards: false)
        }
    }
    /// False once a search comes back empty, until the query changes.
    @Published private(set) var isFound = true
    /// Bumped by ⌘F, so the field takes focus even when the bar is already up.
    @Published private(set) var focusRequests = 0

    private let webView: () -> WKWebView

    init(webView: @escaping () -> WKWebView) {
        self.webView = webView
    }

    /// ⌘F: shows the bar with the last query, ready to be replaced.
    func present() {
        isPresented = true
        focusRequests += 1
    }

    /// Escape: hides the bar and hands the keyboard back to the page, leaving
    /// the match selected.
    func dismiss() {
        guard isPresented else { return }
        isPresented = false
        let webView = webView()
        webView.window?.makeFirstResponder(webView)
    }

    /// ⌘G. With nothing to look for yet, asks for something instead.
    func findNext() {
        query.isEmpty ? present() : find(backwards: false)
    }

    /// ⌘⇧G.
    func findPrevious() {
        query.isEmpty ? present() : find(backwards: true)
    }

    private func find(backwards: Bool) {
        isPresented = true
        guard !query.isEmpty else {
            isFound = true
            return
        }
        let configuration = WKFindConfiguration()
        configuration.backwards = backwards
        webView().find(query, configuration: configuration) { [weak self] result in
            self?.isFound = result.matchFound
        }
    }
}
