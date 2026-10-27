import WebKit

/// The media a page is playing, as the sidebar's player shows it.
struct NowPlaying: Equatable {
    /// From the page's Media Session; empty when it gives none.
    let title: String
    let artist: String
    let isPlaying: Bool
    /// Whether the page goes to the previous or next track itself, as a
    /// playlist or an album does. Without it, skipping seeks.
    let hasPreviousTrack: Bool
    let hasNextTrack: Bool

    /// What skipping back or forward asks the page to do.
    func skipAction(forward: Bool) -> MediaAction {
        if forward {
            hasNextTrack ? .nextTrack : .seekForward
        } else {
            hasPreviousTrack ? .previousTrack : .seekBackward
        }
    }
}

extension NowPlaying {
    /// Reads a frame's report of its media.
    init?(report: Any?) {
        guard let report = report as? [String: Any],
              let isPlaying = report["playing"] as? Bool else { return nil }
        self.init(
            title: report["title"] as? String ?? "",
            artist: report["artist"] as? String ?? "",
            isPlaying: isPlaying,
            hasPreviousTrack: report["previous"] as? Bool ?? false,
            hasNextTrack: report["next"] as? Bool ?? false
        )
    }
}

extension Sequence {
    /// The first element whose media is playing, else the first with paused
    /// media: the one a media player should show.
    func preferringPlaying(_ nowPlaying: (Element) -> NowPlaying?) -> Element? {
        let withMedia = filter { nowPlaying($0) != nil }
        return withMedia.first { nowPlaying($0)?.isPlaying == true } ?? withMedia.first
    }
}

/// What the player can ask of a page's media, by the Media Session names.
enum MediaAction: String {
    case play
    case pause
    case previousTrack = "previoustrack"
    case nextTrack = "nexttrack"
    case seekBackward = "seekbackward"
    case seekForward = "seekforward"
}

/// Follows a page's media: whether it makes sound, for the tab's speaker, and
/// what it plays, for the sidebar's player. Mutes it, and plays, pauses and
/// skips it.
///
/// WebKit has no public API for any of this. `requestMediaPlaybackState` is a
/// one-off query that counts silent and muted video as playing, and
/// `setAllMediaPlaybackSuspended` pauses media rather than muting it. So a user
/// script in every frame watches the page's audio and video elements, from
/// WebKit's client content world where the page's own scripts can't see it.
/// It reports whether any of them is playing with sound, and the one the
/// player controls: the last to play with sound, playing or paused, for as
/// long as it stays in the document. Muting sets their `muted` and remembers
/// which ones it silenced, so unmuting gives back only those, and a page that
/// unmutes itself is muted again. Sound made with Web Audio, or by media
/// elements never added to the document, isn't seen.
///
/// The title and artist come from the page's Media Session, which the client
/// world can read. Its action handlers it can't: a page that handles next
/// track, or play, wants to be asked rather than have its media element
/// driven behind its back. So a second, small script in the page's own world
/// wraps `setActionHandler` to keep them, and the two talk through cancelable
/// events on the document: the page world cancels an action it handled, or a
/// query for one it could. The page can see that script, but it changes
/// nothing about how its Media Session behaves.
@MainActor
final class PageMedia {
    /// What the tab shows of its page's media.
    struct Status: Equatable {
        var isAudible = false
        var nowPlaying: NowPlaying?
    }

    private static let messageName = "pageMedia"

    private static let script = """
    (() => {
        const frame = crypto.randomUUID();
        const silenced = new WeakSet();
        let muted = false;
        let current = null;
        let reported = "";

        const elements = () => document.querySelectorAll("audio, video");
        const isMedia = (target) => target instanceof HTMLMediaElement;
        const playsSound = (media) => !media.paused && !media.ended && media.volume > 0
            && (!media.muted || silenced.has(media));
        const apply = (media) => {
            if (muted && !media.muted) {
                media.muted = true;
                silenced.add(media);
            } else if (!muted && silenced.has(media)) {
                silenced.delete(media);
                media.muted = false;
            }
        };
        const handledByPage = (kind, action) => !document.dispatchEvent(
            new CustomEvent(`\(messageName)-${kind}`, { detail: action, cancelable: true })
        );
        const nowPlaying = () => {
            if (!current?.isConnected) { return null; }
            const metadata = navigator.mediaSession?.metadata;
            return {
                playing: !current.paused,
                title: metadata?.title ?? "",
                artist: metadata?.artist ?? "",
                previous: handledByPage("query", "previoustrack"),
                next: handledByPage("query", "nexttrack"),
            };
        };
        const update = async (event) => {
            elements().forEach(apply);
            if (isMedia(event?.target) && playsSound(event.target)) {
                current = event.target;
                // Taken out of the document, it pauses where the document
                // no longer hears it.
                current.addEventListener("pause", update, { passive: true });
            }
            const state = {
                frame,
                audible: [...elements()].some(playsSound),
                media: nowPlaying(),
            };
            const json = JSON.stringify(state);
            if (json === reported) { return; }
            reported = json;
            muted = await webkit.messageHandlers.\(messageName).postMessage(state);
            elements().forEach(apply);
        };

        globalThis.\(messageName) = {
            setMuted(value) {
                muted = value;
                elements().forEach(apply);
            },
            perform(action) {
                if (!current || handledByPage("action", action)) { return; }
                switch (action) {
                case "play": current.play(); break;
                case "pause": current.pause(); break;
                case "seekbackward": current.currentTime -= 10; break;
                case "seekforward": current.currentTime += 10; break;
                }
            },
        };
        for (const type of ["play", "playing", "pause", "ended", "emptied", "volumechange"]) {
            document.addEventListener(type, update, { capture: true, passive: true });
        }
        document.addEventListener("\(messageName)-change", update);
        window.addEventListener("pagehide", () => {
            current = null;
            webkit.messageHandlers.\(messageName).postMessage({ frame, audible: false, media: null });
        });
    })();
    """

