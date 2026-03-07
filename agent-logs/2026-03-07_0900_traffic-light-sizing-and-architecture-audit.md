# Cove Browser — Traffic Light Sizing Fix & Architecture Audit

**Date:** 2026-03-07
**Agent:** Claude Opus 4.6
**Status:** ✅ Completed

## User Intention
User wanted to fix the long-standing issue of Cove's traffic light buttons (close/minimize/zoom) appearing visually smaller than in native apps like Finder, Ghostty, Safari, and Activity Monitor. This had been an ongoing frustration across multiple sessions. The user also wanted an architecture audit of the full codebase to understand modularity, code quality, and what needs work before tackling sidebar mode redesign.

## What We Accomplished
- ✅ **Identified root cause of small traffic lights** — `UIDesignRequiresCompatibility = true` in Info.plist forces macOS 26 Tahoe to render ALL UI (including native traffic light buttons) in legacy compatibility mode (12x14 instead of 16x16)
- ✅ **Fixed traffic lights to match native apps** — removed the key from Info.plist; Cove's close button now measures 16x16 via accessibility, matching Finder and Ghostty exactly
- ✅ **Completed full architecture audit** — reviewed all 34 source files across App, UI, Foundation, Browser, and Settings layers
- ✅ **Researched Ghostty's window management approach** — read their full Tahoe and Ventura window style implementations from GitHub for comparison
- ✅ **Built diagnostic measurement tooling** — created accessibility-based button measurement scripts that compare traffic light sizes across running apps in real-time

## Technical Implementation

### The Traffic Light Fix
The entire fix was removing two lines from `Cove/Resources/Info.plist`:
```xml
<key>UIDesignRequiresCompatibility</key>
<true/>
```

This key was originally added to opt Cove out of macOS 26's Liquid Glass design system. However, it's a process-level flag that affects ALL rendering — including Apple's own native `standardWindowButton` controls. With it set to `true`, traffic light buttons render at 12x14 (legacy). Without it, they render at 16x16 (Liquid Glass native).

### What We Ruled Out (Extensive Testing)
The following were all tested and confirmed NOT to be the cause:
- `.windowStyle(.hiddenTitleBar)` vs `.titleBar` — no effect
- `.windowToolbarStyle(.unifiedCompact)` vs `.unified` — changes container height (38pt vs 52pt) but not button size
- `titlebarAppearsTransparent = true` — no effect on button size
- `window.isOpaque = true` — no effect
- `.fullSizeContentView` style mask — no effect
- `NSWindow.allowsAutomaticWindowTabbing = false` — no effect
- `window.tabbingMode = .disallowed` — no effect
- SwiftUI `WindowGroup` vs pure `NSWindow` creation — no effect
- SwiftUI `@main App` lifecycle vs pure `main.swift` + `NSApplication.run()` — no effect
- `NSHostingView` vs plain `NSView` content — no effect

### Measurement Data

| App | Close Button (Accessibility) | Window Type |
|-----|------------------------------|-------------|
| Finder | 16x16 | System/AppKit |
| Ghostty | 16x16 | AppKit (storyboard) |
| **Cove (before)** | **12x14** | SwiftUI WindowGroup |
| **Cove (after)** | **16x16** | SwiftUI WindowGroup |
| Discord | 12x14 | Electron |
| Spoke | 12x14 | Unknown |

### Architecture Audit Key Findings

**Strong areas:**
- Foundation layer (`ChromeTokens`, `ChromeButtonStyle`, `ChromePanelSurface`) — excellent design system
- Top mode architecture — clean separation: `TopBrowserShellView` (pure layout) + `WindowChromeHost` (titlebar compensation) + `TitlebarTabStripAccessory` (AppKit bridge)
- AppKit concerns properly isolated to bridge files
- Design tokens eliminate magic numbers; nested corner radii computed mathematically

**Areas needing work:**
1. **Sidebar mode is the weakest code path** — `BrowserView.sidebarShell()` (lines 48–94) duplicates NavigationBar, loading indicator, and content layout that `TopBrowserShellView` already handles. Needs a `SidebarBrowserShellView` extraction.
2. **Duplicated code:** `contentLoadingIndicator` identical in two files; tab reveal/hide hover logic duplicated with inconsistent timing (700ms vs 750ms)
3. **`WebViewModel` does too much** — favicon fetching/rendering/storing (lines 108–156) should be separated
4. **`FaviconStore` has redundant methods** — `get()` and `image()` do the same thing

