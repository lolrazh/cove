# Fine grain promotion — 2026-11-13

## Selected result

The user selected Fine grain, 100% color intensity, and 8 px glass blur.
They asked for the new-tab glow to rise from the bottom so it does not affect
the address-bar blend. The live study showed Blue selected. The native Personal
space is now Blue at 100%; other saved space choices are retained.

## Changes

- Promoted the eight study color pairs into the native theme picker. Custom
  seeds still generate a companion. Very dark custom seeds are lifted for
  readable dark text. Stored colors and intensity keep their existing format.
- Added one shared Fine grain background for the frame and floating chrome.
  It uses a native NSVisualEffectView behind-window material, a translucent
  color layer, broad static color gradients, and one cached 128 px noise tile.
  There is no texture timer or per-frame image generation.
- Applied an 8 pt softening pass over the native material. macOS owns the
  underlying material blur; this is not a claim of an exact 8 px CSS backdrop
  kernel or native Liquid Glass. The prototype itself multiplied its grain
  blur control by 1.5. Native values are not a one-to-one CSS conversion.
- Used dark text on the bright frame in both page appearances. Page foregrounds
  keep their own appearance. Increased Contrast and Reduce Transparency use
  an opaque fallback. The native accessibility modes were not toggled live.
- Moved the new-tab light to the bottom. The primary opacity is 0.15 and the
  companion is 0.10. A height-relative mask excludes the top 35% of the page,
  including very wide windows. The finite 1.2 s entry respects Reduce Motion.
- Kept page sampling, color caching, tab ownership, loading-bar behavior, and
  profile transition state unchanged. No new package or framework dependency.
- Arranged eight theme swatches in two rows. Kept the existing 220 pt sidebar.

## Validation

- Final Debug test build passed: 196 tests, 42 suites.
  Log: `/tmp/cove-fine-grain-final-tests.log`.
- Existing compiler warnings remain in command bar, extensions, and pins code;
  this pass adds no compiler errors. No claim of a warning-free repository.
- Used computer use on Virtual 16:9 to inspect Blue and Yellow, select a color,
  close the editor, and confirm Blue/100% survived a restart.
- Checked XML Prompt Builder: the address bar still matches its green header.
  The dark new tab keeps a clean toolbar and a subtle bottom sunrise.
- Reduced the grain contrast after the first native visual check.
- Recorded the final native build with the previously approved virtual-only
  helper. Evidence: `build/fine-grain-review/final.mov` and `blue-sunrise.png`.
  This is a visual smoke check, not a new frame-by-frame Dia timing study.
- Stopped the recording and moved the final native window to Built-in Retina
  Display. Left Blue at 100% and the start page open for user review.
- Archived the selected study at `build/fine-grain-review/selected-prototype`
  and removed `prototypes/theme-lab`, per the prototype skill's promotion step.
- No commit or push. Pinned tabs remain separate follow-up work.

## Tools and evidence limits

Used the prototype promotion workflow and write-swift guidance. Reused the
already inspected Dia study; no new binary recovery is claimed. Mintlify
context is not exposed in this session. Native API usage was validated by the
installed Xcode build. No external documentation research was needed.
