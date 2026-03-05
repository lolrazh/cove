# Vayu Browser — Review & Favicon Fixes Session

**Date:** 2026-03-06
**Agent:** Codex GPT-5
**Status:** ✅ Completed

## User Intention
User wanted a real codebase review of Vayu, focused on concrete bugs and regressions rather than a vague overview, then wanted the important issues fixed. The follow-up priority became favicon behavior: understand why favicon loading felt slower than other browsers, make the implementation fast and deterministic, remove fallback chains, fix the async race where stale favicon work could overwrite the current page, and confirm which review findings were already resolved versus still open.

## What We Accomplished
- ✅ **Reviewed the current app as a runtime/code-review pass** — inspected the SwiftUI + WKWebView architecture, verified the project builds, and identified concrete state-flow, history, and favicon defects
- ✅ **Validated the project with local builds** — ran `xcodebuild` builds and analyzer passes to ground findings in the actual tree
- ✅ **Confirmed and documented the main review findings** — nested observation gaps, per-tab state leakage, history write race, FTS5 query issues, and favicon lifecycle issues
- ✅ **Verified favicon latency was mostly pipeline timing, not raw network cost** — timed the current favicon request path and confirmed the bigger issue was waiting too late to start work
- ✅ **Reworked favicon fetching to start on navigation instead of page finish** — favicon work is now triggered from URL changes and main-frame navigation, not from a post-load upgrade phase
- ✅ **Removed the fallback chain for favicon loading** — the final implementation fetches a single canonical `/favicon.ico` URL and either shows it or shows no icon
- ✅ **Added request-scoped favicon task management** — each favicon request now has explicit cancellation and request identity so stale completions cannot win
- ✅ **Ensured favicon state is cleared on site change** — navigating to a different site now clears the old icon immediately instead of leaking the previous site’s image
- ✅ **Confirmed other major review fixes were already present in the tree** — Tab forwarding, active-tab `.id`, direct history capture from `WKWebView`, and sanitized history search were all applied
- ✅ **Rebuilt after every meaningful browser-layer change** — final `xcodebuild -project Vayu.xcodeproj -scheme Vayu -configuration Debug -sdk macosx build` succeeded

## Technical Implementation

### Review Validation
- Verified the app builds successfully with `xcodebuild`
- Checked build/analyzer output to distinguish actual breakage from compile-clean runtime bugs
- Compared the current tree against the earlier findings to confirm which had already been fixed

### Favicon Pipeline Changes
- **Old behavior:** favicon work depended on `loadURL(...)` and/or post-load upgrade logic, which made icons feel late during normal in-page navigation
- **New behavior:** favicon work begins as soon as the main-frame URL changes
- **Source of truth:** one canonical favicon URL per site, derived as `scheme + host + optional port + /favicon.ico`
- **No fallbacks:** removed Google favicon API and page-declared icon upgrade chain per user request
- **Stale work protection:** each favicon request gets a `UUID` request ID; completion only applies if both the current site key and request ID still match
- **Reset semantics:** navigating to a new site cancels the current favicon task, clears old state, and either loads cached data instantly or starts one fresh request

**Files Modified/Relevant:**
- `Vayu/Sources/Browser/WebViewModel.swift` — rewrote favicon lifecycle, request cancellation, request identity, and navigation-start triggering
- `Vayu/Sources/Browser/Tab.swift` — forwards `WebViewModel.objectWillChange` so tab chrome actually re-renders
- `Vayu/Sources/UI/BrowserView.swift` — `.id(tab.id)` isolates per-tab SwiftUI state
- `Vayu/Sources/Browser/HistoryStore.swift` — sanitized FTS5 input to avoid syntax-error empty results
- `Vayu/Sources/Browser/FaviconStore.swift` — existing persistent favicon cache reused by the new pipeline

## Bugs & Issues Encountered
1. **Tab chrome was not reacting to nested `WebViewModel` updates**
   - **Root cause:** views observed `Tab`, but `Tab` did not forward `WebViewModel` changes
   - **Fix:** `Tab` now bridges `viewModel.objectWillChange` into its own `objectWillChange`

2. **SwiftUI per-tab state leaked across active tab switches**
   - **Root cause:** the active container view was reused when changing `activeTabID`
   - **Fix:** `ActiveTabView` is keyed with `.id(tab.id)` so address-bar/history/new-tab state resets per tab

3. **History writes could capture stale or empty page data**
   - **Root cause:** `didFinish` read mirrored `@Published` state that was updated asynchronously through KVO tasks
   - **Fix:** history writes now read directly from `WKWebView.url` and `WKWebView.title`

4. **History search could silently fail on common queries**
   - **Root cause:** raw user input was being converted directly into FTS5 syntax
   - **Fix:** search input is sanitized into safe alphanumeric tokens before `MATCH`

5. **Favicons felt slow and could race with later navigations**
   - **Root cause:** work started too late and detached async completions were not tied to the active page
   - **Fix:** moved favicon loading to navigation-time, removed fallback hops, added cancellation plus request-ID checks, and clear old favicon state on site change

6. **Swift 6 actor isolation errors surfaced while rewriting `WKNavigationDelegate` methods**
   - **Root cause:** delegate methods were using `nonisolated` access patterns incompatible with the new actor-isolated implementation
   - **Fix:** made delegate methods actor-safe and returned policy explicitly

## Key Learnings
- **Favicon speed is mostly about when you start the work** — waiting until `didFinish` makes favicon loading feel slow even when the network request itself is fast
- **A simple deterministic favicon path is easier to reason about** — one canonical `/favicon.ico` request plus cache behavior is much easier to validate than a multi-stage fallback chain
- **If you remove fallbacks, some sites will legitimately show no favicon** — this is a product tradeoff, not necessarily a bug
- **Nested SwiftUI observation needs explicit forwarding when the parent object is the observed boundary**
- **Swift 6 actor isolation is strict around `WKNavigationDelegate` and AppKit/WebKit APIs** — cleaner actor ownership is better than fighting `nonisolated`
- **Runtime review findings can matter more than compile cleanliness** — this project built successfully while still having meaningful state and behavior bugs

## Ready for Next Session
- ✅ **Favicon race fixed** — stale async favicon work can no longer overwrite the current site’s icon
- ✅ **Favicon timing improved** — work starts at navigation time instead of after page load
- ✅ **Review-driven fixes largely applied** — the biggest earlier findings are now addressed in the tree
- 🔧 **Still open:** `looksLikeURL(...)` still misclassifies `localhost` / IP destinations as search queries
- 🔧 **Still open:** build warnings remain in `AppDelegate.swift`, `Database.swift`, and `TabManager.swift`
- 🔧 **Still open:** there is still no test target covering history, tab state, or favicon behavior

## Context for Future
This session was not greenfield product work; it was a hardening pass after the MVP build. The user wanted continuity across sessions, so the key takeaway is that Vayu now has a much cleaner runtime story than the initial MVP: tab chrome updates propagate, active-tab UI state is isolated, history persistence is less racy, FTS history search is safer, and favicon loading is deterministic and fast-starting. The remaining browser-layer issue called out explicitly is local-dev URL detection (`localhost`, `127.0.0.1`, etc.). If the next session continues in this area, the highest-value follow-up is to fix URL classification and then add lightweight regression coverage around tab state, history search, and favicon lifecycle.
