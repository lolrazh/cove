# Traffic Light Native Ownership — Stop Fighting macOS

**Date:** 2026-03-07
**Agent:** Claude Opus 4.6
**Status:** ✅ Completed
**Building on:** `2026-03-07_1100_unified-chrome-strip-architecture.md`

## User Intention
User wanted rock-solid, native-looking traffic light buttons that don't drift, jitter, or lose positioning when switching between tab modes (top/sidebar) and visibility states (show/hide tabs). They also wanted the green button's native tiling menu (Move & Resize, Fill & Arrange, Full Screen) to work — which is a macOS Sequoia system feature with no public API to replicate.

## What We Accomplished
- ✅ **Native traffic lights with zero positioning fights** — macOS fully owns button position, appearance, and behavior
- ✅ **Alpha-only visibility control** — buttons fade with the chrome strip, no `isEnabled`/`isHidden`/`setFrameOrigin` manipulation
- ✅ **Green button tiling menu works** — native macOS Sequoia window tiling menu appears on hover
- ✅ **Mode switch double-click fix** — `TabManager` subscriber guard prevents redundant `apply()` calls
- ✅ **Tab strip no longer overlaps traffic lights** — padding properly accounts for native button positions
- ✅ **Massively simplified WindowChromeAccessor** — removed `WindowChromeControlsStyle`, `WindowChromeController`, all positioning/caching code

## Technical Implementation

### The Journey: Three Approaches Tried

**Approach 1 — Position native buttons ourselves (original, failed):**
Multiple attempts to use `setFrameOrigin` on `NSWindow.standardWindowButton()`. Every fix for one bug introduced another. Root cause: macOS's titlebar layout system periodically reclaims button frames, especially after `isEnabled` or `isHidden` toggles. The deduplication cache prevented re-correction after macOS overrides. The green (zoom) button drifted most because it accumulated the largest positional difference from macOS defaults.

**Approach 2 — Custom SwiftUI traffic lights (worked visually, incomplete):**
Created `TrafficLightsView` with custom circles, SF Symbol hover icons, and `ButtonStyle` for pressed states. Eliminated all AppKit fighting. However: symbols didn't match native appearance, and critically, the green button's tiling menu (macOS Sequoia) has no public API — it can only be triggered through the actual native zoom button.

**Approach 3 — Let macOS own everything, alpha-only control (final, shipped):**
Don't touch native buttons at all — no positioning, no isEnabled, no isHidden. Only toggle `alphaValue` (0 when hidden, 1 when visible). macOS handles everything: position, appearance, hover effects, tiling menu. The hover reveal zone in hide-tabs mode fires before the user reaches the button area, so the tiling menu always appears with visible buttons.

### Architecture
```
WindowChromeAccessor (NSViewRepresentable)
├── Measures titlebar height (for layout)
└── Toggles native button alphaValue (for hide/show)
    └── Never touches: isEnabled, isHidden, frame

WindowChromeHost
├── Takes isVisible: Bool
├── Passes to WindowChromeAccessor
└── Provides titlebarHeight via @Environment

BrowserView
├── Computes stripVisible = !hideTabs || areTabsVisible
└── Passes to WindowChromeHost
```

**Files Modified:**
- `Cove/Sources/UI/Foundation/WindowChromeAccessor.swift` — Gutted positioning code, added alpha-only visibility
- `Cove/Sources/UI/WindowChromeHost.swift` — Takes `isVisible` instead of `controlsStyle`
- `Cove/Sources/UI/BrowserView.swift` — Computes `stripVisible`, removed `chromeControlsStyle`
- `Cove/Sources/UI/BrowserShellView.swift` — Removed custom TrafficLightsView overlay
- `Cove/Sources/App/AppDelegate.swift` — Removed `hideNativeTrafficLights`
- `Cove/Sources/UI/Foundation/ChromeTokens.swift` — Restored `shellControlsButtonSize = 16`
- `Cove/Sources/UI/TitlebarTabStripAccessory.swift` — Reverted padding to native-button defaults
- `Cove/Sources/Browser/TabManager.swift` — Added guard for redundant subscriber `apply()`
- `Cove/Sources/UI/Foundation/TrafficLightsView.swift` — Deleted (no longer needed)

## Bugs & Issues Encountered

