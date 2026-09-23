# macOS 27 Chrome Rebuild

**Date:** 2026-09-23 → 2026-09-24
**Agent:** Claude Opus 5.5 (1M context)
**Branch:** `chrome-redesign`: 22 commits, not pushed
**Status:** ✅ Complete; the user is testing

## User Intention
The window chrome was falling apart on macOS 27:
- The sidebar didn't fit anywhere, and switching between sidebar and top tabs was broken.
- Tabs touched the top of the window, and the traffic lights overlapped the first tab in the old pre-Tahoe style.
- The design system had turned into a pile of one-off constants.

The user wanted it rebuilt properly: native macOS 27 traffic lights, Apple's concentric-corner API, squircles everywhere, quiet surfaces without heavy outlines, and much less code. Over four rounds of feedback, with Dia screenshots as reference, this grew into:
- a real tab system (a shared definition, a close button that appears on hover, the active tab in the page's color and attached to the page)
- a History menu and window
- favicons that adapt to light and dark mode
- a set of input bugs found along the way

The user also asked for small, frequent commits and careful engineering.

## What We Accomplished

### Window chrome
- ✅ **macOS 26 minimum.** `UIDesignRequiresCompatibility` was removed, which is what gives the system macOS 27 traffic lights.
- ✅ **The traffic lights are never moved.** An empty `.unifiedCompact` toolbar makes the titlebar 40pt and macOS centers the lights at y=20. `WindowChromeHost` only *reads* where the zoom button ended up and publishes `trafficLightInset` to SwiftUI. When tabs are hidden, the lights fade out and are then set `isHidden`, because at alpha 0 they were still clickable on top of the back button.
- ✅ **The titlebar-accessory tab strip is gone.** The whole shell is one SwiftUI layout under a transparent titlebar.
- ✅ **One layout, four modes:** top tabs, top hidden, sidebar, sidebar hidden. The docked sidebar and the tab row are always in the view tree and animate their size; the floating sidebar is an always-present overlay that slides by offset. Nothing is inserted into or removed from a stack, which fixes the mid-animation identity crash that `16df22a` had reintroduced.
- ✅ **The hidden sidebar and top strip no longer stick open.** Revealing schedules a hide right away, and moving onto the chrome cancels it.

### Design system (`ChromeTokens.swift`)
- ✅ **Corners:** one shape, `ConcentricRectangle` via `.chrome(minimum:)`, which is continuous and concentric with its container (ultimately the window). `ChromeRadius` holds only the *minimum* radius per component size: accessory 5, control 8, tab 10, tile 14, plus the 8pt flare where the active tab meets the page.
- ✅ **Text and icons:** system text styles (`.body` 13, `.callout` 12, `.subheadline` 11, `.caption` 10). SF Symbols size from the text style, and each button style sets its own icon font, so call sites don't.
- ✅ **Colors:**
  - The frame is `underPageBackgroundColor` and the page card is `textBackgroundColor`.
  - Interaction fills are palette tokens from the system fill hierarchy: `resting` = `.fill.quaternary`, `hover` = `.fill.secondary`, `pressed` = `.fill`.
  - The forced dark chrome is gone, so light mode is a real light mode.
- ✅ **No outlines on surfaces.** The card has none, the floating sidebar only has a shadow, and interactive states are fills. `Divider()` is the one separator.
- ✅ **Styles:**
  - `ChromeButtonStyle` sizes: `.icon` (navigation bar), `.titlebar` (tab height and tab radius, for anything in the tab row), `.accessory(side:)` (concentric with its container), and `.row`.
  - `chromeHoverSurface` handles hover on rows and tiles; `chromeFieldStyle` handles text fields.
  - `ChromePanelSurface.swift` was deleted.
- ✅ **Popovers are native.** History and Downloads no longer draw a panel, border and shadow inside the system popover.

### Tabs
- ✅ **One definition:** `ChromeTabItem` is shared by top and sidebar tabs. A presentation only sets the height (30 top, 32 sidebar) and how the active tab is drawn.
- ✅ **Active tab in the page's color, like Dia.** In the sidebar it's a raised card. In the top strip, `AttachedTabShape` extends it into the content card, with continuous top corners and flared bottom corners.
- ✅ **Close button:**
  - Appears only on hover, including on the active tab.
  - Dia's size and placement: it fills the tab's height less a 4pt inset.
  - Its corners are truly concentric: each tab sets `containerShape(RoundedRectangle(10))`, so the button's `ConcentricRectangle` comes out at a radius of about 6.
- ✅ **Tab row:** tabs are 30pt tall, with 6pt above and 4pt below. The **+** button and the sidebar toggle use `.titlebar`, so every shape in the row shares one radius: window (~16) less the gutter = 10.
- ✅ **Motion:** opening a tab grows its slot from zero width and reveals the tab from its leading edge, and closing reverses it, in 0.18s. The mask is oversized so the active tab's flares aren't clipped mid-animation.
- ✅ **Width:** a tab's maximum width is an eighth of the strip, clamped to 120–220pt, so tabs widen with the window.

### History
- ✅ **History menu:**
  - Back and Forward, moved there from the Browser menu, as in Safari.
  - Reopen Last Closed Tab (⇧⌘T).
  - Dia-style **Recently Visited** and **Recently Closed** sections with favicons.
  - Show All History… (⌘Y).
- ✅ **`RecentlyClosedTabs`** is app-wide and keeps the last 20 closed tabs that had a page. `HistoryStore` is now an `ObservableObject` publishing the last 8 distinct pages.
- ✅ **History window:**
  - Its own `Window` scene: grouped by day ("Today – Wednesday, September 23"), native toolbar search, rows with time, favicon, title and site, and no row dividers.
  - Double-click or Return opens the page in the frontmost browser window and brings it forward; the context menu has Copy Link and Delete.
  - The history popover and its button are gone from the navigation bar.

### Favicons
- ✅ **One decoder:** `FaviconImage.make(from:)` renders every favicon into a 64×64px bitmap. Icons whose visible pixels are almost all one neutral tone (near-black or near-white, no color) become template images, tinted like text. GitHub's black cat turns white in dark mode and follows appearance changes without refetching. Icons with color or their own background are untouched.
- ✅ The address bar no longer shows a favicon.

## Bugs Fixed (and Their Root Causes)
1. **⌘T, ⌘W, ⌘R and the other commands went dead after loading a page from the address bar.** `BrowserView` used `.focusedObject`, which is only published while a view in the window has keyboard focus. After Enter, nothing does. Fixed with `.focusedSceneObject`. *(Came from May commit `e6698d5`.)*
2. **⌘W closed the whole window.** File › Close also claimed ⌘W and, sitting earlier in the menu bar, won. `CommandGroup(replacing: .saveItem)` now provides Close Tab ⌘W and Close Window ⇧⌘W. *(From `e6698d5`.)*
3. **Top tabs ignored hover and clicks.** The content card was `.clipShape(.chrome())`, and a clip also sets the hit area. `ConcentricRectangle` resolves that hit area in the wrong place, over the tab strip. Hit areas are now always `.contentShape(Rectangle())`. *(Introduced by this rewrite.)*
4. **The sidebar's header button ignored input.** macOS 26 extends a scroll view up under the titlebar (the "scroll pocket"), so the tab list's `NSScrollView` covered the header row above it. The header now floats over the scroll view as an overlay, with `.contentMargins(.top, headerHeight)` for the list.
5. **Links from other apps (and later from History) waited for the next link before opening.** `BrowserView` drained the URL queue from `$queuedURLs`, but `@Published` emits *before* the value is stored, so the queue looked empty. It now receives on `DispatchQueue.main`. *(From `e6698d5`.)*
6. **The hidden sidebar stuck open** when the pointer left through the window edge (see Window chrome).

## Technical Implementation

**New files:**
- `UI/WindowChromeHost.swift` (rewritten): window configuration, measuring the traffic lights, their visibility, and `NSApplication.frontmostBrowserWindow`, found via `NSToolbar.Identifier.browserWindow`.
- `UI/Foundation/AttachedTabShape.swift`: the active top tab's shape, with top corners and bottom flares.
- `UI/HistoryWindow.swift`: the Show All History window.
- `App/HistoryMenu.swift`: the History menu content, in its own view so only it re-renders on history changes.
- `Browser/RecentlyClosedTabs.swift`: the closed-tab list.
- `Browser/FaviconImage.swift`: the favicon decoder and single-tone detection.

**Deleted:** `UI/Foundation/WindowChromeAccessor.swift`, `UI/Foundation/ChromePanelSurface.swift`, `UI/HistoryView.swift`.

**Rewritten:** `BrowserShellView`, `ChromeTokens`, `ChromeButtonStyle`, `ChromeFieldStyle`, `ChromeTabItem`, `SidebarTabView`, `TabStripView`.

Net: 31 source files, +1172 / −1226.

## Measured on macOS 27

Traffic lights, with no compatibility key (the toolbar style sets the titlebar height):

| Toolbar style | Titlebar | Close button x | Button top | Size |
|---|---|---|---|---|
| none | 32 | 9 | 9 | 14 |
| unifiedCompact | 40 | 12 | 13 | 14 |
| unified | 52 | 19 | 19 | 14 |

The buttons are 23pt apart; with the compact style the cluster ends at x=72. The window corner radius is about 16.

System colors:
- `windowBackgroundColor` and `textBackgroundColor` are **identical** (white / 0.118 gray).
- `underPageBackgroundColor` is 0.965 in light and 0.157 in dark.

## Key Learnings
- **`ConcentricRectangle` is for drawing only.**
  - As a `clipShape` or `contentShape`, its hit area lands in the wrong place.
  - It's a plain `Shape`: not `InsettableShape` (so no `strokeBorder`) and not `RoundedRectangularShape` (so it can't be a `containerShape`).
  - For nested concentric corners, give the parent `containerShape(RoundedRectangle(...))` and draw the child with `ConcentricRectangle`.
