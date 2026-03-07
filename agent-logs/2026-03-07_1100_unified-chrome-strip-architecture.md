# Cove Browser — Unified Chrome Strip Architecture

**Date:** 2026-03-07
**Agent:** Claude Opus 4.6
**Status:** ✅ Completed
**Building on:** `2026-03-07_0900_traffic-light-sizing-and-architecture-audit.md`

## User Intention
User wanted to unify the sidebar and top bar into a single architectural concept — one "chrome strip" that contains tabs and traffic lights, positioned at the top in horizontal mode and on the left in sidebar mode. The strip should expand/contract in both modes (no floating overlay sidebar), traffic lights should never reposition between modes, and switching between all four mode combinations (top/sidebar × show/hide) should be crash-free with smooth animations.

## What We Accomplished
- ✅ **Fixed traffic light positioning** — Removed `centerlineFromTop` from `WindowChromeControlsStyle`. Traffic lights always center in the native titlebar. Position never changes between modes; only visibility toggles.
- ✅ **Stabilized titlebar height** — `TitlebarTabStripAccessory` is always installed (never removed/hidden). When tabs aren't visible, it shows `Color.clear` instead of setting `isHidden = true`. This prevents titlebar height changes that caused traffic light jumps and floating tab artifacts.
- ✅ **Removed top dark band in sidebar mode** — `topSlotHeight` returns `shellGutter` (6pt) in sidebar mode instead of `topBandHeight` (44pt). Content panel adds internal titlebar clearance via `sidebarTitlebarClearance`.
- ✅ **Unified traffic light visibility** — Both modes use `!hideTabs || areTabsVisible`. Traffic lights hide/show with the chrome strip in both modes.
- ✅ **Sidebar always in layout with animated width** — Sidebar is always present in the HStack (no conditional insertion). Width animates between 0 and `sidebarWidth`. Eliminates the crash on Top+Show → Side+Show transition.
- ✅ **Removed overlay sidebar entirely** — Deleted `SidebarTabPresentation` enum, all overlay code, overlay hover logic, reveal handle. Sidebar now expands/contracts like the top strip. (-136 lines)
- ✅ **Unified hover/reveal logic** — `handleChromeHover` works for both modes (removed `guard .horizontal`). Added `sidebarRevealArea` mirroring `topRevealArea`.
- ✅ **Added titlebar height environment plumbing** — `TitlebarHeightKey` environment value propagated from `WindowChromeHost` so descendants can adapt layout.

## Technical Implementation

### The "One Strip, Two Orientations" Architecture
```
Shell (HStack — STABLE, never changes structure)
├── Sidebar (ALWAYS present, width: 0 or 240, clipped)
└── VStack (ALWAYS present)
    ├── topChromeZone (height: 44 or 6, animated)
    └── contentPanel (nav + separator + content)

Overlays:
├── topRevealArea    (horizontal + hidden)
├── sidebarRevealArea (sidebar + hidden)

Background:
└── TitlebarTabStripAccessory (ALWAYS installed, content: tabs or Color.clear)

Traffic lights:
├── Position: FIXED (centered in titlebar, never recalculated)
└── Visibility: !hideTabs || areTabsVisible
```

### Key Visibility Flags
| Flag | Condition |
|------|-----------|
| `showsTopStrip` | horizontal AND (!hideTabs OR areTabsVisible) |
| `showsSidebar` | sidebar AND (!hideTabs OR areTabsVisible) |
| `isHorizontalImmersive` | horizontal AND hideTabs AND !areTabsVisible |
| `isSidebarImmersive` | sidebar AND hideTabs AND !areTabsVisible |

### Why the View Tree Must Be Stable
SwiftUI crashes when `if/else` branches change the view tree during animation. The fix: the sidebar is ALWAYS in the HStack (width animates, `.clipped()`). The top chrome zone is ALWAYS present (height animates). No views are added or removed — only their dimensions change.

**Files Modified:**
- `Cove/Sources/UI/Foundation/ChromeTokens.swift` — Added `TitlebarHeightKey` environment key; removed `topStripLaneCenterFromTop` token
- `Cove/Sources/UI/WindowChromeHost.swift` — Propagates `titlebarHeight` via `.environment()`
- `Cove/Sources/UI/Foundation/WindowChromeAccessor.swift` — Removed `centerlineFromTop` from `WindowChromeControlsStyle`; simplified `resolvedBaseY` to always center
- `Cove/Sources/UI/BrowserView.swift` — Simplified `chromeControlsStyle` (no `centerlineFromTop`, unified `isVisible`)
- `Cove/Sources/UI/BrowserShellView.swift` — Sidebar always in HStack with animated width; removed overlay; added `sidebarRevealArea`; generalized `handleChromeHover`; accessory always installed
- `Cove/Sources/UI/TitlebarTabStripAccessory.swift` — Never sets `isHidden`; shows `Color.clear` when not visible
- `Cove/Sources/UI/SidebarTabView.swift` — Removed `SidebarTabPresentation` enum, all overlay code, hover/reveal logic; simplified to just the tab list and header

