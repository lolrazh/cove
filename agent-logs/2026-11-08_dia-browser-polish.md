# Dia comparison and browser controls

Date: 2026-11-08
Branch: `codex/dia-browser-polish`
Base: `c49487a`

Continuation: [Profiles, themes, and final motion](2026-11-11_profiles-themes-and-motion.md).
That log records the final accepted settings, the 178-test result, and the
remaining checks. The sections below retain the earlier experiments.

## Request

Use computer control to compare Cove with Dia and bring shared browser
controls closer to Dia's appearance and motion.

## Observations

Opened a separate Dia window and compared the installed Cove build with it.
Used example.com and IANA's example-domain page in both browsers. Inspected
screenshots and accessibility trees, and used the keyboard for address entry,
new tabs, tab switching, closing tabs, finding text, and sidebar toggling.

Dia keeps navigation above the page in sidebar mode. Its address editor opens
at the top of the page on a neutral surface. Cove placed navigation in the
sidebar and opened its tinted address editor 18% down the window. Cove also
exposed offscreen copies of its controls in the accessibility tree.

The windows had different sizes and Space themes. This was a comparison of
structure and behavior, not a pixel-difference test. The computer tool returns
settled states; it does not establish frame rate, dropped frames, or Dia's
animation curves. Motion values below are implementation choices, not measured
Dia timings.

## Changes

| Before | After | Reason |
| --- | --- | --- |
| Navigation in the sidebar | Navigation above the page in every layout | Keep controls available when tabs are hidden |
| Sidebar navigation and address pill | Space name in the header | Leave more room for tabs |
| Full URL in resting top toolbar | Domain or extension name; full URL when editing | Reduce visual clutter |
| Centered, tinted command panel | Neutral panel near the toolbar, constrained to the page width and height | Match the reference's placement and surface |
| Command panel scales and fades | Immediate presentation and dismissal | Frequent keyboard actions should respond directly |
| Hidden chrome uses a 0.34 s spring with 0.18 bounce | 0.24 s spring with no bounce | Reduce overshoot |
| Closing tabs scale to 0.8 | Closing tabs scale to 0.97 | Reduce the shrink effect |
| Reload icon bounces during loading | Reload/stop changes directly | Avoid repeated decorative motion |
| Shell transitions ignore Reduce Motion | Shell changes use no animation when Reduce Motion is on | Honor the accessibility setting |
| Offscreen controls remain in the accessibility tree | Hidden tab strips and sidebars are excluded | Expose only visible controls |

The command field's deferred focus callback now checks that the field still
belongs to the same window. Switching tabs or documents dismisses the address
editor. Library and media controls retain their existing layout-specific homes.

## Validation

- Debug build passed with the installed Xcode selected through `DEVELOPER_DIR`.
- Existing test suite: **153 tests in 31 suites passed**.
- A final build passed after the toolbar's Library/media placement adjustment.
- Opened the final build with computer control. Checked top-tab mode, switching
  to the sidebar, address editing, Escape, hiding and showing tabs, site controls
  while the sidebar is hidden, new-tab navigation, find-in-page, repeated tab
  switching, repeated address editing, tab closing, and page scrolling.
- Confirmed that the hidden sidebar no longer exposes duplicate controls.
- Closed the temporary Dia comparison window. Left the updated Cove build open.
- `git diff --check` passed.

Build: `build/dia-polish/Build/Products/Debug/Cove.app`.
Test result: `build/dia-polish/Logs/Test/Test-Cove-2026.11.08_20-34-15-+0530.xcresult`.

## Limits

This pass covers the shared browser frame and frequent controls. It does not
establish an exact smoothness match. Light appearance, full-screen transitions,
trackpad hover/reveal behavior, drag reordering, extension popups, and sustained
performance under heavy pages still need dedicated checks. Reduce Motion was
checked in code, not by changing the user's system preference. Cove's additional
features and stored themes remain part of Cove.

## 2026-11-10: Address field and loading indicator

