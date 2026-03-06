# Cove Browser — Chrome Foundations, Settings Architecture & Launch Session

**Date:** 2026-03-06
**Agent:** GPT-5.4
**Status:** ✅ Completed

## User Intention
User wanted to stop making isolated UI tweaks and instead establish Cove's actual taste: a real design system, stronger hover/pressed/focus states, better button and window framing, a sidebar that blends with the browser UX, and a navigation area that feels intentional rather than stacked together. The user also wanted research into native Apple APIs so Cove could stay custom where it matters while still using the right macOS foundations for settings, materials, and icon animation. The broader intent was to move Cove from "working browser prototype" toward "coherent native browser product," then build and launch the result and keep session continuity with a proper agent log.

## What We Accomplished
- ✅ **Researched and locked a hybrid-native direction** — chose custom browser chrome with selective native macOS behavior/materials instead of either full custom-everything or full toolbar-driven UI
- ✅ **Created a shared chrome foundation layer** — added tokens, button styles, field styles, panel/window surfaces, shared tab items, and centralized symbol names under `Cove/Sources/UI/Foundation`
- ✅ **Refactored the top browser chrome into one system** — reworked `BrowserView`, `NavigationBar`, `TabStripView`, and `SidebarTabView` so they now read as a single chrome shell with consistent interaction states
- ✅ **Prototyped the sidebar as an overlay material surface** — moved sidebar behavior toward a hover-revealed overlay backed by `NSVisualEffectView.Material.sidebar` instead of a simple layout slab
- ✅ **Added a native settings architecture** — introduced a SwiftUI `Settings` scene plus a typed `BrowserSettingsStore` so Cove can use platform preferences patterns instead of inventing its own
- ✅ **Implemented first-pass settings IA** — added `General`, `Privacy`, and `Downloads` settings surfaces with real persisted preferences
- ✅ **Wired settings into browser behavior** — search engine, new-tab behavior, home page, default tab layout, sidebar auto-hide, content blocking, history/recents behavior, and download destination mode now flow through browser services
- ✅ **Standardized icon strategy around SF Symbols** — centralized chrome symbol names and added restrained `symbolEffect` motion only where it communicates state
- ✅ **Updated product documentation to match the new direction** — revised `PRODUCT.md` so the design stance reflects "custom chrome with selective native materials"
- ✅ **Built and launched the app successfully** — regenerated the Xcode project, built the current tree, and launched the fresh debug build
- ✅ **Committed and pushed the major foundation pass** — shipped the main browser-foundations work, then followed up with a `.gitignore` cleanup so repo-local derived data stays out of the worktree

## Technical Implementation

### Chrome Foundation Layer
- Added `Cove/Sources/UI/Foundation/ChromeTokens.swift` for shared spacing, radii, opacity, palette, and motion values
- Added `Cove/Sources/UI/Foundation/ChromeButtonStyle.swift` to standardize toolbar, tab accessory, panel action, and row interaction behavior
- Added `Cove/Sources/UI/Foundation/ChromeFieldStyle.swift` so address/search fields share one focus and container treatment
- Added `Cove/Sources/UI/Foundation/ChromePanelSurface.swift` for window, top chrome, panel, sidebar, and card surfaces, including an AppKit visual-effect wrapper for native material-backed surfaces
- Added `Cove/Sources/UI/Foundation/ChromeTabItem.swift` so horizontal tabs and sidebar tabs are now one control family instead of duplicated implementations
- Added `Cove/Sources/UI/Foundation/ChromeSymbols.swift` to centralize the browser’s SF Symbols vocabulary

