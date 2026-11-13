# Theme polish and Library clarity — 2026-11-12

## Scope and conventions

The user asked for quieter footer icons, hover brightness, and a pleasant
Dia-like opening glow, with basic use kept fast. They also asked why Library,
Archive, and Downloads exist. The original `ARC-PARITY.md` explicitly planned
this Library grouping after Arc. Downloads stores downloaded files; Archive
stores closed tabs for reopening; History lists visited pages.

This pass covers the sidebar footer, empty start page, and Library section
navigation. It is not a full-app audit. The existing `ChromeTheme`, semantic
palette, `ChromeButtonStyle`, SF Symbols, and native text styles remain the
source of truth. Prior dirty changes were preserved. No commit or push.

## Skill review, one domain at a time

| Domain | Coverage | Result |
| --- | --- | --- |
| Layout | Footer targets, start-page bounds, Library section text and rows at 900 × 680 pt | Space targets are 24 pt. Section descriptions wrap. Existing command-bar layout stays unchanged. |
| Typography | Start-page caption, Library title/detail hierarchy and truncation | Recent uses secondary text. Full URLs are available as help text. Native type styles retained. |
| Color | Rest/hover/selected footer emphasis; theme tint in start-page background | Resting icons dimmed. Selected spaces retain stronger emphasis. Increased Contrast bypasses dimming and the decorative wash. |
| UI polish | Shared button states, finite background movement, clipping | Hover brightness uses the existing 120 ms transition. Background moves once with 1.2 s ease-out, then stops. |
| Accessibility | Names, selected state, primary Library actions, motion handling | Explicit names and selected traits added. Rows use native buttons. Reduce Motion stops wash movement and press scaling. |
| Writing | Meaning of Library, Downloads, Archive, and History | Short descriptions explain each section and the Archive action. Library help names all three sections. |

Applied Better Layout, Better Typography, Better Colors, Better UI, Better
Accessibility, Better Writing, then Better Interface to combine the findings.
Emil Design Engineering and Animate guided the finite, non-blocking effect.
The user explicitly requested opening delight; controls remain still and ready
while the decorative background moves. This is not an extra delay on Cmd-T.

## Consolidated findings and changes

| Priority | Before | After | Source |
| --- | --- | --- | --- |
| Medium | Footer icons competed with page content; opacity on the label limited hover emphasis | Resting opacity is a shared button-style option; hover restores full emphasis. Space values are 0.50–0.78; Library and New Space use 0.60. | `Cove/Sources/UI/Foundation/ChromeButtonStyle.swift:19`, `Cove/Sources/Spaces/SpaceSwitcher.swift:25`, `Cove/Sources/Library/LibraryButton.swift:36`, `Cove/Sources/UI/SidebarTabView.swift:92` |
| Medium | Library section names did not explain their use | One short sentence per section, plus descriptive Library help | `Cove/Sources/Library/LibraryModel.swift:24`, `Cove/Sources/Library/LibraryView.swift:13` |
| Medium | Library primary actions used a tap gesture on the row | Native Button for the primary action; accessory controls remain siblings, not nested buttons | `Cove/Sources/Library/LibraryView.swift:171` |
| Low | Empty start page had no requested opening light | Two theme-colored radial gradients move once; search and recent cards do not move or block input | `Cove/Sources/UI/NewTabPage.swift:116` |
| Low | Recent label had weak emphasis; icon-only controls had generic names | Secondary caption color, explicit control names, selected-space trait, full-URL help | `Cove/Sources/UI/NewTabPage.swift:53`, `Cove/Sources/Spaces/SpaceSwitcher.swift:26` |

The first glow draft exposed an ellipse edge. The final version uses a circular
radial fade, then scales the circle vertically. The gradient reaches zero alpha
at its edge before clipping. No timer, looping animation, or extra state machine
was added. Existing download progress stays at full emphasis.

## Dia reference and evidence limits

Used the Reverse Engineer Anything skill. Its scoped parallel workflow was used
for read-only static inspection while the main agent checked the UI. REA tools
were unavailable, so the report labels Apple binary/resource tool output as
ordinary static evidence, not REA-engine Evidence.

Target: Dia 1.56.2 (90792), executable SHA256
`76c924d9bb5ea8e370f00329455607e31bb3f01cf2d0bd0a5014c89222a776d9`.

The inline footer overflow chevron uses label color at 0.20 alpha at rest and
0.40 on hover in one proven code path. These values do not describe every Dia
footer icon. Cove uses its own values over its own surfaces.

Dia contains gradient tokens and Metal halo, swirl, and color-sweep paths. The
new-tab component links to the PowerUp animation system. This does not establish
the exact active opening effect, timing, easing, or trigger. No proprietary
assets or implementation were copied into Cove.

A new Dia reference window and the Cove test window were recorded only on
Virtual 16:9 using the previously approved recording helper. The Dia Cmd-T
capture shows a broad dark teal/blue surface and command-bar glow; it did not
show enough motion to recover a reliable opening curve. Cove's 1.2 s value is
an original design choice, not a measured Dia match.

Local artifacts (ignored build output):

- `build/theme-polish/dia-static-evidence.md`: exact selectors, addresses, colors, and limits.
- `build/theme-polish/dia-opening.mov`, `dia-opening-detail.png`, `dia-settled.png`.
- `build/theme-polish/cove-opening.mov`, `cove-opening-contact.png`, `cove-settled.png`.

The Cove contact sheet samples the page-to-start-page return at 2 fps. It shows
the light shifting and settling while the field and tiles stay fixed. This is
a visual check, not a frame-time benchmark or claim of exact Dia parity.

## Validation and handoff

- Final Debug build and full test run passed: **187 tests in 39 suites**, 3.502 s
  for the test run. Log: `/tmp/cove-theme-polish-final-tests.log`.
- `git diff --check` passed.
- Live checks on Virtual 16:9: final glow has no hard edge; footer names and
  selected state appear in the accessibility tree; all three Library sections
  show their explanations; History opens Example Domain through the new button.
- Closed that test page, then the final empty tab: the window stayed open with
  the start page. Typed a URL into the start-page field and loaded it. Closing
  the final loaded tab returned to the empty start page again.
- Restored the user's hidden-sidebar preference. Closed the temporary Dia
  reference window. Existing user windows and tabs were retained.
- Left the updated Cove start page on the main Built-in Retina display for
  review. App: `build/dia-polish/Build/Products/Debug/Cove.app`.

Not verified live: physical pointer hover timing, a full VoiceOver session,
light appearance, Increased Contrast, Reduce Motion, every custom theme, active
download progress, destructive Archive actions, or a full download-to-Finder
flow. Accessibility fallbacks were checked in source. No alternate mouse helper
was used. The user previously chose to check hover themselves.

No high-severity issue was found in the inspected states. This supports review
of this limited change, not approval of the full Library or the entire app.
Next review: download → Finder, close → restore, and History search. Then check
profile creation and theme editing across appearance and accessibility states.
