# Group controls, glass and theme tones — 14 November 2026

## Request

Remove the strong selection outline. Add a group close button. Fix long-name editing. Make groups and active tabs look like stacked, subtle glass. Use neutral groups by default, with optional color. Match the open Dia sidebar width and improve Cove's theme colors. Keep commits small.

## Reference evidence

Used reverse-engineer-anything, better-ui and write-swift. Independent native/resource analysis and rename work followed the REA skill's separate-scope workflow. Mintlify context was not exposed; the rename API was checked in the installed SwiftUI SDK and Apple's documentation.

- Current Dia 1.57.1 resources and native call paths confirm a neutral group fill of white 10% in dark appearance, 12% hover/emphasis, and a 10% white sidebar stroke. A secondary selected-tab resource is white 25%. These are separate roles, not proof of one complete compositing formula.
- Dia has separate rim, tint, gradient-border/mask, shadow and parent-appearance layers. Cove now uses a small shared surface with translucent fill, a half-point directional rim and a soft shadow. Nested active tabs blend over their group.
- The user's open Dia window measured 380 px of sidebar at 2×, or 190 pt. This is the observed width, not a claim about Dia's factory default.
- The recorded blue sweep measures approximately #057AAB to #043538. Exact profile gradient pairs were not recovered for every family. Cove's other tone pairs are our own choices with a similar saturated-to-deep range. Unrelated Arc Brand/Easel assets were excluded.
- Detailed evidence: `build/tab-group-polish/dia-material-palette.md`, `dia-tab-assets.json`, and `dia-sidebar-samples.json`.

## Changes

- A group close button appears on header hover or whole-group selection. It is a separate button from collapse and uses the existing close/archive path.
- Multi-selection uses a stronger fill without a selection outline. Drop feedback uses a fill instead of a heavy border.
- Groups use neutral glass by default, including existing saved groups. Group Color in the context menu provides optional tints and a Default reset. The optional color survives saved-index mapping, app restart and close/restore; old data decodes without a color.
- RenameField uses a horizontal, single-line SwiftUI field and field-local TextSelection. Removed the delayed global first-responder select-all. The visible text follows the insertion point.
- Sidebar default/minimum is 190 pt. Old 220/240 pt defaults adopt the new width; other saved custom widths remain. The profile-name padding is tighter so Personal fits.
- Theme seeds remain stable. The frame no longer mixes white into pastel paper. It uses saturated upper tones and deeper lower tones. The existing subtle new-tab glow remains separate. Both frame endpoints use the existing profile-transition interpolation.
- Increased Contrast keeps the system appearance. Opaque group/active fallbacks use separate system surfaces and stronger edges. Old intensity values fade toward neutral dark rather than producing a light frame with white text.

## Checks

- Full suite: **230 tests in 50 suites passed** in `/tmp/cove-group-polish-tests.log`. Result: `build/dia-polish/Logs/Test/Test-Cove-2026.11.14_19-09-22-+0530.xcresult`.
- Final UI build: `/tmp/cove-group-polish-final-build.log`.
- Virtual 16:9, separate Cove test window: automatic two-tab group; neutral stacked surface; group selection without outline or page change; visible close button on selection; close group; restore both members with name/color; collapse and expansion retaining the active page; app restart retaining group state.
- Rename: initial select-all; long pasted name shows its tail; Command-Left plus typing shows the start; Escape restores the original name; Return saves; clicking into the page saves.
- Optional group Red tint and Default reset passed. Profile Red, Green, Blue and Sky were checked in the running UI. Restored the user's original Sky selection.
- Current screenshot and virtual-only capture: `build/tab-group-polish/final-sidebar.png` and `final-glass.mov`. No exact frame-match claim.
- Closed the owned test window and stopped the port 8774 fixture server. Original Cove and Dia windows/tabs remain intact.

## Limits

The source review includes Increased Contrast and Reduce Transparency fallbacks; system settings were not changed for a live check. Header close was exercised through whole-group selection; computer use does not reliably generate native hover events on this virtual display. Normal translucent text contrast varies with stacked surfaces and position; matching Dia's material roles is not a WCAG contrast certification. Exact non-blue Dia gradient values remain unknown.
