# Theme variations and compact sidebar — 2026-11-13

## Request

Explore all Dia colors. Show brighter theme variations with a much softer
new-tab gradient, slight glass, blur, and possible noise. Make the docked sidebar
as narrow as the hidden sidebar minimum. Remove its palette icon. Pinned tabs
are the next task, not part of this change.

## Shipped local build changes

- Sidebar default is now the shared lower bound, **220 pt**, previously 240 pt.
  Saved 240 pt widths adopt the new default. Other explicitly resized values
  remain intact. Both sidebar presentations use the same width path.
- Removed the palette symbol from `SidebarSpaceTitle`. The name remains the
  accessible theme-editor button.
- Build succeeded with Xcode Debug and `CODE_SIGNING_ALLOWED=NO`.
  Log: `/tmp/cove-compact-sidebar-build.log`.
- Live check on Virtual 16:9 confirmed the 220 pt frame, missing palette symbol,
  and working name → editor → Done path. Existing Rose theme was retained.
- No new unit tests for these small visual edits. No full-suite rerun claimed.
  `git diff --check` passed.

Source: `ChromeTokens.swift`, `BrowserSettingsStore.swift`, and
`SpaceSwitcher.swift`. Existing unrelated changes were preserved.

## Dia evidence

Used Reverse Engineer Anything's ordinary static-tool fallback, since no REA
MCP engine was connected. A read-only parallel investigation reused prior
matching evidence. These observations are not REA-engine Evidence.

Dia 1.56.2, executable SHA256:
`76c924d9bb5ea8e370f00329455607e31bb3f01cf2d0bd0a5014c89222a776d9`.

Confirmed live picker order: **neutral, green, blue, purple, yellow, pink, red,
orange**. The `SpaceModels.Space.Theme` enum independently has those eight
families. Recorded all eight full-window states with the approved virtual-only
helper. These are inactive-window samples at the existing theme intensity,
not a full sweep of intensity or light appearance. Restored Personal to blue
and closed only the temporary reference window and opened settings window.

Static evidence also shows a separate `newTabBackgroundColors` semantic field.
The neutral picker swatch uses `NSGlassEffectView`, with black tint alpha 0.06
on its macOS 26 path. This does not prove full-window Liquid Glass. Grain,
sand, denim, and tweed resources exist; active theme texture use is unknown.

Reports, inventory, capture marks, and recordings:
`build/theme-variants-review/`. The raw capture is `dia-eight-colors.mov`.
The eight extracted frames are copied into the isolated prototype references.
Exact generated Dia RGB values, blur radius, and intensity mapping remain
unknown. The prototype colors are original choices in those eight families.

## Comparison delivered

Used the prototype skill. The visual exploration is isolated in
`prototypes/theme-lab`; it adds no package or production import.
The fixed picker markup, CSS, and keyboard contract come from its PICKER.md.

| Variant | Surface direction | Useful when | Cost |
| --- | --- | --- | --- |
| Clear | Strong color, crisp surfaces, no grain | Color should carry the identity | Least sense of glass depth |
| Frosted | Backdrop blur and soft edge reflections | A slight glass finish is wanted | More compositing and highlights |
| Fine grain | Diffuse color with a fixed noise texture | A softer, less glossy finish is wanted | Texture can be visible at close scale |

All have an 8% default new-tab wash, compared with the much stronger prior
production glow. Frame intensity is independent. The preview supports eight
families, custom primary color with a derived companion, dark/light appearance,
a white-page context, intensity/glow/blur controls, tab actions, and keyboard
switching. Changing controls updates immediately. No continuous noise or motion.

This is a web visual prototype. Frosted uses browser backdrop blur; native
Liquid Glass is not implemented in Cove by this pass. No material direction
has been promoted. The user's current production theme and new-tab glow remain
unchanged pending the requested visual choice.

## Validation and handoff

- Checked all three variants in Cove on Virtual 16:9. Saved frames and recording:
  `variations.mov`, `preview-clear.png`, `preview-frosted.png`,
  `preview-grain.png`, and `preview-grain-light-yellow.png`.
- A layout defect found in review was fixed: the decorative texture layer now
  sits outside grid flow, so it cannot add a row below the preview page.
- Checked all eight family buttons, custom color, keyboard slider changes,
  variant keyboard switching, reset, closing a tab, and sample search submission
  in a background browser. No console errors or warnings were reported.
- JavaScript syntax checks passed. No external library was added.
- Stopped every recorder and closed the temporary background browser tab.
- Restarted the new Cove build. Opened the comparison in a separate window,
  moved it to Built-in Retina Display, filled the window, and checked the final
  visible layout. Existing user windows remain open.
- Local comparison server remains available on `127.0.0.1:8767` for review.
  It serves only `prototypes/theme-lab`. See its README to restart it.
- No commit or push. Pinned tabs remain next.

## Follow-up: black background hid the material differences

Changed only the isolated prototype. The comparison now starts in light mode
on a pale patterned desk. Added Paper, Color, and Dark backdrop choices, separate
from page appearance. Frosted now has a translucent frame with actual backdrop
blur; Clear remains opaque. Fine grain uses a more diffuse translucent frame
and a slightly more visible static texture. The page content stays opaque.

Checked the updated page and all three variant buttons in the open comparison.
Restored the user's selected green preview family, scrolled to the top, and left
Frosted open on the main display. JavaScript syntax and `git diff --check` passed.
No native Cove theme change or new build was needed for this follow-up.
