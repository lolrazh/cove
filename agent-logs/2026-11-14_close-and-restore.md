# Close and restore — 2026-11-14

## Request

Compare close and restore with Dia in a new window on Virtual 16:9. Test rapid
commands, keep small commits, and record the findings.

## Reference

Created a separate Dia window on Virtual 16:9 and used local A–E test pages.
Closing the selected middle tab selects the next page. Reopen restores the
closed page to its original position. Repeated closes and restores preserve
the list. Dia also retained a named form input and back history in this fixture.

Used the reverse-engineer-anything skill against Dia **1.57.1 / 90935**.
The installed binary changed since the previous study, so the native evidence
was checked again. Its tab snapshot path requests **120 ms** with cubic curve
**(0.25, 0.46, 0.45, 0.94)**. A departing row is placed below its neighbors.
These findings do not imply a delay or a command throttle.

REA 6.9.0 could inspect the app plist. Its doctor reported registration drift
and no native deep-analysis engine. Native code evidence came from installed
Xcode LLVM tools and Mach-O metadata, not an REA deep-engine decompilation.
No Dia code or assets were copied. No tool configuration was changed.

Local evidence: `build/close-restore-study/dia-close-restore-static.md`,
`dia-native-proof.json`, and `dia-middle-burst.mov`. The report records the
binary hash, addresses, evidence ID, and limits of each finding.

## Changes

- Restore a closed regular tab to its original Today slot in the same live
  window. A restore in another window or after a restart appends instead of
  applying an unrelated index. Existing archive databases migrate in place.
- Remove the untouched start page when undoing the last page's close. Keep a
  start page that has forward history.
- Keep custom names after archive reload. Use the database row order to break
  equal close timestamps consistently, including archive trimming.
- Limit the sleeping-tab fade to opacity. The old whole-row 250 ms animation
  also slowed movement when closing a tab woke its neighbor. Structural motion
  keeps the existing short curve and complete-row geometry boundary.
- Save the closed page's latest WebKit state after it becomes hidden. The
  initial archive entry is available immediately. A pending save can reuse the
  live page for immediate undo. Pending work is limited to eight pages and one
  second per page; completion, removal, trimming, and timeout release it.
  Media is suspended and camera/microphone capture is stopped while pending.

### Form-state race

The first live test lost a named form input when the active tab closed. Closing
the same page from the background kept the input. A view-detach callback and
simple JavaScript round trip were insufficient: a temporary trace proved
WebKit still reported the detached page as visible and returned stale state.

The final code waits for the actual hidden event in an isolated WebKit content
world, then makes one further round trip. The trace changed from 1189 saved
bytes to 1245 after hiding. The restored page then retained the confirmed input.
Two immediate close/undo cycles also kept an edited input. No DOM form scraping,
history mutation, private WebKit API, or long-lived closed-page cache was added.
Temporary diagnostics were removed. Before/after traces and findings are under
`build/close-restore-study/visibility-*`.

## Motion check

Recorded Cove before and after on Virtual 16:9. Tracked the same D1 title suffix
through a 37 pt upward move after closing B1. The interval from the last
stationary captured frame to the settled position fell from about **197 ms**
to **103 ms**. From the first moving frame, the intervals were about 173 ms
and 78 ms. Captures have variable frame intervals; these are samples, not exact
animation durations or proof of frame-identical behavior.

The final sampled frames keep the title and favicon together. No row collision
was visible in that close. The code does not wait for an animation to finish
before accepting another close or restore.

Local files: `cove-after-row-track.json`, `cove-final-row-track.json`,
`cove-final-close-frames.png`, and `close-comparison-final-slow.mp4` under
`build/close-restore-study`. The comparison is quarter speed: Dia on the left,
Cove on the right. It compares selected middle-row closes; the tab letters,
sidebar widths, and themes differ.
The small comparison clip is also kept at
[`artifacts/close-restore-comparison.mp4`](artifacts/close-restore-comparison.mp4).

## Verification

Short lists, a 16-tab list, three- and six-command bursts, exact restored order,
and private-window last-tab undo passed live checks. An 11-command reopen burst
also restored all 11 fixture entries. Restoring a scrolled B2 page kept its 0.5
scrollbar position, and Back returned to B1. Active-form and immediate-undo
checks passed after the hidden-event fix. These are local fixture checks,
not a guarantee that every website preserves arbitrary application state.

The final focused suite passed **31 tests in 4 suites**. It covers rapid
selection validity, original slots with interleaved notes, other-window restore,
start pages with forward history, archive migration and ordering, repeated
undo/reclose with late callbacks, callback rebinding, removal/trimming, the
eight-page limit, and the one-second timeout. The form-state race is verified
by the live visible-page test; the never-shown unit-test host cannot reproduce
that visibility transition.

