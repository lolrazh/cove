# Carmack-Style Codebase Refactor

**Date:** 2026-03-16
**Agent:** Claude Opus 4.6 (1M context)
**Status:** ✅ Completed

## User Intention
User wanted the entire codebase cleaned up to embody "elegant simplicity" — code that John Carmack would write. The goal was to identify and fix real architectural problems (not cosmetic ones), remove duplication and dead code, and ensure every file has a single clear responsibility. Not a rewrite — surgical improvements to what exists.

## What We Accomplished
- ✅ **Extracted FaviconFetcher from TabSession** - TabSession dropped from 552→310 lines. ~230 lines of favicon network/rendering/caching logic moved into a standalone `FaviconFetcher` class with two entry points: `update()` and `upgradeFromPage()`.
- ✅ **Deduplicated Database bind code** - `run()` and `query()` had identical 20-line parameter binding switch blocks. Extracted into a single private `bind()` method. Also made `prepare()` private.
- ✅ **Simplified BrowserSettingsStore setters** - 9 identical guard-assign-persist setter methods replaced with two generic `set()` helpers (one for `Equatable`, one for `RawRepresentable`). Setters are now one-liners.
- ✅ **Removed dead code** - `FaviconStore.image(for:)` was an unused alias for `get(domain:)`. Deleted.
- ✅ **Fixed BrowserView redundant unwrap** - `activeTabContent` was re-unwrapping `tabManager.activeTab` despite `body` already having it. Now takes the tab as a parameter.
- ⚠️ **Skipped TabSessionServices removal** - Originally planned to kill this struct, but on analysis it's a legitimate parameter object grouping 4 related deps used by both TabManager and TabSession. Removing it would scatter parameters, not simplify.

## Technical Implementation

**FaviconFetcher pattern:** Callback-based (`onResult` closure) rather than making it an `ObservableObject`. TabSession remains the single `@Published` owner of `favicon`, FaviconFetcher just does the work and reports back. This avoids adding another observable to the SwiftUI graph.

**BrowserSettingsStore generic setters:** Two overloads handle the type split:
- `set<T: Equatable>` — for Bool, String (persists value directly)
- `set<T: Equatable & RawRepresentable>` — for enums (persists `.rawValue`)

Both do the same guard-assign-persist dance, just differ in what gets written to UserDefaults.

**Files Modified:**
- `Cove/Sources/Browser/FaviconFetcher.swift` - **New file.** All favicon fetching, rendering, caching, and document link scraping logic.
- `Cove/Sources/Browser/TabSession.swift` - Removed ~240 lines of favicon code, replaced with FaviconFetcher delegation.
- `Cove/Sources/Browser/Database.swift` - Extracted shared `bind()` method, made `prepare()` private.
- `Cove/Sources/Settings/BrowserSettingsStore.swift` - Generic `set()` helpers replace 9 boilerplate setters.
- `Cove/Sources/Browser/FaviconStore.swift` - Removed dead `image(for:)` method.
- `Cove/Sources/UI/BrowserView.swift` - `activeTabContent` now takes tab as parameter instead of re-unwrapping.
- `Cove.xcodeproj/project.pbxproj` - Regenerated via xcodegen to include new file.

## Bugs & Issues Encountered
1. **SourceKit false positives after adding FaviconFetcher.swift** - LSP reported "Cannot find type 'FaviconStore' in scope" etc.
   - **Fix:** Not a real error — xcodegen sources glob picks up all files in `Cove/Sources/`. Ran `xcodegen generate` and `xcodebuild` to confirm clean build. SourceKit just needed time to re-index.

2. **`withUnsafeBytes` unused result warning in Database** - After deduplicating bind code, the `Data` case's `withUnsafeBytes` call produced a warning.
   - **Fix:** Added `_ =` prefix to discard the return value. This existed silently in the original duplicated code too.

## Key Learnings
- **Parameter objects are fine** - `TabSessionServices` looked like needless indirection at first, but it groups 4 related deps used in 2 places. Removing it would mean 4 loose params × 2 call sites = more noise, not less. Carmack wouldn't fight this.
- **`@Published` fires on every write** - The reason BrowserSettingsStore needs guard-on-same-value in setters. Every write triggers `objectWillChange` → SwiftUI re-evaluation. The generic helpers preserve this guard.
- **Swift generic overload resolution handles Equatable vs RawRepresentable cleanly** - Bool/String resolve to the plain `Equatable` overload, enums resolve to the `RawRepresentable` one. No ambiguity.

## Architecture Decisions
- **FaviconFetcher uses callbacks, not @Published** - Adding another ObservableObject would mean more SwiftUI subscription overhead. TabSession already owns `@Published var favicon` — FaviconFetcher just pushes results via closure. One owner, one direction.
- **Database.prepare() made private** - Callers should use `run()`/`query()`, not raw statements. Reduces API surface.
- **Kept all existing public interfaces intact** - No changes to how views consume TabSession, TabManager, or BrowserSettingsStore. Pure internal refactor.

## Ready for Next Session
- ✅ **Clean build, tested and running** - All 3 commits build and the app launches correctly.
- ✅ **TabSession is now focused** - At 310 lines, it's purely navigation + WebView lifecycle. Ready for new features without growing unwieldy.
- ✅ **FaviconFetcher is extensible** - Could add touch-icon support, size preference logic, or cache eviction without touching TabSession.

## Context for Future
This was a pure cleanup pass — no new features, no behavior changes. The codebase went from ~4155 to ~3850 lines with better separation of concerns. The biggest win is TabSession being half its original size, making it much easier to add navigation features (tab restoration, session state, etc.) without drowning in favicon plumbing.
