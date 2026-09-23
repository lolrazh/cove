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

## Third Pass: Tabs, History, and Input Bugs
Commits `9b14087..9b0b50d` on branch `chrome-redesign`.

- ✅ **Design tokens:** `ChromeRadius` holds per-component minimum radii for `ConcentricRectangle`. Text uses the system text styles (`.body`, `.callout`, `.subheadline`, `.caption`), and button styles set their own icon font.
- ✅ **One tab definition:** top and sidebar tabs share `ChromeTabItem`. A presentation only sets the height and how the active tab is drawn. The close button is bigger and only shows on hover.
- ✅ **Active tab = page color** (Dia-style). In the sidebar it's a raised card. In the top strip, `AttachedTabShape` flares its bottom corners into the content card.
- ✅ **Tab animation:** top tabs grow and shrink from zero width when opened and closed (the mask is oversized so the flares aren't clipped). The maximum width is 160.
- ✅ **History menu:** Back, Forward, Reopen Last Closed Tab (⇧⌘T), Recently Visited, Recently Closed, and Show All History (⌘Y). There's a separate History window with day groups, search, Copy Link and Delete. The history button is gone from the navigation bar.
- ✅ **Bugs fixed, all existing or introduced by the chrome rewrite:**
  - Commands used `focusedObject` and went disabled whenever nothing had focus. `focusedSceneObject` fixes it.
  - File › Close claimed ⌘W, so ⌘W closed the window. It's now Close Tab ⌘W and Close Window ⇧⌘W.
  - A `ConcentricRectangle` clip or `contentShape` puts the hit area in the wrong place: the content card swallowed every click and hover on the top tabs. Hit areas are now always `Rectangle()`.
  - The sidebar's `ScrollView` is extended by macOS up under the titlebar and covered the header button. The header now floats over the scroll view, with `contentMargins` insetting the list below it.
  - The URL queue was drained from a `@Published` publisher, which emits before the value is stored, so links waited for the next one. It now receives on the main queue.

## Key Learnings (Third Pass)
- **Hit testing:** don't use `ConcentricRectangle` for `clipShape` or `contentShape` on anything that must receive input. Draw with it; hit-test with `Rectangle`.
- **Bisecting input problems:** a bare `onHover` + `onTapGesture` probe placed at different levels of the tree found the blocking layer in a few builds. An `NSView.hitTest` dump only shows AppKit's view, not SwiftUI's internal routing.
- **Scroll views on macOS 26:** they extend under the titlebar (the scroll pocket). A view stacked *above* a scroll view can end up behind it for input. `safeAreaBar` fixes input but draws its own bar background and divider.
- **Wrong turn:** browser windows were briefly rewritten as AppKit `NSWindow` + `NSHostingView`, based on a wrong diagnosis (SwiftUI's toolbar region). That was dropped once the real cause was found; `WindowGroup` is fine.
- **Test scripts:** System Events `keystroke` goes to the frontmost app whatever the `tell` target is. Check that Cove is frontmost first.

## Ready for Next Session
- 🔧 The History window opens pages in whichever browser window is frontmost. Once internal pages exist in `TabSession`, an in-tab `cove://history` would match Safari and Dia.
- 🔧 The history includes many test visits (github.com, example.com) from this session.
- 🔧 Sidebar tabs still appear and disappear without the top strip's grow/shrink animation.

## Fourth Pass: Tab Row Polish
- ✅ **Taller tabs:** 30pt, with 6pt above and 4pt below (was 28pt with 6/6), measured against Dia. They sit 1pt below the traffic lights' centerline, which is intentional.
- ✅ **One radius in the tab row:** buttons in the titlebar band use `ChromeButtonStyle(size: .titlebar)`, which gives the tab height and the tab radius (10 = window radius of about 16, less the gutter).
- ✅ **Concentric close button:** each tab sets `containerShape(RoundedRectangle(10))`, and the close button is `.accessory(side: tabHeight - 8)` drawn with `ConcentricRectangle`, which comes out at a radius of about 6.
- ✅ **Tab width:** the widest a tab gets is an eighth of the strip, clamped to 120–220pt. Open/close motion is 0.18s.
- ✅ **Favicons:** `FaviconImage.make` is now the only decoder. Icons that are a single neutral tone become template images and are tinted like text (GitHub turns white in dark mode). Note that `NSBitmapImageRep.colorAt` returns straight (not premultiplied) components.
- ✅ The address bar no longer shows a favicon.