Commits: `e1e709d` archive names/order, `a2e5715` restore position and start-page
handling, `4db229c` bounded pending saves, `d3229c1` scoped wake opacity, and
`4c12384` actual hidden-event barrier. This log and the short comparison clip
are a separate commit.

## First final-build check and cleanup

The final full suite passed **211 tests in 47 suites** in 13.975 seconds.
Log: `/tmp/cove-close-restore-final-tests.log`. Result:
`build/dia-polish/Logs/Test/Test-Cove-2026.11.14_11-32-50-+0530.xcresult`.

Relaunched the clean `build/dia-polish` Debug app on Virtual 16:9. A six-close,
six-restore sequence returned all 16 fixture tabs in order and retained the
confirmed `Clean build F2 draft` input. Recording:
`build/close-restore-study/cove-clean-burst.mov`. Computer-use key delivery is
variable; the automated synchronous race tests cover commands without pauses.

Restored all fixture archive entries, then checked that an Archive search for
`127.0.0.1:8772` had no results. Closed only Cove's separate fixture window;
the original user window and download preview remain. Removed only our fixture
tabs from the new Dia window. Another workflow had added a page there, so that
window was kept. Stopped the fixture server and recordings. No user tabs were
closed. The previous download-preview server on port 8771 remains available.

## Cold-page follow-up

Review of the longer final recording exposed a dark canvas and toolbar before
sleeping pages loaded after restart. This was not a tab-order failure. The
resolved color cache was memory-only, and new WebViews used the system canvas.

Commit `8611739` adds an optional 24-bit RGB value to `SavedTab` and a nullable
archive column. A restored page uses the current browsing-context cache first,
then its saved color. Its new WebView receives that color before loading. Real
document color changes update the canvas, toolbar, and saved session. Existing
sessions and archives still load. No old-page screenshot or render delay was
added. Pinned-tab storage is separate and is not changed by this fix.

The focused suite passed 33 tests. Added checks cover legacy JSON, saved-color
round trips, archive migration, initial WebView canvas color, and a real
style-only page change that updates the saved color.

The saved canvas color fixed the toolbar, but an archived page could still show
WebKit's dark initial canvas. A backing fill behind the native view did not help
and was removed. The final change (`f02e228`, `b5e0238`) keeps the known page
color over a newly created WebView until the document reports its surface.
`didFinish` provides a fallback for PDFs and pages without JavaScript. Existing
WebViews do not restart this cover during normal navigation. The cover does
not intercept input, hide the loading line, or wait for a fixed timer. Stale
callbacks cannot change the state of a newer WebView.

Checked two fixed background patches in every captured frame: page
`(1600, 1100, 32, 32)` and toolbar `(1600, 35, 32, 20)`, in source pixels.
These fixtures have a light page background. Gray values below 160 identify
the dark failure here; they are not a general website-quality metric.

| Capture | Frames | Dark page frames | Dark toolbar frames |
| --- | ---: | ---: | ---: |
| `cove-clean-burst.mov`, before color persistence | 2459 | 173 | 87 |
| `cove-cold-colors.mov`, persisted color only | 998 | 61 | 0 |
| `cove-first-content.mov`, final handoff | 748 | 0 | 0 |

The final page patch stayed at gray 246 throughout. The sequences and lengths
differ, so this is a regression check, not a timing benchmark. The final test
restarted Cove with A/B/C, closed into cold B and A, then restored B and C. AX
confirmed the order; the final screenshot confirmed visible C content, with
the cover removed. Raw videos, `check-surfaces.py`, and `*-surfaces.json` are
local under `build/close-restore-study/`.

The full-suite rerun also exposed a timing assumption in the pending-save test.
Commit `08b384e` captures the one-second deadline when closing, rather than when
the queued task starts. The test yields until scheduled cleanup runs, with a
bounded test timeout, and still checks all pages are released and undo creates
a new session. The subsequent full suite passed 213 tests. Final combined-build
results and cleanup are recorded below.

## Completion

The combined final build passed **213 tests in 47 suites** in 11.284 seconds:
`/tmp/cove-close-restore-complete-tests.log`, result
`build/dia-polish/Logs/Test/Test-Cove-2026.11.14_11-56-09-+0530.xcresult`.
The lifecycle tests include reuse of an existing WebView, stale old-view
callbacks, and the non-scripted-document fallback.

Closed the second fixture window after restoring its A/B/C tabs. Stopped its
server and recording, then relaunched the exact final build. The original Cove
window and its tabs remain open on Virtual 16:9. The download-preview server
remains available. All implementation and log changes are small commits on
`main`; the work is pushed to GitHub.
