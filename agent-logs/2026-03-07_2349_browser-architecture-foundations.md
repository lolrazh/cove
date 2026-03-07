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
- ✅ **Injected tab-scoped browser services** — `TabSession` now receives history, favicon, download, and WebKit dependencies explicitly instead of reaching into service globals
- ✅ **Removed the download settings singleton seam** — `DownloadManager` now reads destination policy from injected settings
- ✅ **Made the app root explicit** — `CoveApp` now creates one `AppServices` container and passes browser services down through the runtime and UI
- ✅ **Removed app-path service globals** — production browser code no longer reaches into `.shared` for settings/history/downloads/content blocking/WebKit wiring
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
- `97198b9` — `refactor: inject tab session services`
- `2e87857` — `refactor: inject settings into download manager`
- `4046a33` — `refactor: introduce explicit app services`

### Ownership After Refactor
```
App scope
└── AppServices
    ├── BrowserSettingsStore
    ├── HistoryStore
    ├── FaviconStore
    ├── DownloadManager
    ├── ContentBlockerManager
    └── WebKitEnvironment

Window scope
├── TabManager
└── WindowChromeAccessor / WindowChromeHost bridge

Tab scope
└── TabSession

Pure policy
└── NavigationRequestBuilder
```

### Major Files Modified
- `Cove/Sources/App/AppServices.swift` — explicit app-scoped composition root for browser services
- `Cove/Sources/Browser/WebKitEnvironment.swift` — centralized `WKWebView` creation and now depends on injected content-blocking policy
- `Cove/Sources/Browser/TabManager.swift` — live settings subscription, popup tab routing, `TabSession` ownership, and window-scoped service composition
- `Cove/Sources/Browser/TabSession.swift` — tab-scoped runtime object with explicit browser-service dependencies
- `Cove/Sources/Browser/NavigationRequestBuilder.swift` — extracted URL/search resolution policy
- `Cove/Sources/Browser/FaviconStore.swift` — lazy cache reads, no startup crash path, explicit construction
- `Cove/Sources/Browser/HistoryStore.swift` — explicit settings dependency instead of hidden reads from global settings
- `Cove/Sources/Browser/DownloadManager.swift` — explicit settings dependency instead of hidden reads from global settings
- `Cove/Sources/Browser/ContentBlockerManager.swift` — explicit settings dependency instead of hidden reads from global settings
- `Cove/Sources/Settings/BrowserSettingsStore.swift` — single settings writer with history clearing moved back out of the store
- `Cove/Sources/Settings/SettingsView.swift` — injected settings/history instead of reaching into globals
- `Cove/Sources/UI/Foundation/WindowChromeAccessor.swift` — single window chrome bridge
- `Cove/Sources/UI/WindowChromeHost.swift` — window bridge host updated to own tab-aware chrome integration
- `Cove/Sources/UI/BrowserView.swift` — active-tab-only hosting plus explicit app-service injection into each window
- `Cove/Sources/UI/BrowserShellView.swift` — consumes `TabSession` directly and receives app-scoped services for browser UI
- `Cove/Sources/UI/NavigationBar.swift` — consumes `TabSession` directly and receives explicit history/download services
- `Cove/Sources/UI/HistoryView.swift` — explicit settings/history dependencies instead of globals
- `Cove/Sources/UI/NewTabPage.swift` — explicit settings/history/favicon dependencies instead of globals
- `Cove/Sources/UI/DownloadsStatusButton.swift` — explicit download-manager dependency instead of globals
- `Cove/Sources/UI/Foundation/ChromeTabItem.swift` — consumes `TabSession` directly
- `Cove/Sources/App/AppDelegate.swift` — reduced back to AppKit window setup only

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

9. **The app still had fake dependency injection after the first refactor**
   - **Root cause:** `TabSession` had cleaner boundaries, but the production app path still reached into `.shared` settings/history/download/content-blocking services from runtime and UI code.
   - **Fix:** Introduced `AppServices` as the app-scoped composition root and threaded explicit dependencies from `CoveApp` into window, tab, and UI surfaces.

