# Tab review

Date: 2026-11-11
Branch: `codex/dia-browser-polish`
Base: `c49487a`
Status: Local changes; no commit, push, or release.

## Request

The user confirmed that the next feature review should cover tabs: create,
close, reorder, pin, group, and restore. This follows the accepted loading
light and Space motion work in the
[session log](2026-11-11_profiles-themes-and-motion.md).

## Fixes

### Closing the newest tab selects its neighbor

With Today tabs A, B, and C, closing the newest tab C selected A in the sidebar.
The intended fallback was the next older tab B. The old code used the last
item in display order, which is the oldest Today tab in sidebar mode.

Added `neighborWhenClosing` in `TabOrder.swift`. `TabManager.closeTab` now
chooses the next tab in stored order, or the previous tab when closing the
last one. A neighboring split pane still takes priority. The pinned-tab
fallback remains when no Today tab is available.

Two regression tests cover end, middle, first, lone, missing, and empty cases.
The live check also confirmed that closing the newest tab selects the adjacent
tab and that Command-Shift-T reopens the closed tab.

### Clear drop areas when a drag ends outside the list

The Favorites drop area could remain on screen after a drag was cancelled.
Cleanup depended on destination drop callbacks, which do not run for a
cancelled drag or a drop outside that destination.

The drag source now uses an identifiable `Transferable` item containing its
UUID. The custom transfer type remains restricted to Cove's own process.
The tab-list container observes drag-session changes and clears the drag ID
when the session ends. The container remains in place while its rows move.
Tab, folder, and section drop delegates still perform their existing moves.

API details were checked in the installed macOS SDK and
[Apple's drag-session documentation](https://developer.apple.com/documentation/swiftui/view/ondragsessionupdated(_:)).
The requested Mintlify context tool was not available in this session.

Temporary phase logging confirmed an ended/cancel event and an ended/move
event. The temporary logging was removed before the final test run.

## Live checks

Used computer control on Virtual 16:9. Created an isolated **Tab review**
Space and local fixture pages A, B, and C. The fixture server listens only on
`127.0.0.1:18768`; its script is `/tmp/cove-tabs-preview.py`.

- Create tabs with Command-T and load distinct pages.
- Close with Command-W; reopen with Command-Shift-T.
- Rename a tab to Review B and retain the name after restart.
- Duplicate a tab, then rename the copy to Duplicate B.
- Pin, unpin, and return a navigated pin to its saved page.
- Create and name Review folder; drop a tab into it; collapse and expand it.
- Reorder Today tabs in the sidebar and in the top strip.
- Select tabs with Command-number shortcuts in the top strip.
- Preserve tab order, custom titles, pinned pages, and folder state on restart.
- Clear temporary drop areas after a completed drop and after cancellation.

Computer-use drag calls sometimes left the native drag session active.
A coordinate click completed the drop, or Escape cancelled the session.
The resulting state was checked after the end callback. This does not measure
physical drag smoothness or prove exact Dia motion parity.

One restart stalled during shutdown. A process sample showed the main thread
waiting in pasteboard promise resolution. Activity Monitor was used to recover
the unresponsive Cove test process. The drag tool had left a session active;
the cause is not established as a separate product defect. Later normal
quit/relaunch checks after completed sessions succeeded. No general shutdown
fix is claimed.

## Final validation and handoff

- **180 tests in 37 suites passed.**
- `git diff --check` passed.
- Final result:
  `build/dia-polish/Logs/Test/Test-Cove-2026.11.11_02-00-14-+0530.xcresult`.
- Console log: `/tmp/cove-tab-review-tests.log`.
- Build: `build/dia-polish/Build/Products/Debug/Cove.app`.
- The final build reopened with Tab review, its folder, and its tabs restored.
- Saved `build/tab-study/final-sidebar.jpg`, then moved Cove back to Built-in
  Retina Display. Closed the Activity Monitor window used for recovery.
- The accepted loading light and Space swipe motion were not changed.

The test Space remains for the user. The next manual check is a slow tab drag,
a quick reorder, and cancellation outside the sidebar. Physical motion feel,
dragging across windows, and more complex nested-folder cases remain outside
this pass.
