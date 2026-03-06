# Cove Browser — Browser Hardening & Google Rendering Session

**Date:** 2026-03-06
**Agent:** Codex GPT-5
**Status:** ✅ Completed

## User Intention
User wanted a serious hardening pass on Cove rather than surface polish: review the codebase for real bugs, fix the important runtime issues, make favicon behavior fast and deterministic, eliminate tab-switch/tab-close flicker so the browser feels native and responsive, and investigate why Google was rendering an obviously outdated/basic homepage compared with modern browsers like Dia.

## What We Accomplished
- ✅ **Validated the earlier review findings against the real tree** — confirmed which issues were already fixed versus still active
- ✅ **Reworked favicon behavior for speed and determinism** — moved favicon work to navigation time, removed fallback chains per user direction, and made stale async completions unable to overwrite the current page
- ✅ **Confirmed the project builds after each browser-layer change** — repeated `xcodebuild` verification throughout the session
- ✅ **Stopped tab-content teardown on active-tab changes** — kept per-tab `WKWebView` instances alive in a stable content stack instead of rebuilding them on every switch
- ✅ **Reduced visual flicker during tab switching and closing** — removed broad model-layer animation from tab selection/close, scoped motion to tab-list rearrangement, and kept content swaps effectively instant
- ✅ **Stabilized top chrome during tab changes** — moved the loading progress indicator into an overlay so the navigation bar no longer changes layout height when tabs differ in loading state
- ✅ **Fixed navigation-bar state initialization** — seeded the address field from each tab’s current URL so hidden tabs do not reveal blank or stale address state when activated
- ✅ **Investigated Google’s legacy/basic homepage rendering with live `WKWebView` probes** — compared runtime UA/body output against the expected modern homepage structure
- ✅ **Added a Safari-style browser UA for Cove** — derived from the installed Safari version and applied to every `WKWebView`
- ✅ **Hardened UA application on every load/reload** — reasserted the browser UA before top-level navigations so Google compatibility does not depend only on initial view creation
- ✅ **Verified the patched `WKWebView` gets the modern Google homepage** — fresh runtime checks returned modern markers (`About`, `Store`, `AI Mode`, `How Search works`) instead of the old/basic homepage markers (`Advanced search`, classic footer layout)

## Technical Implementation

### Review & Runtime Validation
- Rechecked the codebase against the original findings instead of assuming the current tree still matched the earlier report
- Used local builds and targeted source inspection to confirm actual runtime risks
- Verified that several earlier fixes were already present in the working tree before continuing

### Favicon Lifecycle Changes
- **Old behavior:** favicon work could start late and earlier async completions could overwrite later navigations
- **New behavior:** favicon requests are tied to the active site, started at navigation time, and only applied if the site key and request ID still match
- **Product choice:** removed the multi-stage fallback chain and canonicalized favicon loading around deterministic per-site behavior

### Tab Switching & Motion Changes
- Replaced the single active-tab host with a stable layered content stack so tab switches do not recreate the active `WKWebView`
- Removed model-level animation around tab selection/add/close to avoid animating the full content hierarchy
- Scoped a short spring animation only to tab-list rearrangement in horizontal/sidebar tab UI
- Removed tab-item insertion/removal transitions that were making close operations feel more like view choreography than browser behavior
- Kept the actual page/content swap unanimated so switching feels immediate

### Chrome Stability Changes
- Moved the progress indicator into a bottom overlay on the navigation bar instead of inserting/removing a separate layout row
- Initialized each navigation bar’s local address text from the tab URL so hidden tabs do not surface empty or lagging address state

### Google Rendering Investigation
- Confirmed the “old Google” screen was not just styling drift; it was Google’s classic/basic homepage variant
- Measured the actual runtime `navigator.userAgent` coming from Cove before the fix and verified it looked like an embedded `WKWebView`, not full Safari
- Added a Safari-style desktop UA using the installed Safari bundle version and applied it to `WKWebView`
- Re-ran live `WKWebView` checks after the fix and confirmed the page body now matches the modern homepage structure
- Reapplied the UA before `loadURL(...)` and `reload()` so the browser identity is stable on future navigations