### Hybrid Chrome Shell
- Refactored `Cove/Sources/UI/BrowserView.swift` so the tab strip, navigation area, progress indicator, window inset, and content area are composed as one chrome shell
- Refactored `Cove/Sources/UI/NavigationBar.swift` to use shared button/field styling, show site identity in the address field, and expose sidebar/history/download affordances consistently
- Refactored `Cove/Sources/UI/TabStripView.swift` and `Cove/Sources/UI/SidebarTabView.swift` onto the shared tab primitive
- Changed sidebar behavior from side-by-side layout chrome toward a revealable overlay panel with native material treatment and auto-hide behavior controlled by settings
- Reworked `Cove/Sources/UI/HistoryView.swift`, `Cove/Sources/UI/DownloadPopover.swift`, and `Cove/Sources/UI/NewTabPage.swift` so secondary surfaces share the same interaction and panel language as the main chrome

### Settings Architecture
- Added a native SwiftUI `Settings` scene in `Cove/Sources/App/CoveApp.swift`
- Added `Cove/Sources/Settings/BrowserSettingKeys.swift` for typed preference keys and browser preference enums
- Added `Cove/Sources/Settings/BrowserSettingsStore.swift` as the typed bridge between `UserDefaults` and the browser services
- Added `Cove/Sources/Settings/SettingsView.swift` with first-pass panes for:
  - `General` — search engine, new tab behavior, home page URL, default tab layout, auto-hide sidebar
  - `Privacy` — content blocking, save history, show recent sites, clear history
  - `Downloads` — downloads folder vs ask every time

### Browser Service Wiring
- `Cove/Sources/Browser/WebViewModel.swift` now uses the settings store for search engine behavior and supports direct non-search URLs like `about:blank`
- `Cove/Sources/Browser/Tab.swift` and `Cove/Sources/Browser/TabManager.swift` now respect the chosen new-tab destination and persisted tab layout behavior
- `Cove/Sources/Browser/HistoryStore.swift` now respects the `saveBrowsingHistory` setting for record/search behavior
- `Cove/Sources/Browser/ContentBlockerManager.swift` was reworked so the blocker can respond to settings changes across both existing and future web views
- `Cove/Sources/Browser/DownloadManager.swift` now supports either the Downloads folder or `NSSavePanel`-based "ask every time" destination selection

**Files Modified/Created:**
- `Cove/Sources/UI/Foundation/ChromeTokens.swift`
- `Cove/Sources/UI/Foundation/ChromeButtonStyle.swift`
- `Cove/Sources/UI/Foundation/ChromeFieldStyle.swift`
- `Cove/Sources/UI/Foundation/ChromePanelSurface.swift`
- `Cove/Sources/UI/Foundation/ChromeTabItem.swift`
- `Cove/Sources/UI/Foundation/ChromeSymbols.swift`
- `Cove/Sources/Settings/BrowserSettingKeys.swift`
- `Cove/Sources/Settings/BrowserSettingsStore.swift`
- `Cove/Sources/Settings/SettingsView.swift`
- `Cove/Sources/UI/BrowserView.swift`
- `Cove/Sources/UI/NavigationBar.swift`
- `Cove/Sources/UI/TabStripView.swift`
- `Cove/Sources/UI/SidebarTabView.swift`
- `Cove/Sources/UI/HistoryView.swift`
- `Cove/Sources/UI/DownloadPopover.swift`
- `Cove/Sources/UI/NewTabPage.swift`
- `Cove/Sources/Browser/WebViewModel.swift`
- `Cove/Sources/Browser/Tab.swift`
- `Cove/Sources/Browser/TabManager.swift`
- `Cove/Sources/Browser/HistoryStore.swift`
- `Cove/Sources/Browser/ContentBlockerManager.swift`
- `Cove/Sources/Browser/DownloadManager.swift`
- `Cove/Sources/App/CoveApp.swift`
- `Cove/Sources/App/AppDelegate.swift`
- `PRODUCT.md`
- `.gitignore`

## Bugs & Issues Encountered
1. **There was no shared chrome language in the codebase**
   - **Root cause:** button, field, hover, panel, and tab styling all lived as one-off view-local logic, so the UI could not converge toward a recognizable browser taste
   - **Fix:** extracted a reusable foundation layer and rewired primary and secondary surfaces onto it

