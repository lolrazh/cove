# Cove browser polish — combined log, 8–13 November 2026

## Current result

Cove now has the selected Fine grain frame and a compact theme popover.
The popover now contains a name field followed by 16 colors. Spaces use dots.
The icon picker described in section 8 was removed in the latest follow-up.
It has no preview, intensity slider, custom color picker, profile controls,
Done button, or footnote. Changes apply at once. The page remains clear behind it.

This is a local Debug build. The work is not committed, pushed, or released.
The full working tree also contains the earlier accepted changes below.
This log consolidates the existing dated logs; it does not claim that every
historical measurement was repeated today.

## 1. Address bar and loading light

- Moved navigation into the top page toolbar and tightened button spacing.
- Used shared SF Symbols, hit areas, and browser chrome tokens.
- Replaced the heavy loading bar with a thin theme-colored strip.
- Compared curves, upward diffusion, tip spill, and end behavior against Dia.
- Built a small light study, then integrated the selected Soft lift treatment.
- Clipped the light with the address field's rounded corner. The light spreads
  upward; the right spill fades beyond the finite source.
- Kept this accepted loading treatment during later theme changes.

Evidence and iteration history: [Address and loading light](2026-11-08_dia-browser-polish.md).

## 2. Profiles, spaces, and transitions

- Profiles isolate site storage and logins. Spaces have their own tabs, name,
  icon, and color; spaces in one profile share Favorites and site storage.
- Replaced the initial crossfade with adjacent tab lists moving horizontally.
- One transition state drives the lists, title, footer icons, and frame colors.
- Tracking follows the gesture directly. Release uses a bounded spring and can
  be interrupted. Removed the slow fixed settle and moving icon highlight.
- Used quieter icon brightness and an optional light haptic at completion.
- Worked on stable page hosting to reduce flashes while switching spaces/pages.
  Later tab-state work replaced several earlier cover and snapshot paths.

Accepted motion and earlier evidence: [Profiles and motion](2026-11-11_profiles-themes-and-motion.md).

## 3. Tabs and page stability

- Reviewed create, close, reorder, pin, and restore paths.
- Fixed neighbor selection when the newest tab closes and cleared stale drag
  destinations when a drag ends outside the list.
- Compared tab movement against Dia on the virtual display, including recorded
  close motion. Removed experimental motion variants from the active path.
- Kept page ownership valid before removing a tab, including rapid operations.
- Simplified page switching after reports of blank windows and overlapping motion.
- The last-tab action keeps the window open on a fresh start-page tab.
- Fixed title movement during row close with one shared geometry boundary.
  The earlier recorded drift fell from about 12.5 pt to about 0.25 pt.
  That historical measurement was not repeated in this theme pass.

Details: [Tab review](2026-11-11_tab-review.md),
[Dia tab study](2026-11-11_dia-tab-motion.md),
[State and cache](2026-11-12_tab-state-and-color-cache.md),
[State simplification](2026-11-12_tab-state-simplification.md), and
[Stable tab text](2026-11-12_vibrant-themes-and-stable-tab-text.md).

## 4. Page colors and the toolbar

- Cached page backgrounds per browsing context and URL. Switching tabs reuses
  the value; meaningful document or style changes can update it.
- Ignored identical color updates to reduce unnecessary view work.
- Added nested background detection after XMLPrompt.dev exposed the old
  html/body-only assumption. Its green header now supplies the toolbar color.
- Added a real WKWebView regression check for delayed mount, nested surfaces,
  small controls, style changes, removal, and translucent backgrounds.
- The new-tab sunrise is separate from page sampling. Today's change does not
  change the page-color cache or toolbar blending logic.

Details: [Cache work](2026-11-12_tab-state-and-color-cache.md) and the XMLPrompt
follow-up in [Repository and command bar](2026-11-12_repository-cleanup-and-command-bar.md).

## 5. Sidebar and repository cleanup

- Removed the unwanted Clear separator and the unused sidebar address component.
- Reduced observation and duplicate ownership in affected browser services.
- Made hover exit snappy, with no intentional waiting period and a short exit.
- Rounded the revealed sidebar's top corner and widened its reveal area.
- Set the shared sidebar minimum/default width to 220 pt.
- Removed the palette button; clicking the space name opens its editor.
- Dimmed footer icons at rest and kept a clearer hover state.
- Clarified Library's purpose: downloads, closed tabs, and history.

This was a repository inventory plus focused cleanup, not a proven line-by-line
correctness audit of the entire app.

Details: [Repository cleanup](2026-11-12_repository-cleanup-and-command-bar.md),
[Library and theme polish](2026-11-12_theme-polish-and-library.md), and
[Compact sidebar](2026-11-13_theme-variations-and-compact-sidebar.md).

## 6. Command bar and search suggestions

