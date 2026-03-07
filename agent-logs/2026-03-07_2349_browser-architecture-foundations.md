# Browser Architecture Foundations Refactor

**Date:** 2026-03-07
**Agent:** GPT-5.4
**Status:** ✅ Completed
**Building on:** `2026-03-07_1800_state-management-refactor.md`

## User Intention
User wanted more than a code review. They wanted the browser code to feel structurally elegant in a "Carmack style" sense: simpler ownership, fewer fake layers, cleaner system boundaries, and something that could scale without turning into spaghetti. The immediate symptom was broken popup/new-tab behavior, but the real goal was a methodical architecture cleanup with meaningful staged commits.

## What We Accomplished
- ✅ **Created a dedicated refactor branch** — `refactor/browser-architecture-foundations`
- ✅ **Restored popup/new-tab behavior** — `window.open()` / `target="_blank"` now route through `WKUIDelegate` into `TabManager.addTab(request:)`
- ✅ **Centralized WebKit setup** — introduced `WebKitEnvironment` so `WKWebView` construction and browser policy no longer live inline in each tab object
- ✅ **Made settings single-owned** — `BrowserSettingsStore` is now the only writer for browser settings; Settings UI and commands both route through it
- ✅ **Made open windows react live to settings** — `TabManager` subscribes to store changes instead of snapshotting layout/hide state once at init
- ✅ **Unified browser window chrome ownership** — titlebar tabs, traffic-light visibility, titlebar measurement, and window styling now live behind one per-window bridge instead of being split across `AppDelegate` and multiple bridges
- ✅ **Removed redundant chrome plumbing** — deleted `TitlebarTabStripAccessory.swift` and moved that responsibility into `WindowChromeAccessor`
- ✅ **Hardened startup services** — `FaviconStore` no longer crashes the app if the cache DB fails to open, and favicon loading is now lazy instead of prewarming the entire cache at launch
- ✅ **Collapsed fake tab layering** — replaced `Tab` + `WebViewModel` with a single `TabSession` that owns tab identity, start-page state, navigation state, and its `WKWebView`
- ✅ **Separated navigation policy from tab runtime** — extracted `NavigationRequestBuilder` so URL-vs-search resolution is a pure policy object instead of being buried inside tab runtime
- ✅ **Simplified browser view hosting** — `BrowserView` now hosts only the active session's view instead of keeping hidden `WKWebView`s stacked in a `ZStack`
- ✅ **Kept history readable** — landed the work as staged commits instead of one giant "architecture cleanup" blob

## Technical Implementation

### Commit Sequence
- `859a243` — `fix: centralize WebKit setup and restore popup tabs`
- `f99355e` — `refactor: route browser settings through a single store`
- `ae17ae3` — `refactor: give each browser window one chrome bridge`
- `39a98a7` — `fix: harden browser startup services`
- `de73d64` — `refactor: collapse browser tabs into tab sessions`
- `9636a56` — `refactor: separate navigation policy from tab runtime`
- `7293ac0` — `refactor: host only the active tab view`

### Ownership After Refactor
```
App scope
├── BrowserSettingsStore
├── WebKitEnvironment
├── FaviconStore
├── HistoryStore
└── DownloadManager

Window scope
├── TabManager
└── WindowChromeAccessor / WindowChromeHost bridge

Tab scope
└── TabSession

Pure policy
└── NavigationRequestBuilder
```

### Major Files Modified
- `Cove/Sources/Browser/WebKitEnvironment.swift` — centralized `WKWebView` creation and browser user-agent policy
- `Cove/Sources/Browser/TabManager.swift` — live settings subscription, popup tab routing, `TabSession` ownership
- `Cove/Sources/Browser/TabSession.swift` — new tab-scoped runtime object replacing the old wrapper/model split
- `Cove/Sources/Browser/NavigationRequestBuilder.swift` — extracted URL/search resolution policy
- `Cove/Sources/Browser/FaviconStore.swift` — lazy cache reads, no startup crash path
- `Cove/Sources/Settings/BrowserSettingsStore.swift` — single settings writer
- `Cove/Sources/Settings/SettingsView.swift` — store-backed bindings instead of direct `@AppStorage` mutation
- `Cove/Sources/UI/Foundation/WindowChromeAccessor.swift` — single window chrome bridge
- `Cove/Sources/UI/WindowChromeHost.swift` — window bridge host updated to own tab-aware chrome integration
- `Cove/Sources/UI/BrowserView.swift` — active-tab-only hosting
- `Cove/Sources/UI/BrowserShellView.swift` — consumes `TabSession` directly
- `Cove/Sources/UI/NavigationBar.swift` — consumes `TabSession` directly
- `Cove/Sources/UI/Foundation/ChromeTabItem.swift` — consumes `TabSession` directly
- `Cove/Sources/App/AppDelegate.swift` — reduced back to app-global work only

### Files Deleted
- `Cove/Sources/Browser/Tab.swift`
- `Cove/Sources/Browser/WebViewModel.swift`
- `Cove/Sources/UI/TitlebarTabStripAccessory.swift`

## Bugs & Issues Encountered

1. **Popup/new-tab flows silently failed**
   - **Root cause:** `WKWebView` only had a navigation delegate; there was no `WKUIDelegate` bridge for new-window requests.
   - **Fix:** Added popup routing through `createWebViewWith` and opened those requests via `TabManager.addTab(request:)`.

