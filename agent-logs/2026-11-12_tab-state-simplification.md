# Tab-state simplification — 2026-11-12

The user reported continued instability and asked for clean, minimal code.
“Motion A” through “Motion G” were local measurement pages from the previous
recordings, not animation settings. Leaving them open caused confusion.

## Source review

Reviewed Ardia at commit `e8cabcece1d394726ba60d9b0fb56193d835d20a`:
https://github.com/ardia-browser/ardia/tree/e8cabcece1d394726ba60d9b0fb56193d835d20a

Relevant source paths:

- `apps/browser/src/state/tabs/tabs.ts`: removal computes remaining tabs and
  valid successor selection together.
- `packages/ardiacore/ios/ArdiaWebView+Tab.mm`: explicit native attach/detach
  ownership; removes a view only if it still belongs to that host.
- `packages/ardiacore/ios/ArdiaTabParking.mm`: native page retention and parking.
- `apps/browser/src/components/sidebar/ListMotion.tsx`: a separate list-motion
  system. It is substantial, not a small component suitable for copying to Cove.

Ardia uses a different engine and UI stack. No performance claim was independently
verified. No Ardia source or dependencies were copied into Cove. The local Emil
Kowalski design-engineering skill informed the decision to remove animation from
frequent page-selection actions rather than keep adding render coordination.

## Changes

| Before | After | Why |
| --- | --- | --- |
| 283-line page wrapper with snapshots, fade phases, deadline tasks, progress observers, and blocked input | 90-line wrapper with one selected live child | Selection does not wait for loading or animation |
| Queued render callbacks could outlive the selected tab | No page-render callbacks or snapshot requests in the host | Remove the race and render overhead |
| A delayed click could assign a removed tab ID | `selectTab` verifies that the tab still exists | Prevent an invalid active tab and empty content branch |
| Animated scroll on every selection plus list movement | Reveal the selected row directly | Avoid competing movement |
| Toolbar background fades while its text/icons change immediately | Toolbar color and contrast change together | Avoid intermediate mismatched colors |

The loading glow, profile swipe behavior, sidebar spacing, and per-document color
cache remain. No additional animation library or generalized state framework was
added. Focus/dialog notification still runs after SwiftUI updates the view tree,
with a revision check that rejects old A→B→A callbacks. A previous host removes
only its own children, so dismantling a split cannot detach a moved page.

## Tests

Replaced tests of the deleted render scheduler with behavior tests:

- 200 immediate page switches in an attached NSWindow, with one live child and
  no input blocker after every switch.
- Moving a page between hosts, then dismantling the old host.
- Late appearance callbacks, including A→B→A, repeated unchanged updates, and reset.
- Moving the host between windows.
- Existing real-WebKit document-color and cache tests retained.

Added tests through the actual TabManager:

- A selection event for a closed or unknown ID cannot clear the current tab.
- 20 open/close/reopen/close cycles. Every published selection and Today list
  contains a valid active tab. The manager ends with one usable tab.

HistoryStore and FaviconStore now accept an optional database path so this test
uses in-memory databases. Pins, archive, and boosts are in memory; WebKit uses a
private context. Tests use separate UserDefaults and do not alter user data.

Full Debug test run: **185 tests in 39 suites passed**. The count is lower than the
previous run because tests of the removed scheduler were deleted and replaced.

Result bundle:
`build/dia-polish/Logs/Test/Test-Cove-2026.11.12_13-31-17-+0530.xcresult`
Console log: `/tmp/cove-tab-simplify-tests.log`.

Visual testing and handoff are recorded below after completion. No claim is made
that this is a full-codebase audit or that unit tests prove all websites stable.

## Virtual-display checks and handoff

Tested the built app on Virtual 16:9 (display 5). The approved recording helper
captured only the Cove window on that display. UI input used computer use.

- 40 switches between two loaded white Wikipedia pages in 3.458 seconds:
  `build/tab-motion-study/cove-simple-white-pages.mov`. All 907 recorded frames
  passed the toolbar probe; zero dark toolbar frames. The full-content probe
  found no uniform empty content frames.
- 30 switches between dark Example Domain and white Wikipedia in 2.751 seconds:
  `build/tab-motion-study/cove-simple-light-switches.mov`. The filename predates
  confirmation that Example Domain renders dark. Dark toolbar samples here are
  expected. The content probe found no uniform empty frames.
- Closed eight loaded tabs in 2.401 seconds, then ran ten reopen/close pairs in
  2.324 seconds: `build/tab-motion-study/cove-simple-live-closes.mov`. The app
  returned to the correct GitHub page and remained responsive. No crash or
  persistent blank window was observed.

The reopen recording does contain blank content frames. Inspection of frame
1220 (`simple-cold-restore.png`) shows the reopened Wikipedia tab with a loading
indicator and cached light toolbar, while its page has not painted yet. Reopening
creates a new live page and loads it again. This pass does not eliminate that
loading interval, and it must not be reported as a zero-blank-frame result.

Frame checks are screening measurements, not a guarantee for all websites or
hardware. Source capture requests 60 fps but produces variable frame timing.
Checks: `build/tab-motion-study/state-frame-results.json` and
`build/tab-motion-study/simple-content-results.json`.

Closed the temporary test tabs, including the old local Profile and color test
page. Left the Ardia repository open. Moved Cove to Built-in Retina Display and
verified that the Window menu then offered Move to Virtual 16:9. Dismissed the
menu and confirmed rendered GitHub content for the user's test.
