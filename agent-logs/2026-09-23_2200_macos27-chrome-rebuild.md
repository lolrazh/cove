# macOS 27 Chrome Rebuild

**Date:** 2026-09-23
**Agent:** Claude Opus 5.5 (1M context)
**Status:** ✅ First pass complete, awaiting user testing

## User Intention
The window chrome was broken on macOS 27: the sidebar didn't fit anywhere, switching between sidebar and top tabs was glitchy, tabs touched the top of the window, the traffic lights overlapped the first tab and still used the old pre-macOS 26 style, and the design system had drifted into a pile of one-off constants. The user wanted all of it fixed, with macOS 27 traffic lights and the concentric-corner API.

## What We Accomplished
- ✅ **Deployment target raised to macOS 26**, and `UIDesignRequiresCompatibility` removed from Info.plist. The traffic lights now use the macOS 26+ style.
- ✅ **The traffic lights are never moved.** An empty `.unifiedCompact` toolbar makes the titlebar 40pt tall, and macOS centers the lights at y=20. The shell reads the zoom button's `maxX` and lays out around it.
- ✅ **The titlebar accessory is gone.** The tab strip is plain SwiftUI inside the shell. Clicks under a transparent titlebar with an empty toolbar reach the content (checked with `hitTest` and a real click on the + button).
- ✅ **One layout for all four modes.** The docked sidebar and the tab row always stay in the view tree and animate their size. The floating sidebar is an always-present overlay that slides by offset. Nothing is inserted into an HStack/VStack, so there's no identity crash (a March regression that commit `16df22a` reintroduced).
- ✅ **The hidden sidebar no longer gets stuck open.** Revealing now schedules a hide right away, and moving onto the chrome cancels it.
- ✅ **Hidden traffic lights are `isHidden` after fading out.** At alpha 0 they were still clickable, right on top of the card's back button.
- ✅ **Design tokens rebuilt** around `titlebarHeight = 40`, `gutter = 6` and `tabHeight = 28`, plus a `ChromeRadius` scale. The `shellControls*` constants were removed.
- ✅ **Concentric corners.** The content card and the floating sidebar use `ConcentricRectangle` (with an 8pt minimum), so they follow the window's corner radius automatically.
- ✅ The sidebar header now holds the traffic lights and a dock/undock toggle. The duplicate downloads button was removed; it's still in the navigation bar.

## Measured on macOS 27 (no compatibility key)
| Toolbar style | Titlebar | Close button x | Button top | Size |
|---|---|---|---|---|
| none | 32 | 9 | 9 | 14 |
| unifiedCompact | 40 | 12 | 13 | 14 |
| unified | 52 | 19 | 19 | 14 |

The buttons are 23pt apart. With the compact style the cluster ends at x=72.

## Key Learnings
- `ConcentricRectangle` is only a `Shape`: it isn't `InsettableShape`, so there's no `strokeBorder`, and it can't be used with `containerShape`. Draw the border as a centered stroke at 2× width, then clip.
- On macOS 26+, the window itself is a container shape. A `ConcentricRectangle` inset 6pt gets a radius of about 10pt (the window radius is about 16). Inset 20pt, it falls to 0 unless a minimum is given.
- `defaults write com.cove.browser …` reaches the sandboxed app's preferences. Use `true`/`false`, not `0`/`1`.

## Ready for Next Session
- 🔧 Only checked in dark mode. Light mode keeps the dark shell with a light card, which hasn't been checked on screen.
- 🔧 The sidebar rows' leading inset (10pt) is about 2pt off the traffic lights when docked, and 4pt off the other way when floating.
- 🔧 The top-tabs hidden mode still pushes the content down on reveal. The sidebar floats over it instead, so the two could be made consistent.
- 🔧 Settings, history and download popovers only got token renames. They weren't redesigned.

## Second Pass: Native Simplification
The user asked for less complexity, native corner rounding, consistent squircles, and quieter borders. They also noticed that borders got thinner toward the corners.

- ✅ **One shape everywhere:** `.chrome(minimum:)` wraps `ConcentricRectangle`, which is continuous and concentric with the window. `RoundedRectangle` and the `ChromeRadius` scale are gone.
- ✅ **No outlines on surfaces.** The thinning at the corners came from the "stroke at 2× width, then clip" trick. The card has no border now, the floating sidebar only has a shadow on its background shape, and tabs, tiles and buttons use fills only. `Divider()` is used for the one separator.
- ✅ **System colors:**
  - The frame is `underPageBackgroundColor` and the card is `textBackgroundColor`.
  - On macOS 27, `windowBackgroundColor` equals `textBackgroundColor` in both appearances (white in light, 0.118 gray in dark), so using it makes the card disappear.
  - Hover, press and selection use `.fill.tertiary` and `.fill.secondary`.
  - The forced `.colorScheme(.dark)` on the chrome is gone, so light mode is real.
- ✅ **Popovers are native.** History and Downloads no longer draw their own panel, border and shadow inside the system popover. History lost its redundant close button and uses a `.roundedBorder` search field. "Clear" is `.borderless`.
- ✅ **Styles merged:** three style files became two. `ChromeButtonStyle` has three sizes (icon, accessory, row), `chromeHoverSurface` handles hover and selection, and `chromeFieldStyle` shows the system focus-ring color only while focused. The press scale is 0.96.
- UI code went from 2219 lines (at HEAD) to 1757.
- Checked in light and dark mode: top tabs, docked sidebar, floating sidebar, and the history popover.
