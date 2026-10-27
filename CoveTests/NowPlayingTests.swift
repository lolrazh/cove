import Foundation
import Testing
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