- **On macOS 26+ the window is itself a container shape.** A shape inset 6pt gets radius ≈10. Inset 20pt, it falls to 0 unless it has a minimum. `isUniform: true` keeps all four corners equal.
- **Don't stroke-then-clip for borders.** The clip eats the stroke on the curves, so borders look thinner at the corners. Prefer no border.
- **Scroll views on macOS 26 extend under the titlebar**, covering anything stacked above them. `safeAreaBar` fixes input but draws its own bar background and divider, so an overlay plus `contentMargins` is cleaner. `scrollEdgeEffectHidden` alone doesn't shrink the frame.
- **`@Published` emits in `willSet`.** A subscriber that reads the property instead of the emitted value sees the old value.
- **`NSBitmapImageRep.colorAt` returns straight (not premultiplied) components.** Checked empirically.
- **Bisecting input bugs:** a bare `onHover` + `onTapGesture` probe placed at successive levels of the tree finds the blocking layer in a few builds. An `NSView.hitTest` dump only shows which AppKit view got the event, not SwiftUI's internal routing.
- **Wrong turn:** the browser windows were briefly moved to AppKit `NSWindow` + `NSHostingView`, blaming SwiftUI's toolbar region. The real cause was the clip-shape hit area (bug 3). The rewrite was dropped before it was committed, and `WindowGroup` is fine.

