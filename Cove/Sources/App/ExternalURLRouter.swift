import Foundation

@MainActor
final class ExternalURLRouter: ObservableObject {
    @Published private(set) var queuedURLs: [URL] = []

    func enqueue(_ urls: [URL]) {
        let supportedURLs = urls.filter(Self.canOpen)
        guard !supportedURLs.isEmpty else { return }
        queuedURLs.append(contentsOf: supportedURLs)
    }

    func drain() -> [URL] {
        let urls = queuedURLs
        queuedURLs.removeAll()
        return urls
    }

    func consume(_ handler: (URL) -> Void) {
        for url in drain() {
            handler(url)
        }
    }

    static func canOpen(_ url: URL) -> Bool {
        let scheme = url.scheme?.lowercased()
        return scheme == "http" || scheme == "https" || scheme == "file"
    }
}
