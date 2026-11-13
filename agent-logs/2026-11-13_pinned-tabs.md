# Pinned tabs — 13 November 2026

## Result

Top-level pins now use rounded, full-width tile rows. The selected tile has a
soft fill from the favicon, with the crisp favicon centered above it.
This is a local Debug build. Nothing was pushed or released.

The user asked what Favorites and pins mean. Explained the current model:

- Favorites appear in each space within one profile.
- Pins appear only in their own space.
- Neither type crosses profile boundaries.

Kept those storage rules. Pin Tab still creates a space pin. Existing Favorites
keep their separate compact grid. Tabs inside folders keep their named rows.
No migration, page-host change, or new state store was added.

## Changes and commits

- `e6a7337 ui: arrange space pins in balanced full-width rows`
  - Rows: 1, 2, 3, 2+2, 3+2, 3+3; larger counts stay balanced, at most three per row.
  - Tile height 40 pt, gap 6 pt, corner radius 10 pt, favicon 16 pt.
  - One flat SwiftUI Layout keeps tile identity when a tile changes rows.
  - 120 ms ease-out reflow. Reduce Motion removes the added movement animation.
  - Native buttons have names and selected traits. Context-menu rename works.
  - Reused the existing drag/drop path and stable parent drag-session observer.
- `07d2ec2 ui: soften selected pins with favicon color`
  - A separate clipped favicon layer supplies the selected fill: 14 pt blur,
    24% opacity. The source is the existing cached favicon. No page sampling,
    average-color calculation, or extra cache was added.
  - Hover uses a short fill change. No heavy colored rim or scale bounce.
  - Removed an extra 8 pt gap caused by an empty folder-list view below the grid.

## Dia comparison

Used the Reverse Engineer Anything skill's bounded static fallback. The REA
service and CLI were not available. This is ordinary native-tool evidence,
not REA-engine output. The binary hash was checked before prior metadata was reused.
Read-only helper work was limited to the installed executable; no profile files.

- Dia 1.56.2 / 90792 has a dock-layout path with 120 ms ease-out timing.
- Its selected outline can use an image mask and a saturation filter.
- Verified filter values: saturation 2.0 and brightness −0.1. An appearance
  branch chooses alpha 0.75 or 1.0. The light/dark mapping remains unknown.
- The exact upstream image source, blur settings, and row-balancing algorithm
  were not recovered. Cove's row rules come from the user's explicit request.
- Cove's soft interior fill is a deliberate alternative to Dia's strong rim.

[Static evidence and exact addresses](2026-11-13_dia-pinned-tabs-evidence.md).
[Frame comparison and three active-state options](artifacts/pinned-tabs-comparison.html).
The options are illustrative CSS previews. Only Soft color is in the native app.

Recorded both apps using the previously approved virtual-only capture helper.
Both windows were fully inside Virtual 16:9; no main-display recording was made.
The recorder targeted 60 fps, but actual frame intervals vary.

Tracked existing icon positions during row reflow:

| Recording | Captured movement interval |
| --- | --- |
| Dia, two pins to three | 120 ms |
| Dia, three pins to two | 135 ms |
| Cove, one pin to two | 132 ms |
| Cove, two pins to three | 135 ms |
| Cove, three pins to four | 135 ms |
| Cove, four pins to five | 122 ms |

Times run from the last still sample to the last detected position change.
They are capture estimates, not input latency or proof of exact frame parity.
Reviewed original frame strips for the two-to-three case. Icons move into the
new columns and settle without a scale bounce. The app widths differ; the
comparison preserves the same display scale.

Raw recordings, frame tracks, measurement script, and strips:
`build/pinned-tabs-study/`. The checked-in comparison embeds the cropped frames.
Its captures precede the final spacing-only correction below the grid.

## Validation

- Targeted layout checks passed for row counts 0–8, geometry for 1–30 pins at
  both sidebar width limits, no overlaps, full-width rows, and RTL mirroring.
- Full Debug suite passed: 198 tests in 43 suites.
  Result: `build/dia-polish/Logs/Test/Test-Cove-2026.11.13_14-38-40-+0530.xcresult`.
- Live virtual-display checks: create and pin six public test pages; select pins;
  unpin into a normal row; rename a pin; switch spaces and return; restart and
  confirm saved pins and the renamed title; remove all test pins.
- Returned Cove to its original empty start page. Existing spaces were retained.
  The latest build remains on Virtual 16:9. Dia's test tab was removed, its
  auto-hide setting restored, and its window returned to the main display.
- Physical trackpad drag/reorder feel, physical hover, VoiceOver reading order,
  and live Reduce Motion were not verified. Their code paths were preserved or
  inspected; the geometric RTL test is not a full mirrored-interface test.
- `git diff --check` passed. Existing untracked `prototypes/` files were excluded.

Used Better Layout and Better UI for the focused layout and surface pass.
Mintlify was not available. Checked the custom layout contract in
[Apple's Layout documentation](https://developer.apple.com/documentation/swiftui/layout).
