# Tab groups — 14 November 2026

## Request

Add Dia-style tab groups. Study automatic membership, naming, icons and motion. Compare Ardia's source. Keep groups within one profile, preserve tabs, use the pinned-tab color field, make small commits, and test on Virtual 16:9.

## Reference evidence

- Dia 1.57.1: a separate test window on Virtual 16:9, with local public test pages on port 8774. The user's original Dia window was not used for the tests.
- A first Command-click makes a group containing the source and child. Further children join it, including a different hostname. A foreground target-blank link joins an existing group. A fresh target-blank link and `window.open` from an ungrouped tab leave tabs separate. Command-T also makes a separate tab.
- A collapsed group retains the active row. Closing all children dissolves the automatic group and leaves the original tab. A manually created one-tab group remains.
- Command-click on sidebar rows selects multiple tabs without changing the page. Some Dia AX actions returned stale/offscreen targets; screenshot-based clicks were used for the group header and selection.
- Recorded `build/tab-groups-study/dia-groups.mov` and `dia-fold.mov` using the approved virtual-only window recorder. No audio. Recording timestamps are used, not an assumed constant frame rate.
- Native analysis traces automatic title/icon generation through `BoostLLMClient._fetchResponse`, returning a title and emoji. Membership has separate local state. The active model and live transport endpoint remain unknown. A GPT-3.5 catalog symbol alone is not proof of the active model.
- Ardia source pinned to `fbe26ec098574e97b53f138b9fa2a67c54fdcb90`. Names use local title/domain rules; icons default to a member favicon. Background link opens create automatic groups when enabled; foreground children join existing groups. No same-host restriction. Pins remain outside their child groups. Source review only; no Ardia runtime claim or copied implementation.

Primary references:

- https://www.diabrowser.com/release-notes/1-19-0-tab-groups-and-proactive-suggestions
- https://www.diabrowser.com/release-notes/1-13-1-new-year-new-polish
- https://www.diabrowser.com/release-notes/1-10-1-year-end-release
- https://github.com/ardia-browser/ardia/tree/fbe26ec098574e97b53f138b9fa2a67c54fdcb90

Detailed local evidence: `build/tab-groups-study/dia-group-static.md`, `ardia-groups.md`, and `dia-group-motion.md`. These reports separate source facts, runtime observations and unknowns.

## Implementation

- Groups are metadata over flat Today order. Existing pinned folders and page hosts are unchanged.
- Group membership, name, icon and collapse state persist per window/profile. Old saved data needs no migration step and defaults to no groups.
- Explicit link intent controls automatic grouping. Duplicates, extensions and ordinary new tabs do not accidentally trigger it.
- Command/Shift selection is separate from the active page. Group actions and drag moves work with selected tabs; a split moves as one unit.
- Group panels reuse the pinned favicon color field. The favicon stays crisp; the selected member has a dark inset fill. Header controls use a native button and context menu. Motion uses existing fast sidebar tokens and respects Reduce Motion.
- Names are local: clean the page title, use a shared title prefix when present, and fall back to the hostname. Manual names take precedence. No title, URL or page text is sent to an AI naming service.
- Stable saved tab IDs preserve group membership when a closed tab is restored after restart. Duplicate tabs receive a new ID.

## Validation

- Full suite: **229 tests in 50 suites passed**. Output: `/tmp/cove-tab-groups-complete-tests.log`; result: `build/dia-polish/Logs/Test/Test-Cove-2026.11.14_16-45-47-+0530.xcresult`.
- Final UI build passed after the fold/drop and clipping changes: `/tmp/cove-group-final-build.log`.
- Virtual runtime checks passed: fresh Command-click groups; source page keeps focus; foreground Command-Shift-click joins the existing group and selects its page; cross-host children; ordinary Command-T stays outside; manual group creation from selected tabs; manual singleton survival; group collapse retaining active row; rename while collapsed; profile switch away/back; complete app restart; group close and two restores; four successive child closes and four restores recovering all five members and their order; dragging out and back through a member row.
- Multi-selection was verified in the running app: Command-click adds selected traits without changing the web page. Header Command-click selects its members without collapsing. The tests also cover Shift ranges and all visible split panes.
- Input checks caught missing native Command-click routing and late global modifier reads. Modified links now route before navigation. SwiftUI gestures capture tab-selection modifiers with the event.
- State review caught noncontiguous group order, stale selections after focus changes, sleeping pins waking on group close, and missing autosave signals for late child tabs in parked profiles. Each has a regression test.
- Frame review of `cove-fold.mov` found New Tab moving before the group, causing a brief overlap. The corrected implementation animates the whole list on collapse state changes and fades inserted group rows. The 120 ms token remains unchanged.
- Direct drops on the header needed a separate fix. The header now owns its drop target and can recover the exported tab ID after the drag session clears hover state.

### Final virtual checks

- After unlock, the corrected fold recording confirmed that the loose tab and New Tab move together with the group. Their spacing remains 37 pt throughout the measured collapse. The active row and header stay stable; no blank page flash was visible.
- Frame inspection found fading child text outside the shrinking surface. The group now clips its contents to the same 14 pt rounded shape as its surface.
- Direct header drop passed with the user-approved virtual-only drag helper. The helper checked the named display, app identity, exact test-window frame and every event position. Its path crossed into the page, then entered the header without crossing member rows. The group grew from five to six tabs; the active Notebook Research page did not change.
- Standard computer-use drag left a native drag session open. Escape cancelled it. This is why the approved helper was used; an attempted computer-use drag alone is not counted as a pass.
- Final clipping recording: `build/tab-groups-study/cove-fold-clipped.mov`, with a captured collapse and expansion. Frame review confirms that the clipped rows no longer paint over the loose tab or New Tab. Source-frame review is recorded separately alongside the capture.

- Closed the owned test window after verification. The original Cove and Dia windows remain intact. Stopped the port 8774 fixture server.

### Evidence limits

Dia's recorded main travel is about 100–130 ms with a small settling tail near 300 ms. Cove uses its established 120 ms sidebar curve. The Cove recording was about 25 fps with some longer gaps, so it cannot prove a frame-identical match. Cove also keeps its tighter 37 pt row pitch; Dia measured 41 pt. Naming is local fallback logic, not Dia's LLM naming service.

### Skills and source boundaries

Used reverse-engineer-anything for the native/reference study, write-swift for value-state modeling, and animate/better-ui for motion and surfaces. Independent source and frame-analysis scopes were delegated as directed by the REA workflow. Mintlify context was not exposed in this session; gesture API checks used the installed SwiftUI SDK and Apple's official documentation.