1. **Green (zoom) button drifting right on hide/show toggle**
   - **Root cause:** `isEnabled = false` triggered macOS titlebar re-layout. macOS moved buttons to its defaults. Deduplication cache skipped re-correction. Zoom button had largest absolute difference from macOS defaults, so most visible drift.
   - **Fix attempts:** Cached button size (didn't help — macOS overrides position, not size), token-based sizing (wrong values made it worse), alpha-only without frame changes (still failed because `setFrameOrigin` on every call fought macOS layout).
   - **Final fix:** Stop touching native buttons entirely. Alpha-only control.

2. **Mode switch requiring double-click**
   - **Root cause:** `settings.$showsTabsInSidebar` subscriber in TabManager lacked a guard. When `setLayout()` persisted the preference, the subscriber fired `apply()` again outside `withAnimation`, creating a competing non-animated update.
   - **Fix:** Added `guard self.tabLayout != newLayout` to skip redundant `apply()`.

3. **Tabs overlapping traffic lights (during custom buttons phase)**
   - **Root cause:** Hiding native buttons made the `.left` titlebar accessory start at x=0 instead of after the buttons. The 10pt leading padding was insufficient.
   - **Fix:** Increased padding to `shellControlsLeadingInset + shellControlsClusterWidth + shellControlsGapToTabs` (74pt). Reverted when switching back to native buttons.

4. **Custom traffic light symbols looking wrong**
   - **Root cause:** SF Symbols (`xmark`, `minus`, `arrow.up.left.and.arrow.down.right`) don't match the exact native traffic light icon rendering at 12pt.
   - **Resolution:** Abandoned custom approach entirely in favor of native buttons.

## Key Learnings

- **Never fight macOS on native window button positioning.** `setFrameOrigin` on standard window buttons is inherently unstable. macOS's titlebar layout system reclaims frames unpredictably — on `isEnabled` change, `isHidden` change, window activation, display change, and more. The deduplication cache that prevents jitter also prevents recovery after macOS overrides.

- **`isEnabled = false` on standard window buttons triggers macOS re-layout.** This is the specific trigger that causes frame corruption. Even `isHidden = true` causes macOS to reclaim `frame.width`, making it return stale values.

- **The green button's tiling menu (macOS Sequoia) has no public API.** It can only appear via the native zoom button. Any custom implementation that replaces native buttons loses this feature permanently.

- **`alphaValue` is the safest way to hide native controls.** It doesn't trigger re-layout, doesn't affect frame geometry, and buttons at alpha 0 are effectively invisible. The minor hit-test concern (invisible buttons still hittable) is mitigated by the hover reveal zone.

- **Combine `@Published` subscribers without `.removeDuplicates()` cause re-entrancy.** When `setLayout()` persists a setting that the subscriber also watches, the subscriber fires redundantly. Always guard against the current value or use `.removeDuplicates()`.

## Architecture Decisions

- **Native buttons over custom SwiftUI** — Sacrifices custom positioning control, gains native appearance, tiling menu, accessibility, and zero maintenance. The trade-off is clearly worth it.

- **Alpha-only visibility (no isEnabled)** — Invisible buttons remain hittable, but the hover reveal zone makes this a non-issue in practice. The alternative (isEnabled toggling) causes the exact frame corruption we spent hours debugging.

- **stripVisible computed in BrowserView** — Single source of truth for traffic light visibility, passed down through WindowChromeHost to the accessor. Cleaner than having the accessor compute it from multiple state sources.

## Ready for Next Session
- ✅ **Traffic lights are rock solid** — Native, positioned by macOS, alpha-controlled
- ✅ **Mode switching works in one click** — TabManager subscriber guard in place
- ✅ **Tab strip spacing correct** — Original padding works with native button positions
- 🔧 **Unused tokens** — `shellControlsLeadingInset`, `shellControlsVerticalOffset`, etc. are no longer used for positioning but still used for tab strip reservation. Could be simplified.
- 🔧 **Display-change strip artifact** — The darker strip on screen change may still appear occasionally (macOS rendering quirk). AppDelegate re-applies config on `didChangeScreenNotification`.

## Context for Future
This session resolved the longest-running issue in the chrome architecture: traffic light positioning stability. The key insight — don't fight macOS, let it own native controls — applies broadly to any future AppKit/SwiftUI hybrid work in Cove. The `WindowChromeAccessor` is now a clean, minimal bridge that measures titlebar height and toggles button alpha. Any future traffic light work should respect the rule: **never call setFrameOrigin, isEnabled, or isHidden on standard window buttons.**