**Files Modified:**
- `Cove/Resources/Info.plist` — removed `UIDesignRequiresCompatibility` key
- `Cove/Sources/App/CoveApp.swift` — changed `.windowStyle(.hiddenTitleBar)` → `.windowStyle(.titleBar)` (kept from earlier experiment)
- `Cove/Sources/UI/Foundation/WindowChromeAccessor.swift` — removed debug diagnostics

## Bugs & Issues Encountered
1. **Traffic lights appeared smaller than native apps across all sessions**
   - **Root cause:** `UIDesignRequiresCompatibility = true` in Info.plist is a process-level flag on macOS 26 that forces legacy rendering of ALL UI elements, including Apple's own native window buttons
   - **Fix:** Removed the key entirely from Info.plist

2. **Diagnostic prints not appearing**
   - **Root cause:** App sandbox (`com.apple.security.app-sandbox = true`) prevents writing to `/tmp` or `~/`; `print()` doesn't reach stdout from app bundles; `NSLog` didn't appear in `log show`
   - **Fix:** Used `FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)` which maps to the sandbox container at `~/Library/Containers/com.cove.browser/Data/Library/Caches/`

3. **Initial hypothesis about SwiftUI WindowGroup was wrong**
   - **Root cause:** Assumed `AppKitWindow` (SwiftUI's window class) was creating smaller buttons vs plain `NSWindow`. Tested extensively with pure AppKit lifecycle, `main.swift`, even zero-SwiftUI windows — all still 12x14
   - **Resolution:** The issue was process-level (Info.plist), not window-level

## Key Learnings
- **`UIDesignRequiresCompatibility` is nuclear** — it doesn't just opt out of Liquid Glass on your custom chrome; it opts out of Liquid Glass on Apple's own native controls too, including traffic light buttons. On macOS 26, this makes them visually smaller.
- **You can have custom chrome AND native traffic lights** — removing `UIDesignRequiresCompatibility` while keeping `titlebarAppearsTransparent = true` gives you full-size native buttons with your own transparent titlebar. The two are independent.
- **Accessibility API measures visual/hit-target size, not NSView frame** — NSView frame for traffic lights is 14x16 regardless, but accessibility reports 12x14 (legacy) vs 16x16 (Liquid Glass) because the glass effect extends the visual footprint.
- **Sandboxed apps can't write to /tmp or ~/** — use `FileManager.default.urls(for: .cachesDirectory)` for diagnostic output.
- **Ghostty's window approach is instructive** — they use storyboard-based NSWindow subclasses, manipulate private view hierarchy (`NSTitlebarBackgroundView`, `NSTitlebarView`), and have completely separate Tahoe vs Ventura code paths. Their Tahoe path does NOT use `titlebarAppearsTransparent` — instead they hide `NSTitlebarBackgroundView` and set the titlebar view's layer background directly.

## Architecture Decisions
- **Keep `UIDesignRequiresCompatibility` removed** — the custom chrome (transparent titlebar, shell layout, dark top strip) still works without it. Traffic lights get native Liquid Glass treatment, which is correct since they ARE native Apple controls.
- **Keep `.windowStyle(.titleBar)`** — changed from `.hiddenTitleBar` during investigation; this is a better default as it tells SwiftUI to create a normal titled window
- **Sidebar mode needs its own shell view** — the architecture audit confirmed that extracting `SidebarBrowserShellView` (mirroring `TopBrowserShellView`) is the right next step

## Ready for Next Session
- ✅ **Traffic lights are native-sized** — 16x16, matching Finder/Ghostty/Activity Monitor
- ✅ **Architecture audit is complete** — clear picture of what needs refactoring
- ✅ **Top mode architecture is solid** — can serve as template for sidebar mode
- 🔧 **Sidebar mode needs redesign** — extract `SidebarBrowserShellView` with same two-layer shell architecture as top mode
- 🔧 **Check for Liquid Glass side effects** — verify the shell chrome doesn't get unwanted glass effects now that `UIDesignRequiresCompatibility` is removed
- 🔧 **Deduplicate shared components** — loading indicator, hover-to-reveal logic, content panel should be shared between top and sidebar modes
- 🔧 **Commit the traffic light fix** — clean working tree ready for commit

## Context for Future
This session solved the most persistent visual issue in Cove's development — traffic lights that looked "off" compared to native apps. The root cause was a single Info.plist key (`UIDesignRequiresCompatibility`) that was added to opt out of Liquid Glass but had the unintended side effect of downgrading ALL native controls to legacy rendering. The fix is proven with measurement data. The next session should focus on sidebar mode redesign (the weakest part of the codebase per the architecture audit) and checking for any unwanted Liquid Glass effects on the custom chrome now that the compatibility flag is removed.