- Refreshed layout, spacing, type, row targets, and keyboard focus.
- Centered the command bar and compacted it to the accepted 600 pt width.
- Increased page favicons to 22 pt without moving the accepted row layout.
- Typed words use normal emphasis; suggested continuations use secondary text.
- Kept matching continuations while the query grows and rejected stale responses.
- Suggestions still use the selected search engine and its existing preference.
  Local tabs, history, archive, and commands remain local ranked sources.
  No new AI provider was added.

Details: [Command bar](2026-11-12_repository-cleanup-and-command-bar.md) and
[Suggestions](2026-11-12_shared-themes-and-suggestions.md).

## 7. Color study and Fine grain

- Inspected Dia's eight color families and recorded the live picker states.
- Used ordinary static-analysis tools when the REA engine was unavailable.
  These were saved observations, not REA-engine Evidence. Exact Dia color
  formulas and material parameters were not recovered.
- Built Clear, Frosted, and Fine grain prototypes with eight original color pairs.
- Changed the comparison background after black hid the material differences.
- The user selected Fine grain, 100% intensity, and an 8 px blur control.
- Promoted fixed grain, translucent native material, and brighter frame colors.
- macOS controls the base backdrop blur. Cove applies an 8 pt softening pass;
  this is not an exact CSS blur-kernel match or a claim of native Liquid Glass.
- Moved the subtle new-tab glow to the bottom to leave the toolbar clear.
- Saved the selected prototype under `build/fine-grain-review/selected-prototype`
  and removed the temporary theme-lab route from the source tree.

Details: [Study](2026-11-13_theme-variations-and-compact-sidebar.md) and
[Promotion](2026-11-13_fine-grain-promotion.md).

## 8. Today's compact editor and wider sunrise

- Replaced the browser's modal theme sheet with a 316 pt native popover.
  The first visual check showed it extending outside the window; its anchor
  was moved inward. An opaque system panel backing keeps text readable over
  all frame colors. The page itself is not blurred or dimmed.
- Removed the preview, slider, custom color picker, explanatory copy, and Done.
  Color selection uses the preset's full intensity. Old stored colors and
  intensity values still decode; opening the editor does not reset them.