Compared Dia and Cove with a local page that streams a script over 14 seconds.
The Dia loading captures are retained in this chat. The reference showed a
thin theme-colored edge, a stronger tip, and a soft glow above the address
field's lower edge. These are visual observations, not sampled animation curves.

| Before | After |
| --- | --- |
| Uniform 2-point line over the page | Tapered line inside the main address field, from a 0.25-point tail to a rounded 1.25-point tip |
| Uniform tint | Active Space theme color, with blue for the system theme |
| No halo | Curved halo rising above the line, stronger near the tip |
| Linear progress interpolation | 200 ms ease-out progress and a completion fade |
| 20-point site button beside 28-point navigation buttons | Shared 28-point button area and medium SF Symbols |
| Mixed toolbar gaps | Shared 4-point control gaps and a fixed 32-point address field |

No white highlight or repeating shimmer remains. Progress comes from WebKit.
An interrupted completion delay cannot hide a newer load. Reduce Motion removes
the progress and fade animations. Standalone pages and unfocused split panes
retain the edge indicator, since they have no active main address field.

Validation:

- Debug build passed after the final theme and tapered-shape refinements.
- Existing suite passed: 153 tests in 31 suites before the final visual refinement.
- Computer checks: slow load, completion, Stop, a failed connection, Space
  switching during loading, two theme colors, hidden tabs, address editing,
  and opening/closing site controls.
- Connected the user's existing BetterDisplay screen named Virtual 16:9.
  Moved Cove and a separate Dia reference window there. Verified the display
  move using the Window menu. Cove retained the display after relaunch.
- The user's active Dia window changed during testing. Continued Cove checks
  using the captured Dia reference instead of controlling that personal window.
- `git diff --check` passed.

The local test server is `/tmp/cove-loading-preview.py`, bound only to
`127.0.0.1:18766`. It remains running for the user's manual reload test.
Changes remain local and uncommitted. Exact Dia timing and frame pacing have
not been measured. Reduce Motion was checked in code, not by changing system
preferences. Split-pane and standalone-window loading were checked in code.

### Broader light curve

User feedback: the light faded too steeply, was too dim, and needed a broad,
subtle rise towards the tip. Compared three intensity curves using SwiftUI
ImageRenderer and the actual LoadingTrack/shape code. The image is at
`build/glow-study/curves.png` (blue/dark and yellow/light samples).

Selected B: `0.65 + 0.35 * x^1.6`. The previous left-end opacity was 0.06.
The common intensity mask now applies once to the line and halo. The halo
starts at 76% of its full height instead of zero, grows gently to 32 points,
and has a 6-point blur. The line starts at 0.85 points instead of 0.25.
Completion timing is unchanged; this revision changes spatial falloff.

Debug build and `git diff --check` passed. Inspected the real loading state
in Cove on Virtual 16:9. The line and halo remained visible across the loaded
span. The comparison is a static native rendering, not a timing benchmark.

### A refined against an actual Dia capture

User chose A and asked for a subtler light with no visible tapered boundary or
bright spot beyond the strip. Replaced the separate extended halo geometry with
blurred copies of the strip. Both halos share the strip's horizontal extent and
center. The crisp strip is an even 1 point. A's intensity curve remains
`0.45 + 0.55 * x^1.4`; the diffuse layers use 3/10 point heights and blur radii,
with 0.5/0.42 opacity. Completion timing is unchanged.

Saved a real Dia Work-theme loading screenshot to
`build/glow-study/dia-reference.png` and its address crop to
`build/glow-study/dia-address-crop.png`. The comparison at
`build/glow-study/comparison-with-dia.png` puts this screenshot above the new A
and previous A/B/C. Cove samples are native SwiftUI renders with the same scale,
loaded length, and sampled gold color. This is a spatial comparison, not a
measurement of Dia's timing.

