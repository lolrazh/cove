# Vivid themes and stable tab text — 2026-11-12

## Result

One primary color now determines the full theme. It produces a saturated light,
a related gradient color, a dark shade, and a light surface. The editor has one
color control and an optional intensity slider. This replaces the two-color
editor in `2026-11-12_shared-themes-and-suggestions.md`.

The measured sidebar close defect is fixed. The newly selected title now stays
with its own favicon while the row moves upward. The existing 120 ms close
curve and valid-page selection order are unchanged.

## Reverse-engineering method

Used the Reverse Engineer Anything skill for both investigations. Its native
MCP tools and CLI were unavailable. Used its documented ordinary-tool fallback:
Apple tools, Mach-O Swift reflection metadata, matching saved disassembly, and
fresh virtual-display recordings. These are ordinary saved observations, not
REA-engine Evidence. No Dia assets or implementation code were copied.

Target: Dia 1.56.2, build 90792, arm64. Executable SHA256:
`76c924d9bb5ea8e370f00329455607e31bb3f01cf2d0bd0a5014c89222a776d9`.

Dia's qualified metadata identifies tonal roles (`tintedLight`, `midTone`,
`shaded`, `shadedDark`), analogous/complementary wheel modes, and separate color
selection and intensity state. Its exact color coefficients and intensity curve
were not recovered. Cove's hue offsets and saturation values are original visual
choices. This is a reference-based implementation, not an exact theme clone.

Detailed evidence:

- `build/theme-close-review/dia-theme-evidence.md`
- `build/theme-close-review/dia-theme-fields.json`
- `build/theme-close-review/dia-close-evidence.md`
- `build/theme-close-review/close-drift-measurements.json`

## Changes

| Priority | Location | Before | After |
| --- | --- | --- | --- |
| High | `ChromeTabItem.swift:208` | Child geometry could move the selected title ahead of its favicon during removal | A shared geometry group resolves row motion once |
| Medium | `SidebarTabView.swift:476` | New Tab could inherit separate child geometry during list reflow | The same row boundary applies to New Tab |
| High | `ChromeTheme.swift:99` | Weak tint over gray and a separate secondary color | One seed generates a saturated tonal palette and related glow |
| Medium | `SpaceEditor.swift:55` | Main and Glow color controls | One Theme color control; Intensity remains optional |
| Medium | `NewTabPage.swift:135` | Low-opacity start-page light | Stronger primary and companion light with the existing broad falloff |
| Medium | `NewTabPage.swift:48` | Brighter light reduced search placeholder contrast | A quiet content-colored backing keeps the field readable |
| Medium | `ChromeTheme.swift:140` | Translucent text could blend into the colored frame | Solid on-theme text for sidebar labels and recent-site labels |

The theme still follows the existing shared space-transition progress. The
start-page light has the same finite entrance and Reduce Motion path. No new
animation loop, timer, state machine, or package was added. Footer icons retain
their quieter treatment.

Legacy single-color strings still decode. The previous two-color format keeps
its primary color and intensity; its secondary color is replaced by the derived
palette. Tests cover migration, round trips, neutral colors, and hue wrapping.

The geometry fix uses the parent-layout boundary described in Apple's
[geometryGroup documentation](https://developer.apple.com/documentation/swiftui/view/geometrygroup/).
The installed SDK confirms availability. Mintlify's context tool was not exposed
in this session; the installed SDK and official Apple reference were used.

## Measured close result

Fresh recordings used the approved virtual-only helper on Virtual 16:9. The
helper refuses a window that is not wholly on that display. No main-display
video, microphone, or audio capture was used.

The matched case closes selected Motion B and selects Motion C. Measurements
track the title ink center relative to its own favicon, at original frame PTS.
These are geometric ink bounds, not an optical or typographic baseline. Captures
are 2×. Unrecorded between-frame peaks remain unknown.

| Capture | Maximum extra title drift |
| --- | ---: |
| Cove before | 25 source pixels / 12.5 pt |
| Dia reference | At most 1 source pixel / 0.5 pt |
| Cove after | 0.5 source pixel / 0.25 pt |

Files: `cove-before.mov`, `dia-close.mov`, and `cove-after.mov` in
`build/theme-close-review`. Source hashes, original frame indices, PTS values,
and individual bounds are in `close-drift-measurements.json`.

## Validation

- Final `xcodebuild test`: **196 tests in 42 suites passed**, 14.265 s test time.
  Log: `/tmp/cove-vibrant-close-final-tests.log`.
- Result bundle:
  `build/dia-polish/Logs/Test/Test-Cove-2026.11.12_21-59-41-+0530.xcresult`.
- `git diff --check` passed.
- Live virtual-display review: Meadow, Honey, and Coast; one-color selection;
  derived gradient updates; Done; restart; saved primary color and intensity.
- Recorded final green theme in `final-theme.mov`; frame in `green-final.png`.
- Sampled green text contrast improved from 2.52:1 to **5.20:1** for the search
  placeholder, and from 2.98:1 to **6.58:1** for sidebar New Tab. These samples
  use the 95th-percentile text luminance and a nearby background pixel from the
  saved compressed frame. They are local samples, not a whole-app contrast audit.
  Values are in `contrast-samples.json`.

Limits: no claim of exact Dia color parity or universal frame-perfect motion.
The measured close case is a short sidebar list. Overflow, pointer-resting close,
and all rapid gesture combinations were not re-recorded in this pass. The full
suite includes rapid close/reopen selection checks. Light appearance, Increased
Contrast, Reduce Motion, custom color-panel input, and slider dragging were not
all checked live; their existing paths remain in source. CUA's virtual slider
and hover input limitations still apply.

## Handoff

Restored Personal to its original Meadow primary at 100% intensity. Closed only
the temporary Dia reference window. Existing user browser windows were retained.
Stopped all recordings. Moved the latest Cove review window to Built-in Retina
Display with the Window menu, then checked the visible result and confirmed no
Cove window remained in the virtual recorder inventory.

Build: `build/dia-polish/Build/Products/Debug/Cove.app`.
Existing unrelated working-tree changes were preserved. No commit or push.