    /// Runs in the page's world, before the page's scripts.
    private static let sessionBridge = """
    (() => {
        if (!("mediaSession" in navigator)) { return; }
        const handlers = new Map();
        const session = MediaSession.prototype;
        const setActionHandler = session.setActionHandler;
        const metadata = Object.getOwnPropertyDescriptor(session, "metadata");
        const changed = () => document.dispatchEvent(new Event("\(messageName)-change"));

        session.setActionHandler = function (action, handler) {
            setActionHandler.call(this, action, handler);
            if (handler) { handlers.set(action, handler); } else { handlers.delete(action); }
            changed();
        };
        Object.defineProperty(session, "metadata", {
            ...metadata,
            set(value) {
                metadata.set.call(this, value);
                changed();
            },
        });
        document.addEventListener("\(messageName)-query", (event) => {
            if (handlers.has(event.detail)) { event.preventDefault(); }
        });
        document.addEventListener("\(messageName)-action", (event) => {
            const handler = handlers.get(event.detail);
            if (!handler) { return; }
            event.preventDefault();
            handler({ action: event.detail });
        });
    })();
    """

    private struct Frame {
        let info: WKFrameInfo
        let isAudible: Bool
        let nowPlaying: NowPlaying?
    }

    private weak var webView: WKWebView?
    private let onChange: @MainActor (Status) -> Void
    /// The frames with something to report, by the id their script made up.
    private var frames: [String: Frame] = [:]
    /// The frame whose media the player shows: the last to start playing.
    private var playerFrameID: String?
    private var status = Status()
    private var isMuted: Bool

    init(webView: WKWebView, isMuted: Bool, onChange: @escaping @MainActor (Status) -> Void) {
        self.webView = webView
        self.isMuted = isMuted
        self.onChange = onChange

        let controller = webView.configuration.userContentController
        for (source, world) in [(Self.sessionBridge, WKContentWorld.page), (Self.script, .defaultClient)] {
            controller.addUserScript(WKUserScript(
                source: source,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false,
                in: world
            ))
        }
        controller.addScriptMessageHandler(Relay(self), contentWorld: .defaultClient, name: Self.messageName)
    }

    /// Mutes or unmutes the frames playing sound now. The others learn it the
    /// next time they start, in the reply to their report.
    func setMuted(_ muted: Bool) {
        isMuted = muted
        for frame in frames.values where frame.isAudible {
            call("setMuted(muted)", arguments: ["muted": muted], in: frame.info)
        }
    }

    /// Plays, pauses or skips the media the player shows.
    func perform(_ action: MediaAction) {
        guard let frame = playerFrameID.flatMap({ frames[$0] }) else { return }
        call("perform(action)", arguments: ["action": action.rawValue], in: frame.info)
    }

    /// Closing the player pauses its media and hides it until the page plays
    /// something again.
    func closePlayer() {
        perform(.pause)
        playerFrameID = nil
        publish()
    }

    /// A new page replaced the last, and its frames with it.
    func reset() {
        frames.removeAll()
        playerFrameID = nil
        publish()
    }

    private func call(_ function: String, arguments: [String: Any], in frame: WKFrameInfo) {
        webView?.callAsyncJavaScript(
            "\(Self.messageName).\(function)",
            arguments: arguments,
            in: frame,
            in: .defaultClient
        )
    }

    /// A frame's media changed. The reply tells it whether to be muted.
    private func frame(_ id: String, reported frame: Frame) -> Bool {
        frames[id] = frame.isAudible || frame.nowPlaying != nil ? frame : nil
        if frame.nowPlaying?.isPlaying == true {
            playerFrameID = id
        } else if playerFrameID == id, frame.nowPlaying == nil {
            playerFrameID = frames.first { $0.value.nowPlaying != nil }?.key
        }
        publish()
        return isMuted
    }

    private func publish() {
        let status = Status(
            isAudible: frames.values.contains { $0.isAudible },
            nowPlaying: playerFrameID.flatMap { frames[$0]?.nowPlaying }
        )
        guard status != self.status else { return }
        self.status = status
        onChange(status)
    }

    /// Holds the monitor weakly: the content controller keeps its handlers
    /// for as long as the web view lives.
    private final class Relay: NSObject, WKScriptMessageHandlerWithReply {
        private weak var media: PageMedia?

        init(_ media: PageMedia) {
            self.media = media
        }

        @MainActor
        func userContentController(
            _ controller: WKUserContentController,
            didReceive message: WKScriptMessage
        ) async -> (Any?, String?) {
            guard let body = message.body as? [String: Any],
                  let id = body["frame"] as? String,
                  let isAudible = body["audible"] as? Bool,
                  let media else { return (false, nil) }
            let frame = Frame(info: message.frameInfo, isAudible: isAudible, nowPlaying: NowPlaying(report: body["media"]))
            return (media.frame(id, reported: frame), nil)
        }
    }
}
