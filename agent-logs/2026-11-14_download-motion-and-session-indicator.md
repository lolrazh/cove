# Download motion and session indicator

Date: 2026-11-14 (Asia/Kolkata).
Branch: `codex/dia-browser-polish`.

## Request

Use tabular download numbers. Put Downloads at the top right of the sidebar.
Show it only after a download starts in the current session. Study Dia's flying
file and fading indicator, then add that feedback to Cove. Keep small commits,
test on Virtual 16:9, and update the log.

## Changes

- Download rows already used tabular digits. The remaining movement came from
  changing digit counts and byte units. The count now has a reserved, right-aligned
  column. A known-size transfer keeps the unit selected from its total. An
  unknown-size transfer keeps kB. Progress text has no implicit animation.
- Moved Downloads out of the address toolbar into the sidebar header. The top-tab
  layout uses the right end of its tab header. An empty slot keeps the profile
  name stable before the icon appears.
- Each profile's download manager tracks session presence in memory. Restored
  records do not reveal the icon. A new transfer or retry reveals it for that
  session. Clearing records does not reset the session flag.
- Shift–Command–J still gives access to saved files before the first new download:
  it opens Downloads in the Library. After a download starts, it opens the compact
  header popover.
- A file icon lifts from the clicked link, follows a curved path, and shrinks into
  Downloads. The arrow responds at arrival. Its soft highlight decays over three
  seconds; the icon itself remains available for the session.
- The flight uses Core Animation on a pass-through window overlay. It does not
  own download state, move tabs, reload pages, or bring a window forward. Events
  carry their source window. There is no replay when changing profiles.
- A burst has at most four active flights and four pending events. Extra feedback
  has no flight backlog. Each event keeps its click position. Reduced Motion
  skips the flight and uses a short highlight fade.
- A hidden sidebar reveals for the flight, waits for its header to settle, then
  closes after the landing hold unless another interaction keeps it open. The
  list does not open automatically at download start.

## Dia reference: facts and limits

Applied the reverse-engineer-anything and animate skills. REA's tools and engine
were unavailable. Used ordinary read-only static inspection of the installed
Dia 1.57.1 binary, plus virtual-display recordings. No binary patch or recovered
source was used.

Binary SHA-256:
`45e2c890c0edbd0645c71d2a2b6bb8e87972244423da2becd27ba26d2cd6d4ec`.

- `DownloadMagnetAnimationView` has source and destination screen points, a file
  view, particles, and a spotlight. It uses a separate `DownloadMagnetWindow`.
- The file animation shares one generated duration across position, transform,
  opacity, and three shadow channels. A 1/60-second generator sample interval is
  present. This is not a measured display refresh rate.
- The Downloads button has a separate progress view and highlight view. Two
  code paths use a three-second opacity/spring decay. Their event mapping was
  not resolved. This is not evidence that the icon hides after three seconds.
- Feature strings include an animation switch and a theatrical-play counter.
  Their current values were not established.
- The native reference recording shows the landing/indicator response. It does
  not establish an exact full-flight duration. Cove's 620 ms flight, 170 ms wait
  for a hidden header, and 800 ms landing hold are deliberate implementation
  choices, not claimed Dia constants. Cove's fade uses ease-out, not Dia's exact
  spring. No frame-for-frame parity claim.

Static details and bounded disassembly are in
`build/download-motion-study/static-findings.md` and the adjacent annotated files.
The Mintlify context tool was not available. Native API work used the existing
project patterns and installed SDK.

## Tests and corrections

Final suite: **198 tests in 47 suites passed**. Build succeeded with Xcode and
`CODE_SIGNING_ALLOWED=NO`. Added coverage for unit/column stability and for saved
history not showing the session indicator.

Virtual 16:9 was display 5 at `(1710, 0, 2560, 1440)` points, scale 2. Both test
windows were fully within it. Used the previously approved virtual-only capture
helper. A display crop, rather than a browser-window-only filter, includes Dia's
separate animation window. Captures exclude the computer-use software cursor.

| Check | Result |
| --- | --- |
| Fresh app session with saved history | No header icon, including in the accessibility tree |
| Shift–Command–J before a new download | Existing records remain accessible in Library |
| New slow download | Header icon, progress ring, stable count and unit |
| Two small downloads in quick succession | Both completed; no stuck flight or duplicate rows |
| Hidden sidebar | Reveals, file lands on its settled header, sidebar closes again |
| Switch to Space 2 and back | No icon in the untouched profile; Personal retains its session state |
| Unknown total | kB count stays in its reserved column |
| Cancel, then retry | Immediate cancellation; retry keeps the row and completes |
| Completed file | File on disk has the expected size and hash |

Frame review found and fixed three issues before the final commit:

1. A global cursor query could select the page center during background computer
   input. A local mouse event now supplies the clicked link's position.
2. A main-window guard discarded feedback when focus changed before the response
   arrived. Feedback now stays with its visible source window without activation.
3. The first anchor during sidebar reveal was still outside the window. The flight
   now waits for the existing 140 ms reveal motion to finish before taking its
   destination. Final sampled coordinates were `(130, 215)` to `(204, 20)` points.

The final small file is 76 bytes, SHA-256 prefix `77c81169d5909046`.
The slow and retried unknown-size files are each 1,048,576 bytes, SHA-256 prefix
`32ba732d9fc7a392`.

The final build remains on Virtual 16:9 with Downloads open. Cove's test tab was
closed and the prior Spoke page restored. The local server and all recorders were
stopped. Test files and records remain for review. Dia's virtual reference tab
remains; its other active window was left alone.

## Evidence

Under `build/download-motion-study/`:

- `dia-pointer-flight.mov`: native Dia reference with direct pointer input.
- `pointer-detail.png`: sampled indicator/landing frames from that recording.
- `cove-verified-motion.mov`: repeated downloads and initial hidden-sidebar review.
- `cove-shipping-motion.mov`: final committed build, hidden-sidebar flight and
  unknown-size cancel/retry interactions.
- `cove-shipping-flight-frames.png`: 15 fps samples around the corrected flight.
- `cove-shipping-contact.png`: reveal, landing, and return to the hidden state.

Recordings have variable frame timestamps. No claim is made from the container's
nominal frame-rate field. Physical hover, Reduce Motion's system setting, and
full-screen/multi-window motion were not tested in this pass. Earlier download
flow coverage is recorded in `2026-11-13_download-flow.md`.

Test log: `/tmp/cove-download-motion-final-tests.log`.
Result bundle:
`build/dia-polish/Logs/Test/Test-Cove-2026.11.14_00-23-33-+0530.xcresult`.

## Small commits

- `56fa839` — fixed number columns and units.
- `4947f24` — session-only indicator in the sidebar header.
- `91cd33a` — source-window flight, landing feedback, and reveal handling.
- This log update is a separate commit.

The unrelated untracked `prototypes/` directory was not changed.