10. **`BrowserSettingsStore` was drifting into a side-effect owner**
   - **Root cause:** Clearing history lived on the settings store, which mixed persistence settings with browser data mutation.
   - **Fix:** Moved history clearing back to the composed settings UI, where the required `HistoryStore` dependency is explicit.

## Key Learnings
- **Scope discipline matters more than cleverness.** The right question was not "how do we sync these objects?" but "should these objects even both own this state?"
- **Wrapper objects that only forward `objectWillChange` are usually a design smell.** They preserve names while hiding the fact that ownership is wrong.
- **Window-level AppKit integration needs one owner.** If multiple bridges can mutate the same `NSWindow`, the system becomes difficult to reason about quickly.
- **Navigation policy and tab runtime should not be the same thing.** URL parsing, search fallback, and request creation are easier to test and reason about as a separate pure object.
- **The view tree should match the actual interaction model.** If only one tab is active, only one tab view should be attached unless there is a concrete reason not to.
- **With `xcodegen`, project regeneration is part of the edit cycle.** Adding/removing Swift files without regenerating produces fake build errors and stale project state.
- **The app is not really dependency-injected until the app root is explicit.** Cleaning up inner objects helps, but the design stays dishonest if `CoveApp` is not the place where services are composed.
- **Singletons at the boundary are less dangerous than singletons in the runtime path.** Keeping compatibility `shared` instances is tolerable; using them in the production browser path is what makes the architecture slippery.

## Architecture Decisions
- **`BrowserSettingsStore` remains app-scoped and is now the sole settings writer** — one path for settings mutation, not a mix of `@AppStorage`, defaults notifications, and model-local state.
- **`AppServices` is the one app-scoped composition root** — app-wide browser services are created once in `CoveApp` and then passed down explicitly.
- **`TabSession` is the tab boundary** — it owns a tab's runtime identity, start-page state, `WKWebView`, delegates, and published navigation state.
- **`NavigationRequestBuilder` is a pure policy helper** — request construction lives outside the tab runtime.
- **`WindowChromeAccessor` is the single browser-window bridge** — `AppDelegate` should stay app-global; browser windows own their own chrome integration.
- **Only the active session view is hosted** — sessions stay alive in memory, but the SwiftUI tree now reflects the active-tab model instead of layering hidden views.
- **UI surfaces should consume explicit services, not convenience globals** — history, downloads, settings, and start-page data now follow the same ownership story as the browser runtime.

## Ready for Next Session
- ✅ Branch: `refactor/browser-architecture-foundations`
- ✅ Worktree is clean
- ✅ Latest local commits are staged as readable architecture checkpoints
- ✅ `xcodebuild -project "Cove.xcodeproj" -scheme "Cove" -configuration Debug clean build CODE_SIGNING_ALLOWED=NO` succeeds
- ✅ `xcodegen generate` succeeds after adding `AppServices.swift`
- ✅ Production app code no longer uses app-global browser service singletons in its runtime path
- ⚠️ Remaining build warnings are pre-existing: `Database.swift` has two `withUnsafeBytes` "result unused" warnings, plus Xcode's AppIntents metadata warning
- 🔧 Next high-value refactor: add a small test target around `NavigationRequestBuilder`, history/recent-sites behavior, and popup/download routing
- 🔧 Next architecture question only if needed later: decide whether Cove wants a second browser-context layer for profiles/private windows, rather than forcing `AppServices` to represent every future context
- 🔧 Manual smoke testing still worth doing for content-blocking startup/toggle, history search, recent sites, downloads, live settings propagation, and popup/new-tab flows

## Context for Future
This session started as a browser-architecture cleanup and ended by making the app boundary explicit. `CoveApp` now creates one `AppServices` container, `TabManager` remains the window composition point, `TabSession` remains the tab boundary, and browser UI surfaces consume injected services instead of browsing globals.

If a future session keeps pushing toward "browser systems that scale cleanly," the next step is not more singleton cleanup. The next step is a small test target plus selective smoke testing, and only after that deciding whether Cove needs a second browser-context abstraction for profiles or private windows.
