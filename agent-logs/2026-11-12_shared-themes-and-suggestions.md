# Shared themes and search suggestions — 2026-11-12

## Requested result

Extend the accepted start-page glow into the sidebar and browser frame. Make
themes easy to reach and adjust. Explain the blue focus ring and suggestion
source. Show the typed part of a suggestion at normal emphasis and its remaining
text at lower emphasis, updating as each character is typed.

## Changes

| Severity | Location | Before | After | Why |
| --- | --- | --- | --- | --- |
| Medium | `Cove/Sources/UI/Foundation/ChromeTheme.swift:221` | Glow existed only on the start page | Shared static ambient background for the frame and floating browser surfaces | Makes a space feel like one theme without adding continuous animation |
| Medium | `Cove/Sources/Spaces/SpaceEditor.swift:45` | Unnamed solid swatches and one color control | Named gradient presets, live preview, Main and Glow colors, Glow strength | Makes theme choices visible and easy to adjust |
| Medium | `Cove/Sources/Spaces/SpaceSwitcher.swift:49` | Theme editor required double-click or context menu | One-click space title with palette symbol and accessible button name | Makes the existing editor easy to find |
| Medium | `Cove/Sources/CommandBar/CommandBarView.swift:256` | Suggestion text had one emphasis | Typed substring uses primary text; the remainder uses secondary text | Separates entered text from the proposed continuation |
| Medium | `Cove/Sources/CommandBar/CommandBarModel.swift:321` | Cached suggestions could retain branches that no longer matched | Retain only matching continuations as the query grows; reject late answers for another query or engine | Keeps immediate results relevant while the next request runs |
| Low | `Cove/Sources/UI/Foundation/ChromeFieldStyle.swift:22` | A 3 pt system-blue focus outline | A 1 pt theme outline; stronger system outline under Increased Contrast | Keeps keyboard focus visible with less visual weight |
| Medium | `Cove/Sources/UI/SidebarTabView.swift:38` | Opaque header backing cut across the new gradient | Fade scroll content below the header, leaving the background continuous | Keeps the title clear without a dark strip |

Applied Better UI, Better Colors, and Emil Design Engineering. Reused the native
type styles, semantic text colors, SF Symbols, theme environment, and existing
motion model. No new animation framework or loop.

The two glow colors interpolate with the existing space-swipe progress. They do
not wait for the active-space commit. The page keeps its cached background color.
The command bar opens immediately, and the attributed suggestion text updates
without movement, blur, or delay. Its input position and accepted layout remain
unchanged. Matching handles case, accents, and composed Unicode characters.

## Persistence and search behavior

Legacy theme strings still decode. A gradient theme stores its primary color,
secondary color, and glow strength as a keyed value. Old single-color themes can
still encode as their original string. Decode clamps glow strength to 0–1.
Choosing a preset keeps the chosen glow strength; custom colors keep the other
theme controls.

Search suggestions already came from the selected engine. When enabled, Cove
sends search-like input to that engine after a 150 ms typing pause. Address-like
input does not use this request. Tabs, history, archive, and commands are local
ranked sources. These sources and the preference are retained. No AI service or
new provider was added.

## Validation

- Final `xcodebuild test` passed: **193 tests in 41 suites**, 4.268 s test time.
  Log: `/tmp/cove-theme-suggestions-final-tests.log`.
- Added regression checks for legacy theme decoding, saved gradient/glow round
  trips, out-of-range values, growing text matches, accented text, emoji, and
  cached branches that no longer match.
- `git diff --check` passed.
- Live on Virtual 16:9: opened the editor with one click; chose Coast and Honey;
  checked the sidebar, frame, start page, and thin focus outline. Fixed the
  header strip and wrapped percentage label found in the first visual pass.
- Restarted and confirmed the Coast preset and both colors were restored.
- Live suggestions: `swift` → `swift on`, Backspace, Down, Return. Matching text
  gained primary emphasis; Return opened the selected Google search. Declined
  the unexpected location request. No location permission was granted.
- Measured text pixels in the final dark suggestion capture: primary #DBDBDB
  and secondary #989898 over #1C1C1C. Contrast is 12.31:1 and 5.91:1 respectively.
  This is one rendered dark state, not a claim for all appearances or themes.

Not verified live: slider dragging, expanded Space details, custom color-panel
editing, light appearance, Increased Contrast, Reduce Motion, every theme, or
physical trackpad swipes. The virtual input tool did not change the slider or
disclosure state through click, value-setting, or drag attempts. The controls
and bindings were checked in source; glow persistence has a regression test.
No alternative mouse helper was used.

Approve the inspected states; no high-severity issue was found in that scope.
This is not full-app or full-accessibility approval.

## Artifacts and handoff

- `build/theme-suggestions/final-review.mov`: virtual-only theme recording.
- `build/theme-suggestions/coast-theme.png` and `theme-editor.png`.
- `build/theme-suggestions/suggestions.mov` and `suggestions.png`.
- Both recording helpers stopped. No main-display capture was made.
- Restored Personal to its original System theme and restored hidden-sidebar
  mode. Kept the user's existing windows and tabs. The separate review window
  is on the main Built-in Retina display with the theme editor open.
- Latest app: `build/dia-polish/Build/Products/Debug/Cove.app`.
- No commit or push. Earlier workspace changes were preserved.