2. **Settings needed to affect long-lived browser services, not just views**
   - **Root cause:** raw `@AppStorage` is good for SwiftUI controls, but core services like `WebViewModel`, `TabManager`, `ContentBlockerManager`, and `DownloadManager` need a typed shared source of truth
   - **Fix:** added `BrowserSettingsStore` as a typed bridge over `UserDefaults` and used it inside browser-layer services

3. **Content blocking toggle behavior no longer fit the original pending-only architecture**
   - **Root cause:** the older design assumed one startup load path; once settings could enable/disable blocking dynamically, existing `WKUserContentController` instances also had to be tracked
   - **Fix:** replaced the pending-only approach with tracked weak controller sets plus attach/detach behavior for both current and future web views

4. **Download destination refactor introduced a stale variable bug**
   - **Root cause:** while extracting destination handling into reusable helpers, the deduplication function still referenced the old local directory variable name
   - **Fix:** corrected the destination helper to use the passed-in directory consistently

5. **Repo-local derived data polluted git status after build/launch verification**
   - **Root cause:** the fresh build used a workspace-local `.derivedData/` path that was not yet ignored by the repo
   - **Fix:** added `.derivedData/` to `.gitignore` and committed the cleanup separately

## Key Learnings
- **Taste problems are architecture problems first** — when every surface owns its own hover/focus/spacing rules, the UI never converges no matter how many small styling edits you make
- **Hybrid-native is the right fit for Cove** — the browser chrome benefits from custom layout and visual restraint, while sidebars, settings, and window behavior benefit from macOS-native affordances
- **SwiftUI `Settings` + `@AppStorage` + typed store is the right split** — the view layer stays native and simple while the browser layer still gets typed, observable settings access
- **Overlay sidebars feel more browser-like than width-collapsing layout sidebars** — especially when the surface can float over content rather than permanently consuming space
- **SF Symbols motion works best when it explains state** — downloads, reload/stop, and layout changes gain clarity; persistent browser controls should still visually recede
- **Building and launching the exact fresh binary matters** — the design pass ended with a real build/launch cycle, which is important for validating browser-feel work rather than just compiling it

## Architecture Decisions
- **Keep the main top chrome custom** — Cove still owns its browser-specific identity and spacing, rather than becoming a stock toolbar app
- **Use native material selectively, not globally** — sidebar/panel/settings surfaces can use AppKit materials, but the whole browser should not become full-window glass
- **Make settings first-class infrastructure, not a later patch** — key browsing behavior now flows through persisted settings instead of staying hard-coded
- **Stay SF Symbols-first for browser chrome** — site favicons and file icons remain special cases, but the main icon language is still platform-native
- **Limit motion to event-driven changes** — no decorative icon loops or over-animated browser chrome

## Ready for Next Session
- ✅ **Chrome foundation layer exists** — future UI work can build on shared tokens and primitives instead of per-view styling
- ✅ **Settings architecture exists** — new preferences can now plug into the existing store and native settings window
- ✅ **Hybrid sidebar direction is established** — overlay material sidebar is now a real part of the browser shell
- ✅ **Build/launch path was validated** — the current tree builds and opens successfully
- 🔧 **Open item:** keyboard shortcuts are still missing and are now the clearest high-impact follow-up
- 🔧 **Open item:** bookmarks still do not exist, but the settings and persistence architecture now make them easier to add cleanly
- 🔧 **Open item:** the new chrome system likely needs iterative visual tuning in the running app now that the structural layer is in place

## Context for Future
This session was the inflection point from "browser with features" to "browser with a product language." The biggest win was not a single visual tweak; it was the introduction of shared UI primitives, a hybrid-native chrome model, and a real settings architecture that turns future taste work into deliberate iteration instead of local hacks. If a future session continues from here, the most natural next steps are to tune the live chrome feel in the running app, add keyboard shortcuts on top of the new foundation, and then move into bookmarks or other browser-parity features without having to rebuild the browser shell again.