2. **Settings changes did not propagate to already-open windows**
   - **Root cause:** `TabManager` read layout/hide settings once at init, while `SettingsView` mutated defaults independently.
   - **Fix:** Made `BrowserSettingsStore` the single writer and had `TabManager` subscribe to the store's published values.

3. **Browser chrome ownership was split across too many places**
   - **Root cause:** `AppDelegate`, `WindowChromeAccessor`, `WindowChromeHost`, and `TitlebarTabStripAccessory` all participated in the same window-level behavior.
   - **Fix:** Moved browser-window styling and titlebar accessory hosting into one per-window bridge and removed the separate titlebar accessory layer.

4. **Favicon cache failure could crash the whole app**
   - **Root cause:** `FaviconStore` called `fatalError` if `favicons.db` could not be opened.
   - **Fix:** Downgraded the DB to optional, log-and-degrade behavior, and lazy-loaded cache entries on demand.

5. **The `Tab` / `WebViewModel` split was fake complexity**
   - **Root cause:** `Tab` mainly existed to forward `objectWillChange` from `WebViewModel`, which meant the real runtime boundary was split across two objects for no real gain.
   - **Fix:** Collapsed both into `TabSession`.

6. **All tabs' `WKWebView`s stayed attached to the SwiftUI tree**
   - **Root cause:** `BrowserView` rendered every tab in a `ZStack` and hid inactive ones with opacity/hit-testing.
   - **Fix:** Host only the active session's view while keeping the session itself alive in `TabManager`.

7. **Swift compiler crashed during the settings refactor**
   - **Root cause:** Complex inferred `Binding` setter closures against the main-actor store triggered a compiler crash in `SettingsView`.
   - **Fix:** Marked settings panes `@MainActor` and expanded the setter closures explicitly. Build became stable again.

8. **New source files were invisible to the Xcode project until regeneration**
   - **Root cause:** This repo is `xcodegen`-managed, so adding/removing source files without regenerating left the project graph stale.
   - **Fix:** Ran `xcodegen generate` after file additions/deletions.

## Key Learnings
- **Scope discipline matters more than cleverness.** The right question was not "how do we sync these objects?" but "should these objects even both own this state?"
- **Wrapper objects that only forward `objectWillChange` are usually a design smell.** They preserve names while hiding the fact that ownership is wrong.
- **Window-level AppKit integration needs one owner.** If multiple bridges can mutate the same `NSWindow`, the system becomes difficult to reason about quickly.
- **Navigation policy and tab runtime should not be the same thing.** URL parsing, search fallback, and request creation are easier to test and reason about as a separate pure object.
- **The view tree should match the actual interaction model.** If only one tab is active, only one tab view should be attached unless there is a concrete reason not to.
- **With `xcodegen`, project regeneration is part of the edit cycle.** Adding/removing Swift files without regenerating produces fake build errors and stale project state.

## Architecture Decisions
- **`BrowserSettingsStore` remains app-scoped and is now the sole settings writer** — one path for settings mutation, not a mix of `@AppStorage`, defaults notifications, and model-local state.
- **`TabSession` is the tab boundary** — it owns a tab's runtime identity, start-page state, `WKWebView`, delegates, and published navigation state.
- **`NavigationRequestBuilder` is a pure policy helper** — request construction lives outside the tab runtime.
- **`WindowChromeAccessor` is the single browser-window bridge** — `AppDelegate` should stay app-global; browser windows own their own chrome integration.
- **Only the active session view is hosted** — sessions stay alive in memory, but the SwiftUI tree now reflects the active-tab model instead of layering hidden views.

## Ready for Next Session
- ✅ Branch: `refactor/browser-architecture-foundations`
- ✅ Worktree is clean
- ✅ Latest local commits are staged as readable architecture checkpoints
- ✅ `xcodebuild -project "Cove.xcodeproj" -scheme "Cove" -configuration Debug clean build CODE_SIGNING_ALLOWED=NO` succeeds
- ⚠️ Remaining build warnings are pre-existing: `Database.swift` has two `withUnsafeBytes` "result unused" warnings, plus Xcode's AppIntents metadata warning
- 🔧 Next high-value refactor: inject `HistoryStore`, `FaviconStore`, and `DownloadManager` into `TabSession` so it stops reaching for app-global singletons directly
- 🔧 Next safety improvement: add a small test target around `NavigationRequestBuilder` and popup/new-tab routing
- 🔧 Manual smoke testing still worth doing for popup sites, live settings propagation, downloads, history navigation, and tab switching after the active-view-hosting change

## Context for Future
This session materially improved the browser architecture, but it did not finish the dependency story. The biggest remaining seam is that `TabSession` still talks directly to `HistoryStore.shared`, `FaviconStore.shared`, and `DownloadManager.shared`. The code is much cleaner now, but the runtime still has app-global service reach-through.

If a future session keeps pushing toward "browser systems that scale cleanly," the next step is service injection plus a small test target, not another round of UI polish. The core ownership model is finally in decent shape: app settings/services at app scope, `TabManager` at window scope, `TabSession` at tab scope, and navigation policy extracted into its own object.