## Bugs & Issues Encountered

1. **Traffic lights jumped/got wonky when switching modes**
   - **Root cause:** `TitlebarTabStripAccessory` was conditionally installed (`if .horizontal`). Removing it changed the titlebar height. Also, `centerlineFromTop` switched between a value and nil, changing Y calculation.
   - **Fix:** Always install the accessory (show empty content when not visible). Remove `centerlineFromTop` — always center in titlebar.

2. **Tabs floated above nav bar in top+hide mode**
   - **Root cause:** `accessoryController.isHidden = true` per Apple docs "removes its contribution to titlebar height." Titlebar shrank during animation, causing the tab strip content to be briefly visible at wrong position.
   - **Fix:** Never set `isHidden`. Swap content to `Color.clear` instead. Titlebar height stays constant.

3. **Crash on Top+Show → Side+Show switch**
   - **Root cause:** `if showsIntegratedSidebar` inside the HStack changed the view tree structure during animation, breaking SwiftUI view identity.
   - **Fix:** Sidebar always present in HStack. Width animates between 0 and 240pt with `.clipped()`.

4. **Uneven traffic light spacing in sidebar mode**
   - **Root cause:** Same as #1 — titlebar height change caused `resolvedBaseY` to compute different values, and the animated transition made it visible.
   - **Fix:** Stable titlebar height + fixed centering.

## Key Learnings
- **`NSTitlebarAccessoryViewController.isHidden = true` removes titlebar height contribution** — Apple docs confirm this. Never hide the accessory if you need stable titlebar geometry. Show empty content instead.
- **SwiftUI view tree stability is critical during animation** — `if/else` that adds/removes views from a container (HStack, VStack) will crash during animated transitions. Always keep the view present and animate its size (width/height to 0 with `.clipped()`).
- **Traffic light positioning should be dumb** — Don't compute per-mode positions. Just center in the titlebar. The titlebar height is the only input. Keep it constant, and the buttons never move.
- **One hover handler for all modes** — The hide/reveal logic is identical for top strip and sidebar. The only variable is which dimension animates (height vs width). The timer, delay, and state management are the same.
- **Overlay sidebar was unnecessary complexity** — Two separate code paths (overlay vs integrated), two surfaces (`.sidebar` vibrancy vs transparent on dark frame), two hover systems. Replacing with animated width is simpler and more consistent.

## Architecture Decisions
- **Always-installed titlebar accessory** — Trade-off: the accessory takes up titlebar space in sidebar mode (44pt). But since the shell extends into the titlebar via `WindowChromeHost`'s negative padding and the titlebar is transparent, this is invisible. The benefit (stable traffic lights, no floating tabs) far outweighs the cost.
- **Sidebar width animation vs overlay** — The user explicitly requested expand/contract behavior matching the top strip. This also eliminates the crash, removes ~136 lines of overlay code, and unifies the hover/reveal logic.
- **No `centerlineFromTop`** — The math works out to the same Y position when titlebar height equals `topBandHeight` (both center at the same point). Removing it eliminates a source of positioning bugs and simplifies the style struct.

## Ready for Next Session
- ✅ **All four mode combinations work** — Top/Sidebar × Show/Hide tested by user, confirmed "absolutely gorgeous"
- ✅ **Traffic lights stable** — Fixed position, no jumps on mode switch
- ✅ **Clean git history** — 6 commits, each a meaningful step
- 🔧 **Content panel top-left corner radius** — In sidebar mode, the content panel's rounded top-left corner creates a small visual gap where it meets the sidebar. May want `UnevenRoundedRectangle` for a flush junction.
- 🔧 **Sidebar header titlebar clearance** — The `sidebarHeader` uses `shellStripHeight + 18` (54pt) which works but is a magic number. Could be derived from `titlebarHeight` environment value.
- 🔧 **`sidebarRevealHandleWidth` token** — Now unused in code (overlay removed). Can be cleaned up.

## Context for Future
This session completed the major architectural unification of Cove's chrome system. Both tab layouts (horizontal top bar, vertical sidebar) now share the same two-layer shell, the same hover/reveal pattern, and the same traffic light management. The view tree is stable (no conditional insertion/removal), which eliminates animation crashes. The next focus areas are visual polish (corner radii at sidebar/content junction, spacing refinements) and potentially the favicon/WebViewModel separation identified in the earlier architecture audit.
