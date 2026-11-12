# Tab state and page-color cache — 2026-11-12

## User report

Rapid tab closes left the window blank. Close/open animations collided. The
address bar flashed black between light pages. The user asked to keep a cached
page color until the document changes.

## Changes

- Select a valid neighboring tab before removing and archiving the active tab.
  The active ID no longer points at the removed tab during archive work.
- Make each page selection replace any pending presentation. A new selection
  settles and replaces a running fade instead of waiting behind it.
- Allow only one WebKit snapshot in flight per page host. Ignore old snapshot
  and animation completions. They cannot detach the latest page.
- Limit preparation to 120 ms. On timeout, reveal the live destination and
  release input. A network load or missing snapshot can no longer keep the
  window blocked indefinitely. Only a loaded document can supply a fade image.
- Reset the host on dismantle. Settle preparation when the host loses its window.
- Remove a closed sidebar row immediately while keeping the 120 ms movement of
  the remaining rows. This removes the outgoing label that could overlap a new row.
- Replace `underPageBackgroundColor` KVO with a main-frame document signal in
  WebKit's isolated client world. Resolve HTML/body background colors to sRGB,
  including transparency over the document's light/dark canvas.
- Keep the resolved color in the tab. Update it on root/body attribute changes,
  stylesheet/head changes, stylesheet loads, theme-media changes, resize,
  completed root/body transitions, and history page restoration. Coalesce work
  and publish only when RGB changes. Tab selection and view attachment do not
  trigger a color calculation.
- Add a bounded, in-memory cache of 128 document URLs per browsing context.
  Reopened tabs use that cached color immediately, then accept actual document
  updates. Profiles and private contexts do not share this cache.
- Reject queued KVO and navigation callbacks from replaced web views.

## Tests and the issue caught by recording

The original host tests never attached an NSWindow. They took the immediate path
and did not cover snapshot/fade behavior. Added tests use a real attached window
without displaying it. They cover 40 replacements in one burst, stalled snapshots,
late render and fade callbacks, detachment, and input release. A real WKWebView
also tests document color, attachment without republishing, style changes, and a
`data-theme` attribute. Cache tests cover replacement, bounds, and isolation.

The first revision passed its tests but the recording caught another fault:
reopened tabs lost their color and a still-loading page could supply a blank fade
image. The first close/reopen recording had 59 dark-toolbar frames. Eight frames
also fell below the heading's dark-pixel threshold; inspection showed a faint
old heading fading toward an empty incoming image, not proof of a crashed window.
The final changes retain colors across tab recreation and require loading to
finish before taking the fade image. The bounded fallback remains.

Final command:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project Cove.xcodeproj -scheme Cove -configuration Debug \
  -derivedDataPath build/dia-polish test CODE_SIGNING_ALLOWED=NO
```

Result: **187 tests, 39 suites passed**. `git diff --check` passed.
Test result: `build/dia-polish/Logs/Test/Test-Cove-2026.11.12_00-54-20-+0530.xcresult`.
Full console log: `/tmp/cove-tab-state-tests.log`.

## Computer-use evidence

All interaction used computer use. All recordings used the previously approved
virtual-only ScreenCaptureKit helper on **Virtual 16:9**, display ID 4. Capture
had no audio. No main-display recording was used.

- 18 quick selections across loaded light pages: 583 source frames, no dark
  toolbar frames and no frames without dark heading pixels.
- First close/reopen pass: eight closes in 1,345 ms; ten reopen/close pairs in
  2,612 ms. This exposed the cache loss described above.
- Final pass: eight closes in **1,168 ms**; ten reopen/close pairs in **2,468 ms**.
  The app returned to Motion C, responded to input, and retained the four
  pre-test tabs. Eight disposable Motion D tabs were removed.
- Final pass: **1,295 source frames**. No dark-toolbar frames. No frames without
  dark heading pixels. The minimum sampled toolbar RGB was (231, 237, 241.5).
  The minimum heading dark-pixel count was 704 at quarter resolution.
- Sampled sidebar frames show closed row labels leaving without overlapping the
  replacement. The New Tab control continues its existing downward/upward motion.

Artifacts in `build/tab-motion-study/`:

- `cove-state-switches.mov`
- `cove-state-closes.mov` — first pass; contains the caught defect
- `cove-state-final.mov` — final close/reopen pass
- `check-state-frames.py` — decodes every source frame, preserves frame order
- `state-frame-results.json` and `*-frame-checks.json` — measurements and timestamps
- `state-worst-before.png` — caught dark toolbar and faint heading
- `state-sidebar-final.png` — source-frame contact sheet

The capture requests 60 fps; actual source timestamps are variable. The pixel
checks sample the address-bar fill and heading region on local light fixtures.
They do not prove that every website is free of flashes. No native process crash
was reproduced or diagnosed. A genuinely unpainted new page can still show its
loading surface after the 120 ms preparation deadline. The color cache is
session-only; it is not persisted across app restarts. The document signal does
not intercept arbitrary CSSOM method calls or continuously sample animated colors.

The Swift skill guided the state/callback work. The requested Mintlify context
tool is not available in this session. Existing project patterns and the installed
WebKit SDK were used. No extra binary reverse engineering was needed for this fix.

## Handoff

Opened the latest tested Debug executable and moved its browser window to the
Built-in Retina Display (the main display used for the earlier handoff). Verified
that Window now offers Move to Virtual 16:9, closed the menu, and left Motion C
ready for manual testing. The original four tabs remain. No commit or push made.
