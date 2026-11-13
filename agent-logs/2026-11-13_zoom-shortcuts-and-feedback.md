# Page zoom shortcuts and address feedback — 2026-11-13

## Result

- Added Control–Plus, Control–Equals, Control–Minus, and Control–0.
- Kept Command–Plus, Command–Minus, and Command–0. Added Command–Equals.
- Moved Add Split View from Control–Shift–Equals to Control–Option–S.
  The old shortcut collided with Control–Plus, including on a start page.
- Page zoom changes at once. A compact, theme-colored badge appears in the
  address field. Its digits roll vertically during repeated changes.
- The badge has a fixed 66 pt slot, so address text does not move.
- Numeric changes use a 180 ms ease-out transition. Appearance and removal use
  a 120 ms fade. Each update restarts a 1.5 second dismissal timer.
- Reduce Motion disables the movement and fades. The badge exposes the label
  Page zoom and the current percentage to accessibility.
- Feedback belongs to its TabSession. Navigation and closing clear it. Other
  tabs and profiles do not inherit it. Site Controls and menu/Command Bar zoom
  use the same page setter. The old Zoom toast is removed.
- Existing site zoom persistence, zoom levels, and native pinch remain intact.

## Dia reference

Used the reverse-engineer-anything skill. Neither an REA MCP engine nor an REA
CLI was available. This is computer-use evidence and ordinary read-only static
inspection, not REA-engine Evidence or recovered source.

Target: `/Applications/Dia.app/Contents/MacOS/Dia`, version 1.57.1.
SHA-256: `45e2c890c0edbd0645c71d2a2b6bb8e87972244423da2becd27ba26d2cd6d4ec`.
The binary differs from earlier studies; old binary addresses were not reused.

Current strings and ObjC metadata contain `NavigationBar.ZoomToastView`,
`ZoomToastViewModel`, `ZoomToastLabel`, and separate `labelView` and `iconView`
fields. These establish component names, not their animation timing or code.

Recorded Dia on Virtual 16:9 using the approved virtual-only helper. Used a
new Example Domain tab, exercised Command zoom in/out/reset, restored 100%,
and closed the temporary tab. The live build shows a colored badge at the
center near the bottom edge of the navigation bar, with a magnifier and a
percentage. Repeated presses update the same badge. Frames sampled at 30 fps
show digit movement and soft overlap while the numbers change. The current
Dia placement is not literally inside the address text field.

Cove places the feedback inside the address field as requested. Its timing,
size, fixed icon, and surface are implementation choices informed by the
capture, not claims of exact recovered Dia parameters or pixel parity.

Local artifacts (not committed):
- `build/zoom-study/dia-zoom.mov`
- `build/zoom-study/dia-zoom-detail.mp4`
- `build/zoom-study/dia-digits.jpg` (32 samples, starting at 15.7 s, 30 fps)
- `build/zoom-study/dia-zoom-strings.txt`
- `build/zoom-study/dia-objc-metadata.txt`
- `build/zoom-study/cove-zoom.mov`
- `build/zoom-study/cove-digits.jpg` (32 samples, starting at 15.4 s, 30 fps)

## Validation

Debug build and **8 tests in 2 suites passed**: PageZoomTests and TabManagerTests.
The added test checks zoom in/out/reset, no generic toast, per-page feedback,
the start-page guard, and clearing on close. Test output:
`/tmp/cove-zoom-feedback-final-tests.log`.

Live checks on Virtual 16:9:
- Control–Equals and Control–Plus increase one step.
- Control–Minus decreases one step; Control–0 reports 100%.
- Command–Equals, Command–Plus, Command–Minus, and Command–0 work.
- Rapid increase/decrease updates one badge; it fades after the last input.
- Profile switching removes the previous page's feedback.
- After the conflict fix, Control zoom on a start page does nothing and
  Control–Option–S still opens the split command bar.
- The recorded digit sequence shows vertical transitions, with a stable badge
  and icon. The page changes scale without waiting for feedback animation.

Restored the test site's zoom to 100%, closed Cove's temporary tab, and returned
to Personal's original active page. The latest build remains on Virtual 16:9.
Reduce Motion was checked in source, not by changing the user's OS setting.
Physical trackpad pinch remains outside this keyboard test.

API reference: [Apple ContentTransition](https://developer.apple.com/documentation/swiftui/contenttransition).
Mintlify context was unavailable; used official Apple documentation.

## Commits

- `c59f454` Add Control zoom shortcuts and remove the split shortcut conflict.
- `55003f6` Show rolling page zoom feedback in the address bar.
