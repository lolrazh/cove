import Foundation
import Testing
import WebKit
@testable import Cove

struct NowPlayingTests {
    private func nowPlaying(
        isPlaying: Bool = true,
        hasPreviousTrack: Bool = false,
        hasNextTrack: Bool = false
    ) -> NowPlaying {
        NowPlaying(
            title: "",
            artist: "",
            isPlaying: isPlaying,
            hasPreviousTrack: hasPreviousTrack,
            hasNextTrack: hasNextTrack
        )
    }

    @Test func `a frame's report reads into what's playing`() {
        let report: [String: Any] = ["playing": false, "title": "Song", "artist": "Band", "previous": false, "next": true]
        #expect(NowPlaying(report: report) == NowPlaying(
            title: "Song",
            artist: "Band",
            isPlaying: false,
            hasPreviousTrack: false,
            hasNextTrack: true
        ))
    }

    @Test func `a frame with no media reports nothing playing`() {
        #expect(NowPlaying(report: NSNull()) == nil)
        #expect(NowPlaying(report: nil) == nil)
    }

    @Test func `skipping changes track when the page has tracks, and seeks when it doesn't`() {
        let playlist = nowPlaying(hasPreviousTrack: true, hasNextTrack: true)
        #expect(playlist.skipAction(forward: false) == .previousTrack)
        #expect(playlist.skipAction(forward: true) == .nextTrack)

        let video = nowPlaying()
        #expect(video.skipAction(forward: false) == .seekBackward)
        #expect(video.skipAction(forward: true) == .seekForward)
    }

    @Test func `the player shows playing media first, then paused media`() {
        let tabs: [(name: String, media: NowPlaying?)] = [
            ("quiet", nil),
            ("paused", nowPlaying(isPlaying: false)),
            ("playing", nowPlaying()),
        ]
        #expect(tabs.preferringPlaying(\.media)?.name == "playing")
        #expect(tabs.dropLast().preferringPlaying(\.media)?.name == "paused")
        #expect(tabs.prefix(1).preferringPlaying(\.media) == nil)
    }
}

/// Exercise the real client-world bridge without a network or audio device.
@Suite(.serialized)
@MainActor
struct PageMediaTests {
    private func makePage() async throws -> WKWebView {
        let page = WKWebView()
        page.loadHTMLString("<html><body id=media-test></body></html>", baseURL: URL(string: "https://media.test"))
        for _ in 0..<300 {
            if (try? await page.evaluateJavaScript("!!document.getElementById('media-test')")) as? Bool == true {
                return page
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        Issue.record("Media test page did not load")
        return page
    }

    @Test func `pausing the latest frame returns controls to the frame still playing`() async throws {
        let page = try await makePage()
        var status = PageMedia.Status()
        let media = PageMedia(webView: page, isMuted: false) { status = $0 }

        func report(_ frame: String, playing: Bool) async throws {
            _ = try await page.callAsyncJavaScript(
                "return await webkit.messageHandlers.pageMedia.postMessage({frame, audible: playing, media: {playing, title: frame}})",
                arguments: ["frame": frame, "playing": playing], contentWorld: .defaultClient
            )
        }

        try await report("music", playing: true)
        try await report("video", playing: true)
        #expect(status.nowPlaying?.title == "video")
        try await report("video", playing: false)
        #expect(status.nowPlaying?.title == "music")
        #expect(status.nowPlaying?.isPlaying == true)
        try await report("music", playing: false)
        #expect(status.nowPlaying?.title == "music")
        #expect(status.nowPlaying?.isPlaying == false)
        media.closePlayer()
        #expect(status.nowPlaying == nil)
        try await report("music", playing: false)
        #expect(status.nowPlaying == nil)
        try await report("music", playing: true)
        #expect(status.nowPlaying?.title == "music")
        media.reset()
        #expect(status == PageMedia.Status())
    }

    @Test func `ended media offers play instead of pause`() async throws {
        let page = WKWebView()
        var status = PageMedia.Status()
        let media = PageMedia(webView: page, isMuted: false) { status = $0 }
        page.loadHTMLString("<html><body><audio></audio></body></html>", baseURL: URL(string: "https://media.test"))
        for _ in 0..<300 {
            if (try? await page.evaluateJavaScript("!!document.querySelector('audio')")) as? Bool == true { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        // A deterministic media element exercises the injected event listeners.
        // Its read-only playback properties are supplied in the same world.
        _ = try await page.callAsyncJavaScript("""
            const audio = document.querySelector('audio');
            globalThis.testEnded = false;
            Object.defineProperties(audio, {
                paused: {get: () => false},
                ended: {get: () => globalThis.testEnded}
            });
            audio.dispatchEvent(new Event('playing', {bubbles: true}));
            """, contentWorld: .defaultClient)
        for _ in 0..<300 {
            if status.nowPlaying?.isPlaying == true { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(status.nowPlaying?.isPlaying == true)
        _ = try await page.callAsyncJavaScript("""
            globalThis.testEnded = true;
            document.querySelector('audio').dispatchEvent(new Event('ended', {bubbles: true}));
            """, contentWorld: .defaultClient)
        for _ in 0..<300 {
            if status.nowPlaying?.isPlaying == false { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(status.nowPlaying?.isPlaying == false)
        #expect(!status.isAudible)
        withExtendedLifetime(media) {}
    }
}
