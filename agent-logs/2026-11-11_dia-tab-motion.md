# Downward tabs and Dia motion reference

Date: 2026-11-11
Branch: `codex/dia-browser-polish`
Status: Recorded comparison and final motion revision complete for sidebar
create/close behavior. See the appended recording section for results and limits.
The earlier static-only section is retained as investigation history.

## Request

The user asked for tabs to open downward like Dia, better tab motion and UX,
recorded measurements, and a frame-by-frame comparison. They also requested
the Reverse Engineer Anything skill and allowed binary inspection.

## Skill and reference

Read the upstream [Reverse Engineer Anything skill](https://github.com/morluto/rea/blob/main/.agents/skills/reverse-engineer-anything/SKILL.md).
Used its distinction between static observations, inference, and runtime
evidence. The REA runtime was not installed or used. A separate read-only
analysis used installed Apple binary tools on `/Applications/Dia.app` only.
No personal browser data was inspected in that analysis.

Reference binary: Dia **1.56.2**, build **90792**, arm64.
SHA-256: `76c924d9bb5ea8e370f00329455607e31bb3f01cf2d0bd0a5014c89222a776d9`.

Confirmed static facts:

- Both `TabListCollectionViewLayout` initializers set default row height to
  **34.0 points**. Normal initializer store: `0x105cb6b4c`–`0x105cb6b58`.
- The custom appearing-item branch uses an initial alpha of **0** and a
  vertical offset of **tabHeight / 3**, or about **11.33 points** by default.
  Relevant instructions: `0x105cb6594`–`0x105cb65d0`.
- The sign depends on `revealedInsertedItemDirection`. Raw 1 subtracts the
  offset; raw 0 adds it; raw 2 uses superclass behavior. This pass did not
  establish the case used by normal new tabs or its screen-space direction.
- The custom disappearance method decreases the item's zIndex by one. Its
  inherited opacity and position behavior remain unknown.

Full evidence and disassembly are local artifacts in
`build/tab-motion-study/`, starting with `dia-static-evidence.md`.
No duration, easing curve, or actual frame pacing was recovered.

## Cove changes

- Removed the reverse order in the sidebar's Today list. New tabs now append
  downward. Tabs opened by a link still go beside their opener.
- Updated `TabLayout.displayOrder` so keyboard shortcuts, next/previous tab,
  reordering, and Close Tabs Below use the same visible order.
- Kept saved storage order and document/split positions intact.
- Changed the shared sidebar row height from 32 to 34 points.
- Sidebar insertion uses an 11.33-point offset from above plus an opacity
  transition. Removal uses opacity. Sidebar rows no longer use the top
  strip's shrinking/clipped slot effect.
- Kept the existing 180 ms tab animation token. Its timing has not been
  measured against Dia. The entry sign and exit fade are implementation
  choices pending the recording, not fully recovered Dia behavior.
- Kept the accepted Space swipe motion and loading light unchanged.

Used the animation skill for spatial continuity. The user's explicit request
for tab animation takes precedence over the skill's general rule to omit
animation on keyboard actions. Existing Reduce Motion handling disables the
tab-list animation.

## Validation

- **180 tests in 37 suites passed** after the order and motion changes.
- Updated the display-order regression test and replaced the old reverse-order
  test with checks for downward insertion, shortcuts, Close Tabs Below, and
  reordering.
- `git diff --check` passed.
- Test output: `/tmp/cove-downward-tabs-tests.log`.
- Build: `build/dia-polish/Build/Products/Debug/Cove.app`.

## Live-test blocker and remaining work

Opened a separate empty Dia reference window. Its Window menu did not list
Virtual 16:9; it offered only R27qe Gen2 as another display. The user chose
to enable Virtual 16:9 rather than test on the current display. Rechecking
the menu still showed no virtual display.

No live tab recording or frame-by-frame comparison was completed. Do not
describe the present motion as an exact Dia match. The updated Cove build
has not yet been opened for this pass's live acceptance test.

Once Virtual 16:9 is available:

1. Use isolated Dia and Cove test windows at matching sizes and scale.
2. Record new tabs, insertion after a link, close, repeated close, and drag
   interruption. Use local test pages with distinct titles.
3. Preserve the source videos and inspect actual timestamps and frame cadence.
4. Compare row positions, opacity progression, sibling motion, and the final
   layout. Confirm the New Tab control's position and long-list scrolling.
5. Tune the existing motion tokens from measured results, rerun relevant
   checks, and return the build to the user's main display.

## Recorded comparison and final revision — 11 November

The user enabled Virtual 16:9 and asked for the full recording and comparison.
The first macOS Screenshot setup selected a system dialog on the main display.
It was stopped and excluded from the measurements. After the user explicitly
approved a different capture method, a local ScreenCaptureKit helper recorded
only the selected test window. The helper requires the window to be fully
inside the display named `Virtual 16:9`; it refuses another display. Audio,
microphone, and cursor capture are disabled. All test actions still used CUA.

Both windows were **1268 × 693 points at 2× scale**. Test pages loaded from disk,
with the same text and links. Source videos, timestamps, image samples, and
analysis scripts are in `build/tab-motion-study/`. The frame viewer is
[`comparison.html`](../build/tab-motion-study/comparison.html).

### New static evidence

A second read-only pass followed the TabListView update into
`NSAnimationContext.runAnimationGroup`, then the collection data-source
snapshot apply. It establishes **0.12 seconds** when animation is enabled and
`CAMediaTimingFunction(0.25, 0.46, 0.45, 0.94)`.

- Update closure: `0x105cc3e14`.
- Duration setter: `0x105cc3eb4`.
- Curve helper: `0x1008b4cbc`.
- Snapshot apply: `0x105cc3f90`.
- Report: `build/tab-motion-study/dia-tab-timing-evidence.md`.

This used the requested REA skill's evidence workflow with installed binary
tools. No REA runtime was installed, and these are not REA-engine outputs.
The same binary hash and version recorded above were used.

### What the recordings changed

The earlier offset/fade choice was **not used by normal new-tab insertions in
the recorded Dia path**. Its presence in the binary was insufficient to select
that branch. In the first changed frame, the new row is solid and in place;
the rows below it move. Closing fades the outgoing row while the gap closes.
Dia places New Tab below the rows. Measured row pitch is **74 pixels / 37 points**.

Final implementation:

- Sidebar-only update curve: **120 ms**, exact control points above. Top-strip
  timing remains separate.
- Immediate insertion at the final position; opacity removal. No shrink or
  translation of the new sidebar row.
- **34 pt row + 3 pt gap**, for Today and Pinned.
- New Tab follows the Today list.
- Selected rows draw above moving siblings, preventing overlapping labels.
- Selection scrolls only far enough to reveal the selected row, including a
  split row. It does not take over scrolling during a tab drag.
- Existing Reduce Motion gating remains on the sidebar's structural motion.
- Accepted Space paging and loading light were not changed.

### Frame measurements

Tracking used the text's horizontal pixel gradient against a settled-frame
reference, searching for the best vertical correlation. Frame timestamps came
from ffprobe, not a claimed constant frame rate. Raw frame count matched the
PTS count. Frame extraction emitted non-monotonic DTS warnings from the rawvideo
muxer; frame order/count was preserved with passthrough and verified against
source PTS. No fabricated intermediate frames were used for measurements.

| Sample | Movement | 95% travel | Exact final pixel |
| --- | --- | --- | --- |
| Dia first insertion | 37 pt | 125 ms | 125 ms |
| Cove before | 36 pt | 220 ms | 242 ms |
| Cove first revision | 37 pt | 122 ms | 140 ms |
| Dia repeat | 37 pt | 143 ms | 165 ms |
| Cove final | 37 pt | 127 ms | 180 ms |

These values start at the last unchanged sample of the tracked row. Capture
intervals varied, generally about 17–33 ms around motion. They are frame bounds,
not exact input latency. The final sample differs by less than one typical
frame interval at both thresholds. The final single-pixel tail is sensitive to
capture cadence and antialiasing. The implementation matches the recovered
curve; this report does not claim perfect frame identity or universal 60 fps.

The side-by-side slow clip duplicates source frames for playback. The HTML
viewer instead steps through original captured frames and displays timestamps.

### Live checks and limits

- Recorded Dia: link insertion, new tab, close, middle insertion and close;
  repeated insertion/close sample.
- Recorded Cove: baseline, revised insertion/close, immediate open then close,
  15 repeated closes, final middle insertion/close, and reorder.
- Confirmed full-list bug before fix: newly selected tab was below the viewport.
  After fix, a nineteenth test tab was visibly selected at the bottom of the
  sidebar. Temporary overflow tabs were closed.
- Reordered Cove C above A and restored A/B/C. Native drag state cleared.
- The simulated Dia drag did not reorder reliably; no measured drag-parity claim.
- Page-selection policy on closing a link tab differs: observed Dia returned to
  the opener, while Cove selected the next tab. This pass preserves Cove's
  previously tested close-selection policy.
- Themes and sidebar widths differed; no pixel-identical color/width claim.
- Pin/restore feature logic was not changed or re-audited in this motion pass.
- Restored Dia's original Auto-Hide Tabs setting and closed only the temporary
  Dia test window. Cove remains running on Virtual 16:9 with A/B/C test pages.

### Final validation

**180 tests in 37 suites passed** after the final source changes.
`git diff --check` passed. Test log: `/tmp/cove-tab-recording-tests.log`.
Build: `build/dia-polish/Build/Products/Debug/Cove.app`.
No commit, push, or deployment was made.

Capture API reference used with the installed SDK headers:
[Apple SCRecordingOutput](https://developer.apple.com/documentation/screencapturekit/screcordingoutput).
The requested Mintlify context tool was not present in this session.
