import WebKit

/// Tells whether a page is making sound, and mutes it.
///
/// WebKit has no public API for either. `requestMediaPlaybackState` is a
/// one-off query that counts silent and muted video as playing, and
/// `setAllMediaPlaybackSuspended` pauses media rather than muting it. So a user
/// script in every frame watches the page's audio and video elements, from
/// WebKit's client content world where the page's own scripts can't see it,
/// and reports whether any of them is playing with sound. Muting sets their
/// `muted` and remembers which ones it silenced, so unmuting gives back only
/// those, and a page that unmutes itself is muted again. Sound made with Web
/// Audio, or by media elements never added to the document, isn't seen.
@MainActor
final class PageAudio {
    private static let messageName = "pageAudio"

    private static let script = """
    (() => {
        const frame = crypto.randomUUID();
        const silenced = new WeakSet();
        let muted = false;
        let audible = false;

        const elements = () => document.querySelectorAll("audio, video");
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
        const post = (isAudible) => webkit.messageHandlers.\(messageName).postMessage({ frame, audible: isAudible });
        const update = async () => {
            elements().forEach(apply);
            const now = [...elements()].some(playsSound);
            if (now === audible) { return; }
            audible = now;
            muted = await post(now);
            elements().forEach(apply);
        };

        globalThis.\(messageName) = {
            setMuted(value) {
                muted = value;
                elements().forEach(apply);
            }
        };
        for (const type of ["play", "playing", "pause", "ended", "emptied", "volumechange"]) {
            document.addEventListener(type, update, { capture: true, passive: true });
        }
        window.addEventListener("pagehide", () => { audible = false; post(false); });
    })();
    """

    private weak var webView: WKWebView?
    private let onChange: @MainActor (Bool) -> Void
    /// The frames playing sound, by the id their script made up.
    private var audibleFrames: [String: WKFrameInfo] = [:] {
        didSet {
            if audibleFrames.isEmpty != oldValue.isEmpty {
                onChange(!audibleFrames.isEmpty)
            }
        }
    }
    private var isMuted: Bool

    init(webView: WKWebView, isMuted: Bool, onChange: @escaping @MainActor (Bool) -> Void) {
        self.webView = webView
        self.isMuted = isMuted
        self.onChange = onChange

        let controller = webView.configuration.userContentController
        controller.addUserScript(WKUserScript(
            source: Self.script,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false,
            in: .defaultClient
        ))
        controller.addScriptMessageHandler(Relay(self), contentWorld: .defaultClient, name: Self.messageName)
    }

    /// Mutes or unmutes the frames playing sound now. The others learn it the
    /// next time they start, in the reply to their report.
    func setMuted(_ muted: Bool) {
        isMuted = muted
        for frame in audibleFrames.values {
            webView?.callAsyncJavaScript(
                "\(Self.messageName).setMuted(muted)",
                arguments: ["muted": muted],
                in: frame,
                in: .defaultClient
            )
        }
    }

    /// A new page replaced the last, and its frames with it.
    func reset() {
        audibleFrames.removeAll()
    }

    /// A frame started or stopped playing sound. The reply tells it whether
    /// to be muted.
    private func frame(_ id: String, isAudible: Bool, info: WKFrameInfo) -> Bool {
        audibleFrames[id] = isAudible ? info : nil
        return isMuted
    }

    /// Holds the monitor weakly: the content controller keeps its handlers
    /// for as long as the web view lives.
    private final class Relay: NSObject, WKScriptMessageHandlerWithReply {
        private weak var audio: PageAudio?

        init(_ audio: PageAudio) {
            self.audio = audio
        }

        @MainActor
        func userContentController(
            _ controller: WKUserContentController,
            didReceive message: WKScriptMessage
        ) async -> (Any?, String?) {
            guard let body = message.body as? [String: Any],
                  let id = body["frame"] as? String,
                  let isAudible = body["audible"] as? Bool,
                  let audio else { return (false, nil) }
            return (audio.frame(id, isAudible: isAudible, info: message.frameInfo), nil)
        }
    }
}
