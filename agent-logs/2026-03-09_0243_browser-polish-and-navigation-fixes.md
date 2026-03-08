# Browser Polish & Navigation Fixes

**Date:** 2026-03-09
**Agent:** GPT-5.4
**Status:** ✅ Completed
**Building on:** `2026-03-07_2349_browser-architecture-foundations.md`, `2026-03-07_1100_unified-chrome-strip-architecture.md`

## User Intention
User was not asking for one isolated bug fix. They wanted Cove to stop feeling like a promising prototype with a few "off" behaviors and start feeling like a real browser: native-looking chrome without stray system artifacts, standard adjacent-tab behavior, stable top-tab sizing, download affordances that stay visually centered, favicons that appear quickly instead of lagging or missing, and browser-style back/forward semantics even when the first page is Cove's own SwiftUI start page.

## What We Accomplished
- ✅ **Removed the dark native toolbar band** — hid the system toolbar background at the SwiftUI window level so AppKit no longer painted a blue-ish native strip over Cove's custom top chrome
- ✅ **Fixed new-link tab insertion order** — new tabs opened from a tab now insert immediately after the opener instead of always appending at the end
- ✅ **Centered the downloads icon during active downloads** — kept the icon centered in the toolbar button while leaving the progress bar pinned at the bottom as an independent overlay
- ✅ **Stopped the downloads icon from changing symbol style mid-download** — removed the filled-symbol swap so the glyph stays visually consistent instead of turning into a white/filled variant
- ✅ **Normalized top tab widths** — horizontal tabs now share one computed width, shrink together as tab count grows, clamp to a min/max range, and only scroll after hitting the minimum
- ✅ **Removed tab-width jitter from active-state typography** — horizontal tabs no longer subtly resize when active state changes because width is no longer title-driven and active/inactive font metrics are now width-neutral
- ✅ **Improved favicon reliability and speed** — kept the fast-start `/favicon.ico` path, shortened its timeout, and added a page-declared icon fallback so modern sites no longer depend on the legacy root-icon convention
- ✅ **Restored start-page back/forward behavior** — the New Tab page now behaves like a browser-owned history entry, so navigating from it enables Back, returning to it works, and Forward returns to the web page again
- ✅ **Validated the fixes in the running app** — rebuilt repeatedly and smoke-tested chrome, favicon, and start-page navigation behavior in live debug windows

## Technical Implementation

### Native Top Band Removal
- `Cove/Sources/App/CoveApp.swift`
- Added `.toolbarBackgroundVisibility(.hidden, for: .windowToolbar)` to the window content
- This preserved the native titlebar/toolbar host while stopping SwiftUI/AppKit from painting the extra toolbar material above the custom shell

### Adjacent New-Tab Placement
- `Cove/Sources/Browser/TabManager.swift`
- `Cove/Sources/Browser/TabSession.swift`
- `TabManager.open(...)` now inserts after an opener/current tab when available instead of always calling `tabs.append(...)`
- `TabSession` now receives its `id` up front so popup/new-window callbacks can capture the opener tab identity and insert the new tab directly after it

### Download Button Layout Fix
- `Cove/Sources/UI/DownloadsStatusButton.swift`
- Replaced the icon/progress `VStack` with a fixed-size `ZStack`
- Kept the icon centered in the button and moved the progress bar to a bottom overlay position
- Removed the `downloadsActive` filled symbol path so active and inactive states share the same base icon

### Shared Horizontal Tab Width Model
- `Cove/Sources/UI/TabStripView.swift`
- `Cove/Sources/UI/Foundation/ChromeTabItem.swift`
- `TabStripView` now computes a shared width from available strip width, tab count, spacing, and the reserved new-tab button footprint
- The width is clamped to `112...200`
- `ChromeTabItem` accepts `horizontalWidth` and uses it for the outer tab frame so only the title truncates inside the fixed box
- Horizontal tabs now use width-neutral typography for active/inactive state

### Favicon Resolver Upgrade
- `Cove/Sources/Browser/TabSession.swift`
- Kept the fast navigation-time favicon start so icons can still appear before the page fully settles
- Reduced the initial `/favicon.ico` timeout to fail fast when the root icon is not useful
- Added a second pass after `didFinish` that queries page-declared `<link rel="icon">` URLs via `evaluateJavaScript(...)`
- Filtered out `apple-touch-icon` and `mask-icon` so the browser continues preferring browser-oriented icons instead of iOS home-screen assets
- Fetched candidate icons in parallel and applied the first valid result while preserving the existing request-ID / site-key race protection

### Synthetic Start-Page History
- `Cove/Sources/Browser/TabSession.swift`
- Added a browser-owned navigation layer on top of WebKit history for the New Tab page
- `canGoBack` / `canGoForward` are now derived from both WebKit state and the synthetic start-page entry
- Back from the first navigated page now reveals the SwiftUI start page even when `WKWebView` has no prior history entry
- Forward from the revealed start page returns to the hidden web page
- If the user goes back to the start page and then navigates somewhere else, `TabSession` replaces the hidden `WKWebView` with a fresh one so stale web history does not leak into the new branch

**Files Modified:**
- `Cove/Sources/App/CoveApp.swift` — hid the system toolbar background
- `Cove/Sources/Browser/TabManager.swift` — opener-aware adjacent tab insertion
- `Cove/Sources/Browser/TabSession.swift` — popup adjacency plumbing, favicon fallback resolver, and synthetic start-page history
- `Cove/Sources/UI/DownloadsStatusButton.swift` — centered icon + bottom overlay progress
- `Cove/Sources/UI/TabStripView.swift` — shared horizontal tab-width calculation
- `Cove/Sources/UI/Foundation/ChromeTabItem.swift` — fixed-width horizontal tabs with width-neutral active state