- Arranged colors as two close rows of eight 32 pt targets with 26 pt swatches.
- Retained all original study colors, including Red (#EE8295 → #F4B18F) and
  Blue (#4BAFF1 → #8984EE). Added Teal, Mint, Sky, Indigo, Plum, Coral, Scarlet,
  and Sand. Scarlet gives a stronger red choice without replacing the study red.
- Expanded the icon catalog from 16 to 96 SF Symbols and added 96 named emoji.
  Both grids have search, selection cues, accessible names, and 32 pt targets.
- Emoji are stored as complete strings, including joined and variation sequences.
- Name changes save immediately. Escape or clicking outside closes the popover.
- Kept profile assignment in Settings → Spaces, outside the appearance popover.
- Widened the two sunrise lobes vertically (0.55 → 0.78, 0.60 → 0.82). Opacity
  remains 0.15 / 0.10. The mask now fades from 25% to 80% of the page height,
  keeping the top quarter free of color. No new loop, timer, or dependency.

## Interface review

Scope: native theme editor and changed new-tab light. SwiftUI/AppKit, existing
ChromeButtonStyle/ChromeMotion tokens, and the current native window sizes.
The user's latest brief takes priority over the historical Arc roadmap.
Used Better Accessibility, Layout, Writing, Typography, Colors, UI, and Interface.

| Domain | Evidence inspected | Result |
| --- | --- | --- |
| Accessibility | AX names, selected states, search, native controls, Escape, focus styling, Reduce Motion code | Clear in inspected paths; full VoiceOver walk not verified |
| Layout | 316 pt panel, shared 8-column grid, popover position, fixed-height scroll area | Initial edge overflow fixed; native desktop layout inspected |
| Writing | All SpaceEditor strings and icon labels | Removed footnotes; short search/empty labels; clear-search action |
| Typography | Name field and native control type, icon sizing, screenshot | System type retained; no small swatch captions |
| Colors | Study source pairs versus native presets; Red and Scarlet live selection | Study pairs retained; system panel foreground/background; full numeric contrast matrix not verified |
| UI | Hover/press reuse, selected outlines/checkmarks, live updates, bottom light | Uses existing short motion and Reduce Motion path |

No actionable interface findings remain in the inspected paths.

### Validation

- Xcode Debug test run: **198 tests, 43 suites passed**.
  `/tmp/cove-theme-popover-final-tests.log`.
- New checks verify that every offered SF Symbol exists on the supported system
  and that all emoji choices preserve one complete character through Codable.
- Later panel-position, backing, and focus changes were rebuilt successfully.
  `/tmp/cove-theme-popover-handoff-build.log`.
- Computer use on Virtual 16:9: open editor, inspect both grids, filter `cat`,
  select Cat, switch to Symbols, choose Scarlet, restore Red and the original
  dot, edit/restore the name, and dismiss with Escape. Changes persist across
  the app restart used for the visual pass.
- The final panel has no preview, intensity slider, custom color picker, or
  footnote. The new-tab background remains visible behind the popover.
- Not verified: complete VoiceOver walkthrough, full keyboard traversal of
  every icon, RTL/localization, live Increase Contrast/Reduce Transparency,
  every color in light appearance, and Settings profile reassignment live.
  CSS page zoom and 320 px mobile layouts do not apply to this native browser.
- Existing warnings in unrelated command-bar, extension, and pin code remain.
  No warning-free-repository claim. `git diff --check` passed.

**Approve** for the inspected native editor paths, with the limits above.

## Next work

Pinned tabs remain the next requested feature review. Also retain the open
end-to-end checks for download → Finder, close → restore, history search, and
profile/theme accessibility modes. No new work in these areas is claimed here.

Final handoff: opened the rebuilt app on Built-in Retina Display with the theme
popover visible. Confirmed the complete two-row palette, selected Red and dot,
name-field focus outline, and unblurred page behind it at the smaller window size.


## Latest follow-up: dots and stronger frame colors

The user rejected the icon/emoji picker and clarified that the colors still
felt dim. The final panel order is name, then colors. There is no icon section
or separator for an absent section.

- Removed the icon picker, search state, both 96-item catalogs, and their
  catalog-only tests. Removed the unused command-bar icon lookup and parameter.
- All space markers now draw the same 7 pt dot. The old icon enum remains only
  for saved-data compatibility; existing saved symbols and emoji still decode.
- Reduced the frame base's white mix from 60% to 22% and raised its opacity
  from 76% to 94%. This makes the existing colors more saturated and reduces
  dark desktop bleed, without increasing the new-tab glow or changing its mask.
- Kept the selected Fine grain texture, native material, and 8 pt softening.
- Inspected Dia live, then followed the user's correction: the issue to address
  is vibrance. No new exact Dia color-match claim is made.
- Debug tests: 196 tests / 42 suites passed. The count dropped by two because
  the removed icon catalog no longer needs its availability/round-trip tests.
  Log: `/tmp/cove-dots-vibrance-tests.log`.
- The final unused-parameter cleanup was built separately:
  `/tmp/cove-dots-vibrance-build.log`.
- Git history confirms no commits were made for this polish sequence. The user
  was told directly that logs are not commits and all changes are still local.
  No commit or push is claimed.
- Visual check on Virtual 16:9: confirmed the compact name-and-colors popover,
  dot markers, and stronger blue and purple frames. Returned to Space 2 and
  restored the hidden sidebar. Opened the latest build on Built-in Retina
  Display for the user to review. No claim that all 16 colors were checked.

## Thin frame and independent concentric corners

- Checked the previous committed layout: the page inset was already 8 pt. The
  color update did not increase it. Reduced it to 4 pt on all exposed edges.
  Kept sidebar row insets at 8 pt so their layout does not shrink with the frame.
- The page already used Apple's `ConcentricRectangle`, but with uniform radii.
  Changed the page clip and its shadow backing to use the same shape with
  independently resolved corners. Near window edges, SwiftUI supplies the
  concentric radius; corners farther inside retain the 8 pt minimum.
- Source: https://developer.apple.com/documentation/swiftui/concentricrectangle
  and the installed SwiftUICore SDK. Mintlify context was not exposed this turn.
- Debug build passed (`/tmp/cove-thin-frame-build.log`); diff whitespace check
  passed. No new tests for this small geometry change, and no full-suite rerun.
- Inspected sidebar shown and hidden on Virtual 16:9. Confirmed thinner borders
  and separate corner shapes. Returned the app to Built-in Retina Display with
  the sidebar hidden and Space 2 active. Full screen and top-tab mode were not
  checked in this pass.

## Compact space dots and name-only header

- Used the user's Dia/Cove footer screenshots as the visual reference. Dia's
  dots appear about 12 px across on a 24 px pitch, compared with Cove's 14 px
  dots on a 48 px pitch (interpreted at 2x display scale).
- Removed the dot and its reserved space from the sidebar title. The name
  remains the edit button, with the existing name transition and context menu.
- Footer dots are now 6 pt across on a 12 pt pitch, with a 24 pt tall click area.
  Inactive opacity is 0.28; active opacity remains 0.78. Hover still brightens
  through the shared button style. Other space markers keep their 7 pt size.
- Debug build passed (`/tmp/cove-compact-space-dots-build.log`). Checked the
  header and footer on Virtual 16:9 and clicked both space dots successfully.
  Returned to Space 2 and moved Cove to Built-in Retina Display with the sidebar
  visible for review. No full-suite rerun for this small visual edit.
