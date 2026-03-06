# Content Blocking & Download UI Polish

**Date:** 2026-03-06
**Agent:** Claude Opus 4.6
**Status:** ✅ Completed

## User Intention
User wanted to continue building on Cove's feature set — polish the download progress indicator (replace circle with horizontal bar), then implement content blocking so ads are blocked by default. User wants content blocking always-on for now, with a settings toggle deferred to a future Settings feature.

## What We Accomplished
- ✅ **Download progress bar redesign** — replaced circle progress ring around download icon with a horizontal bar underneath it (capsule shape, fills left-to-right)
- ✅ **Download progress reactivity fix** — forwarded DownloadItem.objectWillChange to DownloadManager via Combine so nav bar progress bar updates in real-time
- ✅ **Content blocking with EasyList** — 27,576 WebKit content blocker rules compiled and cached, attached to every WKWebView, ads blocked by default
- ✅ **Pending controller pattern** — handles race condition where WebView is created before rules finish compiling

## Technical Implementation

### Download Progress Bar
- Replaced `Circle().trim()` with `Capsule()` inside a `GeometryReader` for proportional fill
- Added `Spacer().frame(height: 4)` when no active downloads to prevent layout shift
- Fixed reactivity: `DownloadItem.objectWillChange` wasn't propagating to `DownloadManager`, so nav bar never re-rendered. Added Combine sink per item, cleaned up in `remove()` and `clearCompleted()`

### Content Blocking Architecture
- `ContentBlockerManager` singleton, `@MainActor`
- Bundled `easylist_min_content_blocker.json` (6.8MB, 27,576 rules pre-converted for WebKit)
- `WKContentRuleListStore.default()` compiles JSON into bytecode on first run, caches to disk
- `lookUpContentRuleList(forIdentifier:)` on subsequent launches — instant, no recompilation
- Pending controller queue: if `attach(to:)` is called before rules are ready, the controller is queued; `flushPending()` runs after compilation/cache load
- `WebViewModel.init` calls `ContentBlockerManager.shared.attach(to: config.userContentController)` so every tab gets rules
- `AppDelegate.applicationDidFinishLaunching` triggers `Task { await ContentBlockerManager.shared.load() }`

**Files Modified/Created:**
- `Cove/Sources/UI/NavigationBar.swift` — download button: circle → horizontal bar
- `Cove/Sources/Browser/DownloadManager.swift` — Combine import, itemCancellables for objectWillChange forwarding
- `Cove/Sources/Browser/ContentBlockerManager.swift` — new, compile/cache/attach content rules
- `Cove/Sources/Browser/WebViewModel.swift` — attach content blocker to WKWebViewConfiguration
- `Cove/Sources/App/AppDelegate.swift` — trigger content blocker load at launch
- `Cove/Resources/easylist.json` — new, bundled EasyList filter rules
- `project.yml` — added easylist.json as source with buildPhase: resources

## Bugs & Issues Encountered
1. **Download progress bar not updating in nav bar**
   - **Root cause:** `overallProgress` is a computed property on DownloadManager derived from DownloadItem's @Published properties, but SwiftUI only observes DownloadManager's own @Published changes
   - **Fix:** Forward each DownloadItem's `objectWillChange` to DownloadManager via Combine sink

2. **easylist.json not found in app bundle**
   - **Root cause:** xcodegen's `resources:` section wasn't creating a `PBXResourcesBuildPhase` at all. The JSON file existed in the project directory but wasn't copied to the app bundle.
   - **Fix:** Moved easylist.json into the `sources:` section with `buildPhase: resources` — this forced xcodegen to create the resources build phase

3. **Content blocking rules not applied to first tab**
   - **Root cause:** `load()` is async — the first WebView is created before rules finish compiling, so `attach(to:)` finds `ruleList` nil and does nothing
   - **Fix:** Pending controller queue — controllers registered before compilation are stored and flushed once rules are ready

4. **Keychain modal on launch ("Cove WebCrypto Master Key")**
   - **Root cause:** WKWebView's WebCrypto API needs keychain access; ad-hoc signing ("Sign to Run Locally") doesn't have implicit keychain entitlements like Xcode's debugger does
   - **Fix:** One-time "Always Allow" click. Won't occur in production builds with proper code signing.

## Key Learnings
- **xcodegen `resources:` section doesn't always create a build phase** — if it only contains files that are already referenced elsewhere (Info.plist, entitlements), it may skip the phase entirely. Putting resource files in `sources:` with `buildPhase: resources` is more reliable.
- **SwiftUI computed properties don't trigger re-renders** — if a computed property on an ObservableObject depends on another ObservableObject's @Published properties, SwiftUI won't know to re-render. You must forward `objectWillChange` via Combine.
- **WKContentRuleListStore compiles to bytecode** — first compilation of 27k rules takes a few seconds, but the result is cached to disk permanently. Subsequent launches use `lookUpContentRuleList` which is instant.
- **150k rule limit per WKContentRuleList** (raised from 50k in 2022) — can attach multiple lists to one WKUserContentController for more coverage
- **`/usr/bin/log stream` for system logs** — use full path because `log` conflicts with zsh. Filter with `--predicate 'subsystem == "..."'` and `--level debug` to see all levels.

## Architecture Decisions
- **Singleton ContentBlockerManager** — content blocking is global state, same rules for all tabs. Matches DownloadManager and FaviconStore patterns.
- **Pending controller queue over awaiting** — can't make WebViewModel.init async, so instead of blocking on rule compilation, we queue controllers and flush retroactively. Rules still apply before any navigation happens.
- **No settings toggle yet** — user explicitly deferred to Settings feature. `attach(to:)` and `detach(from:)` methods are ready for wiring.
- **Bundled EasyList only** — no remote updates or EasyPrivacy yet. 27k rules cover most ads. Can add more lists later within the 150k limit.

## Ready for Next Session
- ✅ **Content blocking active** — EasyList rules compiled, cached, and applied to all tabs
- ✅ **Toggle API ready** — `ContentBlockerManager.attach/detach` ready for Settings UI
- 🔧 **Keyboard shortcuts** — Cmd+T/W/L/[/] not yet implemented, highest-impact next feature
- 🔧 **Bookmarks** — SQLite-backed, same architecture as history/favicons
- 🔧 **Settings pane** — search engine, content blocking toggle, downloads location

## Context for Future
Content blocking completes the core browsing experience — Cove now has tabs, navigation, history, favicons, downloads, and ad blocking. The next highest-impact feature is keyboard shortcuts (essential browser UX), followed by bookmarks and settings. The ContentBlockerManager is designed for easy extension: add more filter lists, per-site allowlisting, or a settings toggle by calling the existing attach/detach methods.