**Files Modified/Relevant:**
- `Cove/Sources/Browser/WebViewModel.swift` — favicon request identity/cancellation, Safari-style user agent, load/reload UA reapplication
- `Cove/Sources/Browser/TabManager.swift` — removed broad animation on add/close/select and stabilized active-tab replacement during close
- `Cove/Sources/UI/BrowserView.swift` — stable stacked active-tab content, animation suppression for content swaps, navigation progress overlay
- `Cove/Sources/UI/NavigationBar.swift` — seeded address field state from current URL
- `Cove/Sources/UI/TabStripView.swift` — tab-list reorder animation only, removed insertion/removal transitions
- `Cove/Sources/UI/SidebarTabView.swift` — sidebar tab-list reorder animation only, removed insertion/removal transitions
- `Cove/Sources/Browser/Tab.swift` — verified nested `WebViewModel` updates are forwarded through `Tab`
- `Cove/Sources/Browser/HistoryStore.swift` — verified sanitized FTS5 search fix is present

## Bugs & Issues Encountered
1. **Favicons could race and overwrite later navigations**
   - **Root cause:** async favicon work was not tied tightly enough to the currently active site/request
   - **Fix:** request-scoped identity plus cancellation and site-key validation before assignment

2. **Tab switches and tab closes felt flickery**
   - **Root cause:** active content was being recreated or animated too broadly, and tab-item transitions were over-animating high-frequency browser interactions
   - **Fix:** persistent tab content stack, instant content swaps, localized reorder animation for tab UI only

3. **Navigation chrome jumped during tab changes**
   - **Root cause:** the progress bar changed layout height and some hidden nav bars started with empty local state
   - **Fix:** overlay progress presentation and explicit address-field initialization from `viewModel.currentURL`

4. **Google rendered the classic/basic homepage instead of the modern homepage**
   - **Root cause:** Cove initially identified itself like an embedded `WKWebView`, which pushed Google onto its old/basic compatibility path
   - **Fix:** Safari-style desktop UA derived from installed Safari and re-applied at creation/load/reload time

5. **Google still appeared old in a user screenshot even after the UA fix landed**
   - **Root cause:** fresh runtime probes showed the patched code now gets the modern homepage, so the screenshot was almost certainly from an older running process or a tab/webview created before the fix
   - **Fix:** hardened UA application further and documented that a fresh app launch/new tab is required for already-existing old `WKWebView` instances

## Key Learnings
- **Browser-feel depends more on transaction scope than on animation quantity** — instant content swaps plus brief tab-list motion feel much faster than crossfading or rebuilding the page view hierarchy
- **`WKWebView` identity matters for browser UX** — recreating or broadly animating the active web view produces obvious flicker
- **Google’s “old homepage” is a real compatibility path, not just A/B variance** — the classic page structure is easy to distinguish from the modern homepage once you inspect body markers
- **A Safari-style UA materially changes how major sites treat the browser** — the embedded/default `WKWebView` fingerprint is enough to fall onto compatibility UI
- **Live runtime probes are more trustworthy than static assumptions** — the decisive evidence came from inspecting `navigator.userAgent` and page body content inside a real `WKWebView`
- **Address-bar local state needs deliberate initialization in persistent-tab architectures** — keeping tabs alive is good, but hidden per-tab UI state still has to start from a correct source of truth

## Ready for Next Session
- ✅ **Favicon lifecycle is cleaner and race-safe**
- ✅ **Tab switching/closing feels more browser-like and less like animated view replacement**
- ✅ **Top chrome is more stable across tab changes**
- ✅ **Fresh patched `WKWebView` instances now receive modern Google**
- 🔧 **Open item:** verify the user is launching the rebuilt binary when testing runtime compatibility changes
- 🔧 **Open item:** `looksLikeURL(...)` still does not handle `localhost` / IP destinations correctly
- 🔧 **Open item:** there is still no regression test coverage for browser identity, history behavior, or favicon lifecycle

## Context for Future
This session moved Cove from “works as an MVP” toward “feels like a browser.” The meaningful changes were not cosmetic: favicon work is tied to real navigation state, tab content stays alive instead of getting rebuilt, motion is constrained to chrome rearrangement, the navigation bar no longer jumps around, and Google compatibility was investigated with live runtime evidence instead of guesswork. If a future session continues the compatibility work, the next high-value step is to validate the actual launched app binary/process path and then add lightweight instrumentation or regression checks around browser identity (`navigator.userAgent` / page markers) so issues like the Google basic-page fallback are caught immediately.