## Architecture Decisions
- **Read the traffic lights, never move them.** Every earlier attempt to position them fought AppKit's titlebar layout (see the March logs). Layout adapts to where macOS puts them.
- **Adopt Apple's tokens rather than invent them.** Text styles, SF Symbol scaling, system fills and colors, and concentric shapes. Cove only defines layout metrics and minimum radii.
- **History in a window, not a tab.** An in-tab `cove://history` like Dia's needs internal-page support in `TabSession`, where the New Tab page is currently a special case tied into back/forward. The window is the smaller, decoupled step.
- **Tint single-tone favicons rather than follow the page.** Chromium shows the page's current favicon, and GitHub swaps its own for dark mode, but Cove caches one icon per site. Template tinting works for any site with a one-color icon and follows appearance changes for free.

## Testing Notes
- Verified by screenshots of the running app in light and dark mode, all four tab modes, hover states, a frame burst of the tab-open animation, and the History menu and window.
- Test harness (in the session scratchpad, not the repo):
  - `defaults write com.cove.browser browser.showTabsInSidebar/hideTabs -bool true|false` switches modes; this reaches the sandboxed app.
  - `-NSRequiresAquaSystemAppearance YES` forces light mode for Cove alone.
  - CGEvent mouse moves and clicks in window-relative coordinates.
- ⚠️ **System Events `keystroke` goes to the frontmost app, whatever the `tell` target.** Scripts must check that Cove is frontmost first. Early in the session some keystrokes may have gone to the user's Dia.
- Cove's history DB now holds many github.com and example.com visits from testing.

## Ready for Next Session
- 🔧 **Unverified:** the tab animation's feel at 0.18s, and tab widths on small windows. Waiting on the user.
- 🔧 **History in a tab:** add internal pages to `TabSession` (and fold the New Tab page into the same mechanism), then show `cove://history` in a tab like Dia and Safari.
- 🔧 The History window opens pages in the frontmost browser window, even with several windows open.
- 🔧 Sidebar tabs appear and disappear without the top strip's grow/shrink animation.
- 🔧 When top tabs are hidden, revealing them pushes the page down, while the hidden sidebar floats over it.
- 🔧 The Settings window hasn't been restyled.
- 🔧 `example.com` pages record an empty title in history: the title isn't set yet when `didFinish` fires.

## Context for Future
The shell is now small and declarative. Everything positions itself from two facts macOS provides (the 40pt compact titlebar and the traffic-light cluster), and every corner is `ConcentricRectangle`, drawn only. When a control in the top 40pt stops responding, check two things first: a concentric shape used as a clip or hit area, and a scroll view extending under the titlebar. The user cares about native feel, correct concentric rounding, and quiet surfaces, and compares closely against Dia. Expect pixel-level feedback, and measure the reference screenshots rather than guessing.
