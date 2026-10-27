import AppKit
import WebKit

/// What the page offers besides browsing: printing, saving, its source, and
/// its video in Picture in Picture.
extension TabSession {
    /// Shows the print sheet for the page.
    func printPage() {
        guard let window = webView.window else { return }
        let operation = webView.printOperation(with: .shared)
        // WebKit prints blank pages from a print view that has no size.
        operation.view?.frame = webView.bounds
        operation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
    }

    /// The page and everything it loaded, as a web archive.
    func webArchive() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            webView.createWebArchiveData { continuation.resume(with: $0) }
        }
    }

    /// The page's HTML as the server sent it, read from its web archive.
    func pageSource() async -> WebArchive.MainResource? {
        guard let archive = try? await webArchive() else { return nil }
        return WebArchive.mainResource(in: archive)
    }

    /// Puts the page's video in Picture in Picture, or brings it back. The
    /// video is the one playing, or else the largest. False when there's no
    /// video. Runs in WebKit's client world, out of the page's reach; WebKit
    /// treats calls from the app as a user gesture, which the API requires.
    func togglePictureInPicture() async -> Bool {
        let result = try? await webView.evaluateJavaScript(Self.pictureInPictureScript, contentWorld: .defaultClient)
        return result as? Bool ?? false
    }

    private static let pictureInPictureScript = """
    (() => {
        if (document.pictureInPictureElement) {
            document.exitPictureInPicture();
            return true;
        }
        const videos = [...document.querySelectorAll("video")];
        const area = (video) => video.clientWidth * video.clientHeight;
        const video = videos.find((video) => !video.paused && !video.ended)
            ?? videos.sort((a, b) => area(b) - area(a))[0];
        video?.requestPictureInPicture();
        return video !== undefined;
    })();
    """
}