## Bugs & Issues Encountered
1. **A blue-ish native strip appeared above the tab bar**
   - **Root cause:** the native window toolbar background was still being painted on top of Cove's custom titlebar shell
   - **Fix:** hid the window toolbar background with SwiftUI's `toolbarBackgroundVisibility(.hidden, for: .windowToolbar)`

2. **New links opened in the last tab position instead of beside their opener**
   - **Root cause:** `TabManager` always appended new tabs, regardless of where the request originated
   - **Fix:** added opener-aware insertion so popup/new-link requests land immediately after the source tab

3. **The downloads icon was pushed upward and changed appearance during downloads**
   - **Root cause:** the icon and progress indicator shared a vertical layout stack, and the active state swapped to a filled symbol
   - **Fix:** moved the progress bar into a bottom overlay and kept one stable icon symbol for all states

4. **Top tab widths felt unstable and visually inconsistent**
   - **Root cause:** horizontal tabs were content-sized, capped only by title width, and active-state font weight changes altered intrinsic width
   - **Fix:** switched to one shared computed width for all horizontal tabs and made active/inactive tab typography width-neutral

5. **Favicons missed on many modern sites or felt too slow**
   - **Root cause:** Cove only tried canonical `/favicon.ico`, which is deterministic but incomplete for sites that publish their real icon only through HTML metadata
   - **Fix:** kept the fast root-icon attempt but added a page-declared icon fallback after load completion

6. **The Back button stayed disabled after navigating from the New Tab page**
   - **Root cause:** the start page is a SwiftUI view, not a `WKWebView` navigation entry, so WebKit legitimately reported no back history
   - **Fix:** implemented a synthetic start-page history entry inside `TabSession` so browser navigation semantics include the SwiftUI start page

7. **Swift 6 actor isolation rejected the initial JS favicon bridge**
   - **Root cause:** raw `Any` values returned from `evaluateJavaScript` were being sent through a continuation in a way Swift 6 flagged as data-racy
   - **Fix:** normalized the result to plain `[String]` on the main actor before returning from the continuation

## Key Learnings
- **A custom browser start page needs its own history model if it should behave like a real page.** If the start page lives outside WebKit, `canGoBack` cannot come only from `WKWebView`.
- **Top tabs should be count-driven, not title-driven.** Browser tab widths feel stable when the strip owns width distribution and titles merely truncate inside the box.
- **Secondary indicators should not participate in primary icon layout.** A bottom progress bar belongs in an overlay, not in the same stack that determines icon centering.
- **Pure `/favicon.ico` logic is simple but incomplete.** It is a good first-stage fast path, but modern sites often require a page-declared icon fallback if you want browser-grade hit rates.
- **SwiftUI can suppress native toolbar paint without giving up the native host.** Hiding the toolbar background was enough to remove the blue-ish strip while keeping the rest of the AppKit titlebar integration intact.

## Architecture Decisions
- **Keep the native titlebar/toolbar host, but hide its background paint** — preserves the macOS window behavior already established in earlier sessions without the unwanted top strip
- **Insert new tabs relative to the opener/current tab** — matches mainstream browser expectations and keeps related navigation spatially local
- **Use a shared-width model for horizontal tabs** — `112...200` is now the initial clamp range for top tabs
- **Keep one stable downloads icon** — progress should communicate state; the base symbol should not morph while downloading
- **Use staged favicon resolution** — fast root-icon attempt first, page-declared icon fallback second, with request identity preserved throughout
- **Model the New Tab page as browser-owned synthetic history** — browser navigation semantics should cover both SwiftUI-owned and WebKit-owned content surfaces

## Ready for Next Session
- ✅ `xcodebuild -scheme "Cove" -project "Cove.xcodeproj" -configuration Debug build` succeeds after the final fixes
- ✅ Top chrome no longer shows the extra native toolbar band
- ✅ New-link tabs open adjacent to their opener
- ✅ Download icon remains centered while progress is visible
- ✅ Horizontal top tabs use a shared width model instead of title-driven sizing
- ✅ Favicons resolve on live smoke-tested sites like `spoke.so`
- ✅ New Tab -> navigate -> Back -> Forward works in the running app
- ✅ Worktree was clean before creating this log file
- 🔧 Most likely next polish pass: tune the horizontal tab clamp bounds (`112/200`) by eye after more real-world browsing
- 🔧 Most likely next favicon pass: handle any remaining manifest-only edge cases if specific sites still miss
- 🔧 Highest-value regression coverage: lightweight tests or smoke scripts around synthetic start-page history, adjacent tab insertion, and favicon fallback resolution

## Context for Future
This session was a concentrated browser-behavior polish pass rather than a single bug fix. The pattern across all issues was the same: places where Cove looked close to a browser but still behaved like an app prototype. After this session, several of those seams were removed: the titlebar no longer leaks system chrome, opener-created tabs land where users expect, download status stays visually composed, top tabs behave like a real strip instead of a row of content-sized pills, favicon resolution is staged like a real browser, and the New Tab page now participates in navigation like a first-class browser surface.

If a future session keeps pushing Cove toward "this feels inevitable," the next best moves are likely small behavioral refinements rather than new feature work: real-world tuning of the tab-width clamp, targeted favicon edge-case cleanup based on concrete sites, and regression coverage around the synthetic history model so the start page never quietly falls out of browser navigation again.
