import Foundation
import AppKit
import WebKit

@MainActor
final class FaviconFetcher {
    private let store: FaviconStore
    private var currentSiteKey: String?
    private var requestID: UUID?
    private var task: Task<Void, Never>?

    init(store: FaviconStore) {
        self.store = store
    }

    deinit {
        task?.cancel()
    }

    /// Kick off a favicon fetch for the given page URL.
    /// Returns the image synchronously if cached, otherwise fetches async and calls `onResult`.
    func update(for pageURL: URL?, force: Bool = false, onResult: @escaping (NSImage?) -> Void) {
        guard let pageURL,
              let siteKey = Self.siteKey(for: pageURL),
              let faviconURL = Self.canonicalFaviconURL(for: pageURL) else {
            reset()
            onResult(nil)
            return
        }

        let siteChanged = currentSiteKey != siteKey
        if !siteChanged && !force && (requestID != nil || task != nil) {
            return
        }

        currentSiteKey = siteKey
        task?.cancel()
        task = nil

        if siteChanged || force {
            onResult(nil)
        }

        if let cached = store.get(domain: siteKey) {
            requestID = nil
            onResult(cached)
            return
        }

        let rid = UUID()
        requestID = rid
        task = Task(priority: .userInitiated) { [weak self] in
            guard let data = await Self.fetchData(from: faviconURL),
                  !Task.isCancelled,
                  let image = Self.render(from: data) else {
                await MainActor.run { [weak self] in
                    self?.completeRequest(ifMatches: rid)
                }
                return
            }

            await MainActor.run { [weak self] in
                guard let self, self.requestID == rid, self.currentSiteKey == siteKey else { return }
                self.store.store(domain: siteKey, imageData: data)
                self.completeRequest(ifMatches: rid)
                onResult(image)
            }
        }
    }

    /// After page finishes loading, try document link tags if we still don't have an icon.
    func upgradeFromPage(_ webView: WKWebView, currentImage: NSImage?, onResult: @escaping (NSImage?) -> Void) {
        guard currentImage == nil,
              let pageURL = webView.url,
              let siteKey = Self.siteKey(for: pageURL),
              currentSiteKey == siteKey else { return }

        let fallbackURL = Self.canonicalFaviconURL(for: pageURL)
        task?.cancel()
        task = nil

        let rid = UUID()
        requestID = rid
        task = Task(priority: .userInitiated) { [weak self] in
            let candidates = await Self.documentCandidates(from: webView, pageURL: pageURL, fallback: fallbackURL)
            guard let data = await Self.fetchFirstData(from: candidates),
                  !Task.isCancelled,
                  let image = Self.render(from: data) else {
                await MainActor.run { [weak self] in
                    self?.completeRequest(ifMatches: rid)
                }
                return
            }

            await MainActor.run { [weak self] in
                guard let self, self.requestID == rid, self.currentSiteKey == siteKey else { return }
                self.store.store(domain: siteKey, imageData: data)
                self.completeRequest(ifMatches: rid)
                onResult(image)
            }
        }
    }

    func reset() {
        task?.cancel()
        task = nil
        currentSiteKey = nil
        requestID = nil
    }

    // MARK: - Private

    private func completeRequest(ifMatches rid: UUID) {
        guard requestID == rid else { return }
        task = nil
        requestID = nil
    }

    // MARK: - Pure functions (no instance state)

    static func siteKey(for pageURL: URL) -> String? {
        guard let host = pageURL.host?.lowercased() else { return nil }
        if let port = pageURL.port { return "\(host):\(port)" }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    private static func canonicalFaviconURL(for pageURL: URL) -> URL? {
        guard let scheme = pageURL.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = pageURL.host else { return nil }

        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.port = pageURL.port
        components.path = "/favicon.ico"
        return components.url
    }

    private nonisolated static func fetchData(from url: URL) async -> Data? {
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 1.5)
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              !data.isEmpty else { return nil }
        return data
    }

    private nonisolated static func fetchFirstData(from urls: [URL]) async -> Data? {
        let candidates = Array(urls.prefix(6))
        guard !candidates.isEmpty else { return nil }

        return await withTaskGroup(of: Data?.self, returning: Data?.self) { group in
            for url in candidates {
                group.addTask { await fetchData(from: url) }
            }
            while let data = await group.next() {
                if let data {
                    group.cancelAll()
                    return data
                }
            }
            return nil
        }
    }

    private static func documentCandidates(from webView: WKWebView, pageURL: URL, fallback: URL?) async -> [URL] {
        let script = """
        (() => {
          return Array.from(document.querySelectorAll('link[rel][href]'))
            .map(link => {
              const rel = (link.getAttribute('rel') || '').toLowerCase();
              if (!rel.includes('icon')) return null;
              if (rel.includes('apple-touch-icon') || rel.includes('mask-icon')) return null;
              const href = link.href;
              return href && href.length > 0 ? href : null;
            })
            .filter(Boolean);
        })();
        """

        let hrefs: [String] = await withCheckedContinuation { continuation in
            webView.evaluateJavaScript(script) { value, _ in
                if let hrefs = value as? [String] {
                    continuation.resume(returning: hrefs)
                } else if let hrefs = value as? [NSString] {
                    continuation.resume(returning: hrefs.map(String.init))
                } else {
                    continuation.resume(returning: [])
                }
            }
        }

        let parsed = hrefs.compactMap { href -> URL? in
            guard let url = URL(string: href, relativeTo: pageURL)?.absoluteURL,
                  let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https" else { return nil }
            return url
        }

        // Deduplicate, append fallback at end
        var ordered: [URL] = []
        var seen: Set<String> = []
        for url in parsed + [fallback].compactMap({ $0 }) {
            if seen.insert(url.absoluteString).inserted {
                ordered.append(url)
            }
        }
        return ordered
    }

    nonisolated static func render(from data: Data) -> NSImage? {
        guard let image = NSImage(data: data), image.isValid else { return nil }
        let size = NSSize(width: 32, height: 32)
        let rendered = NSImage(size: size, flipped: false) { rect in
            NSGraphicsContext.current?.imageInterpolation = .high
            image.draw(in: rect, from: NSRect(origin: .zero, size: image.size), operation: .copy, fraction: 1.0)
            return true
        }
        rendered.isTemplate = false
        return rendered
    }
}