Debug build and `git diff --check` passed. Relaunched Cove on Virtual 16:9,
inspected its blue light during the local slow load, and confirmed completion
removed the loading indicator. Saved `build/glow-study/cove-strip-loading.png`.
Moved Cove back to Built-in Retina Display and verified the Window menu now
offers Move to Virtual 16:9. The local slow fixture remains available for review.

### Native loading-light editor

Built an isolated SwiftUI app in `prototypes/loading-light/GlowLab.swift` after
the user requested controls to choose the glow. The study draws light only
above the strip, with a smooth vertical falloff and a short right tail. It clips
the entire field to the address bar's continuous rounded corner, removing the
8-point inset and abrupt left boundary in the prototype. Cove's production
loading renderer is unchanged in this round; the editor is for selection.

The editor includes three spatial presets, eight light/shape controls, six
colors plus a native color picker, light/dark surfaces, progress scrubbing,
Loading/Complete/Stopped/Idle states, a cancellable simulated load, named saved
choices, and JSON clipboard export. The real Dia crop is aligned below the
preview field at the same height and fitted width. Match color & progress sets
the captured gold color and 72.4% progress without changing the glow settings.

Built with `prototypes/loading-light/run.sh`. Checked presets, color changes,
light/dark surfaces, all eight sliders, progress, replay, stopped state, copying,
and saving through computer use on Virtual 16:9. Verified that the saved
Soft lift · gold choice survives an app restart and reloads its values.
Choices persist in `build/glow-study/choices.json`; they are local artifacts.

### Right spill from a finite light source

Corrected the prototype's separable horizontal/vertical tail. Previously the
same rightward extension appeared on every row, including the baseline. Each
row now integrates a Gaussian over the finite emitting segment; horizontal
spread grows with height above the source. This creates a soft outward fan at
the end, while the baseline stops at actual progress. There is no added emitter
or bright spot to the right. The rounded address-bar clip is retained.

Preserved the user's current purple tuning through Save choice as My glow,
then loaded those same values after rebuilding. Captured tip-before.png and
tip-after.png under build/glow-study. Checked the new field on Virtual 16:9,
including a wider spill on a dark surface. The change remains in Glow Lab.

### Balanced tip spread

The user found the finite-source fan too far in the opposite direction. Added
a small base blur and reduced the growth with height. Broad horizontal sigma
is now rightSpread * hypot(0.6, 0.55 * height / verticalSigma); the close halo
remains much narrower. The source still ends at progress, and the field keeps
the rounded address clip and upward-only rendering. Rebuilt Glow Lab.

The user began adjusting the reopened editor, so left its controls with them
and inspected the live screenshot without more input. Separately rendered the
same native field in gold at the reference scale/progress for comparison with
the actual Dia crop: build/glow-study/balanced-tip-comparison.png. This is a
spatial comparison, not a claim of matching Dia motion or optics exactly.

### Selected Soft lift integrated into Cove

The user approved the balanced Soft lift and requested slightly more upward
spread. Read the live editor: spread 31.3279, strength 0.19, right spread 8.2608,
base 0.45, curve 1.4, 1-point line, and line strength 0.9. Integrated that native
renderer into PageProgressBar, with upward spread raised to 34 points and right
spread rounded to 8.26. Color still comes from the active space's chrome theme.

NavigationBar now gives the light the full address-field bounds and clips it
with the same concentric corner shape as the field surface. Removed the old
8-point horizontal and 1-point bottom inset. The light stays above the strip.
Page-edge indicators in standalone pages and unfocused split panes keep a thin
line without an address-bar halo. Loading/completion timing is unchanged.

Marked only the value-based animation progress and animatableData nonisolated
to satisfy Animatable under Cove's MainActor-default Swift configuration.
Debug build passed, as did git diff --check. On Virtual 16:9, inspected real
slow loads in Personal blue and Space 2 warm tint; confirmed load completion
and Stop clear the loading indicator. Captures are cove-chosen-glow.png and
cove-chosen-glow-warm.png in build/glow-study. Exact frame pacing was not measured.
