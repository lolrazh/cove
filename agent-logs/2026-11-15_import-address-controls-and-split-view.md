# Browser import, address controls, folders, media, and split view

Date: 15 November 2026. Work on `main`, in small commits.

## Delivered

- File → Import Browser Data and the same Command Bar action open a compact source → review → result flow. A new installation can skip this step. Existing installations do not get a new forced welcome screen.
- Source choices: Safari, Chrome, Dia, and Other browser. The native picker accepts a selected profile folder, bookmarks export, or history file. Data is not read before selection. The review shows the destination profile, counts, category choices, and source errors.
- Bookmarks support Safari plist, Chromium JSON, and Netscape HTML exports. Nested folders are kept. They become pinned tabs and folders in the selected Cove profile; no new Favorites or Spaces model was added.
- History supports Safari and Chromium/Dia SQLite visit records, including an open source database's WAL. Source files are opened read-only. Imported visits are written in one transaction. Repeating an import skips existing URL/date pairs. Bookmarks also skip saved URLs and empty duplicate folder shells.
- The destination profile is captured before the picker opens. A deleted destination fails with a clear message. Import does not switch profiles, change history preferences, or read passwords/cookies. History-off status is explained in the review.
- Save Page, Site Settings, and Split View now sit on the right of the address field. They reveal on hover or keyboard focus and stay visible while their panel is open. The Save Page panel uses the current profile's pinned tabs and folders.
- Each split pane owns its navigation bar and close action. Single and split pages use the same keyed page deck, so surviving WebKit hosts stay in place through layout changes. Pane changes use a short spring (response 0.34, damping 0.88), with Reduce Motion support. These are Cove tuning values, not recovered Dia values.
- Split controls include add, rotate, equal sizes, and separate. The divider is 10 pt wide, with a subtle handle and double-click equal sizing. Drag bounds target 220 pt per pane where space permits and remain valid in smaller windows. Narrow panes use compact navigation and retain room for their address.
- Folder rows fold immediately. Rename is in the context menu and accessibility actions, so a double-click delay no longer slows folding. Renaming cannot also collapse the folder.
- Media controls have separate title/open and close buttons, compact text, explicit labels, and Reduce Motion support. Ended media is no longer shown as playing; a paused frame cannot replace another frame that is still playing.

## Reference research

Used reverse-engineer-anything, better-ui, and animate. The REA skill called for independent research scopes; the import source study, Dia binary study, and media/folder work were separated. The Mintlify context tool was not exposed in this session. No new API setup was based on an unverified web snippet.

Ardia main was pinned to `82847d45128833bd84003a416449510813dd1f22`:

- https://github.com/ardia-browser/ardia/blob/82847d45128833bd84003a416449510813dd1f22/apps/browser/src/components/onboarding/SourceStep.tsx
- https://github.com/ardia-browser/ardia/blob/82847d45128833bd84003a416449510813dd1f22/apps/browser/src/components/import/ImportWindow.tsx

Its source separates optional browser choice from an import window with source/profile/access/progress/result states. Cove uses the smaller supported subset. This is an independent native implementation, not copied Ardia component code.

Dia target: 1.57.1 (90935), arm64. SHA-256:
`45e2c890c0edbd0645c71d2a2b6bb8e87972244423da2becd27ba26d2cd6d4ec`.

REA `inspect-plist` evidence:
`ev_2932007811593d3c04b2d269615695ec8927252491d18a9d0d5c468aa189867e`.

No native decompiler provider was installed. The rest of the native study used Swift metadata, ObjC selectors, focused LLVM disassembly, strings, and format-aware asset inspection. These are static observations, not REA-engine decompiler evidence. Whole-app asset inspection hit a 64 MB limit on an unrelated catalog; focused Onboarding and NavigationBar catalogs were inspected instead.

Confirmed structure: import categories and partial failure states; separate bookmark/split/site buttons sharing hover tracking; retained split-pane coordinators and pending-removal content. The split constructor sets a 10 pt handle and 220 pt minimum width, with separate resize/drag states. Runtime overrides remain possible. Static cases do not prove the live onboarding order.

A separate Dia window was created and moved to Virtual 16:9 before tests. The user's regular Dia tabs were not used for split tests. Live checks confirmed each pane has its own navigation and close controls, and that Separate Tabs keeps both pages. The approved virtual-only recorder captured Dia and Cove. It refuses to record a selected window outside Virtual 16:9.

Local evidence, excluded from Git:

- `build/import-controls-study/dia-static-findings.md` and supporting native metadata/disassembly.
- `build/import-controls-study/dia-split.mov`, `dia-split-layout.png`, `dia-split-contact.png`.
- `build/import-controls-study/cove-split.mov`, `cove-split-layout.png` (before the final narrow-toolbar refinement).
- `build/import-controls-study/fixture/` and `pages/` contain owned import and pane-state fixtures.

Exact Dia spring timing and hover opacity were not recovered. The capture does not support a frame-perfect timing claim. The UI is aligned with the observed layout and state ownership; its spring values are explicit Cove tuning.

## Verification

- Full macOS test run: **241 tests, 52 suites passed**. Log: `/tmp/cove-import-controls-tests.log`.
- Import-focused run: 10 tests, including nested HTML, Unicode/entities, unsafe URL filtering, both timestamp epochs, live WAL reading, unchanged source bytes, partial file errors, deduplication, profile separation, and rollback. Log: `/tmp/cove-import-tests.log`.
- Added pin-import coverage for folder preservation, repeat import, profile separation, and save/reload. Added split tests for narrow adjacent panes and equal sizing.
- Media tests use real WebKit fixtures for ended playback and frame selection. Folder model tests cover movement and self-nesting protection.
- Final build passed after toolbar focus, narrow-pane, and copy refinements. Log: `/tmp/cove-import-final-build.log`. No repeat full suite was needed for those final UI-only changes.
- Computer use on Virtual 16:9 completed a real fixture import: two bookmarks, one nested folder, one history visit. Verified folder folding, rename, and safe folder removal back to regular tabs. Removed the temporary imported folder and closed the owned test windows. The single clearly named fixture history visit remains; no user history was cleared.
- Verified site controls and Save Page popovers, split entry, rotation, equal sizing, separation, and close/restore commands. External example.com cold restores sometimes remained at loading, so they were not used as proof of page-state continuity.
- Final local fixture check used counters in both panes. Both remained at 1 after insertion, rotation, divider drag, and equal sizing. Verified the final compact layout at a 900 pt window width. Closed the local test window afterward; the updated Cove build remains running on Virtual 16:9.

## Limits and next review

Import covers bookmarks and history only. It does not migrate passwords, cookies, extensions, open sessions, or Firefox history. Limits are 32 MB per bookmarks file and 100,000 visits per history source. The first-install welcome was checked in source; the existing-data upgrade path and reopened import flow were checked live. No user browser data was imported for this test.

Media state changes passed WebKit tests; this task did not manually test every streaming site, track command, or device media key. VoiceOver, four-pane layouts, and all combinations of reduced motion and appearance still need a dedicated daily-use review. History search remains the next roadmap review after user feedback on this pass.

## Commits

`5607a49` media state; `4cc6e4f` media controls; `d7ddda1` instant folder folding;
`ae79141` bookmark exports; `44e6006` history imports; `c0240fc` import UI;
`50e22d8` split bounds; `e3f81b7` address actions; `03c8271` retained split hosts;
`66df43f` focus and open-panel visibility. This log is a separate commit.
