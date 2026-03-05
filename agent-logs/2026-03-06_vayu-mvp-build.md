# Vayu Browser — MVP Build Session

**Date:** 2026-03-06
**Agent:** Claude Opus 4.6
**Status:** ✅ Completed

## User Intention
User wants to build a native macOS browser from scratch because every existing browser fails in some way — Dia is beautiful but bloated with AI and memory-heavy, Safari has Liquid Glass forced on it, Orion/Zen/Brave are tacky or cluttered. The goal is a browser with Dia's clean aesthetic, Safari's performance (WKWebView/WebKit), zero AI features, zero Liquid Glass, and zero dependencies. This session focused on building a working MVP — a shitty version that works, to iterate from.

## What We Accomplished
- ✅ **Xcode project scaffold** — xcodegen-based project, pure Swift 6, macOS 15+ target, zero deps, Liquid Glass disabled via `UIDesignRequiresCompatibility`
- ✅ **WKWebView browser shell** — WebViewRepresentable wrapping WKWebView with full navigation delegate
- ✅ **URL bar + navigation** — Smart URL/search detection (URLs navigate, text searches Google), back/forward/reload with proper state, linear progress bar
- ✅ **Tab system** — Full tab model with independent WKWebViews per tab, add/close/switch, always-keep-one-tab guard
- ✅ **Horizontal tab strip** — Top tab bar with titles, favicons, close buttons, new tab button
- ✅ **Vertical sidebar tabs** — Auto-hiding sidebar, hover-to-reveal, layout toggle between horizontal/sidebar
- ✅ **History persistence** — SQLite via C API (zero deps), FTS5 full-text search, auto-record on page load, searchable popover UI
- ✅ **Smooth animations** — Tab open/close scale+fade, hover transitions, layout crossfade, progress bar opacity
- ✅ **Favicon support** — High-res fetching (apple-touch-icon preferred), 32x32pt Retina rendering, globe placeholder
- ✅ **New tab page** — Clean centered search bar with auto-focus, recent sites grid (deduplicated by domain from history)
- ✅ **Private GitHub repo** — All work pushed to github.com/lolrazh/vayu with descriptive commits at each step
- ✅ **Detailed PRODUCT.md** — Full product doc capturing vision, design decisions, technical spec, architecture, and roadmap

## Technical Implementation

### Architecture
```
VayuApp (@main) → WindowGroup → BrowserView
  ├── TabStripView (horizontal) OR SidebarTabView (vertical)
  └── ActiveTabView (@ObservedObject Tab)
       ├── NavigationBar (URL bar + nav buttons + history popover)
       ├── ProgressView (loading indicator)
       └── NewTabPage OR WebViewRepresentable
```

### Key Patterns
- **WebViewModel** (ObservableObject) wraps WKWebView, publishes state via KVO observers → `Task { @MainActor }` bridge
- **TabManager** owns array of Tabs, each Tab owns a WebViewModel (independent WKWebView per tab)
- **Database.swift** — thin SQLite C API wrapper, WAL mode, parameterized queries
- **HistoryStore** — singleton, FTS5 with auto-sync triggers, prefix matching search
- **Favicon fetching** — JS injection to find best icon link, async download with fallback chain

**Files Created/Modified:**
- `project.yml` — xcodegen project definition
- `Vayu/Sources/App/VayuApp.swift` — @main entry, hiddenTitleBar window style
- `Vayu/Sources/App/AppDelegate.swift` — NSWindow config, anti-Liquid Glass
- `Vayu/Sources/Browser/WebViewModel.swift` — WKWebView wrapper with KVO, favicon fetching, navigation delegate
- `Vayu/Sources/Browser/WebViewRepresentable.swift` — NSViewRepresentable for WKWebView
- `Vayu/Sources/Browser/Tab.swift` — Tab model (ID + WebViewModel + isNewTabPage)
- `Vayu/Sources/Browser/TabManager.swift` — Tab lifecycle, layout toggle
- `Vayu/Sources/Browser/Database.swift` — SQLite C API wrapper
- `Vayu/Sources/Browser/HistoryStore.swift` — History with FTS5
- `Vayu/Sources/UI/BrowserView.swift` — Main composition view
- `Vayu/Sources/UI/NavigationBar.swift` — URL bar + nav buttons + history
- `Vayu/Sources/UI/TabStripView.swift` — Horizontal tab strip
- `Vayu/Sources/UI/SidebarTabView.swift` — Vertical sidebar tabs
- `Vayu/Sources/UI/HistoryView.swift` — History search popover
- `Vayu/Sources/UI/NewTabPage.swift` — New tab page with search + recents
- `Vayu/Sources/UI/FaviconView.swift` — Favicon display component
- `Vayu/Resources/Info.plist` — UIDesignRequiresCompatibility = YES
- `Vayu/Resources/Vayu.entitlements` — Sandbox + network client
- `PRODUCT.md` — Full product doc

## Bugs & Issues Encountered
1. **New tab page wouldn't dismiss when navigating**
   - **Root cause:** `BrowserView` observed `TabManager` but not individual `Tab` objects. When `tab.isNewTabPage` changed, SwiftUI didn't re-render.
   - **Fix:** Extracted `ActiveTabView` with `@ObservedObject var tab: Tab` so the view subscribes to Tab's published properties.

2. **Favicons looked blurry/pixelated**
   - **Root cause:** Fetching 16x16 `.ico` files, which look terrible on Retina (scaled up to 32 physical pixels).
   - **Fix:** Prefer `apple-touch-icon` (180x180 PNG), render at 32x32pt with high interpolation. Still not perfect — user noted they're "not that good" compared to Dia.

3. **xcodegen overwrites Info.plist**
   - **Root cause:** The `info.path` directive in project.yml tells xcodegen to generate the plist.
   - **Fix:** Removed `info.path`, kept only `INFOPLIST_FILE` build setting so our custom plist is preserved.

## Key Learnings
- **`UIDesignRequiresCompatibility = YES`** in Info.plist disables Liquid Glass on macOS 26 Tahoe. This is the official Apple opt-out mechanism.
- **WKWebView KVO → SwiftUI** requires `Task { @MainActor }` bridge inside KVO closures to safely update `@Published` properties.
- **SwiftUI observation chains** — a parent view observing `TabManager` does NOT automatically observe `@Published` properties on objects inside `TabManager.tabs`. You need `@ObservedObject` on the child object in a sub-view.
- **WKWebView per-tab memory** is ~15-30MB baseline. Shared `WKProcessPool` saves memory at cost of crash isolation.
- **Favicon quality** — always fetch the largest available icon (apple-touch-icon > sized link tags > /favicon.ico). The `.ico` format is legacy garbage on Retina.
- **xcodegen** is excellent for keeping the project definition readable and diffable vs the opaque `.pbxproj` format.

## Architecture Decisions
- **Zero dependencies** — user explicitly chose pure Swift + Apple frameworks. SQLite via C API instead of GRDB/SQLite.swift. No SPM packages.
- **SQLite over CoreData** — user wants lightweight, explicit control. FTS5 for search is a huge win.
- **xcodegen over manual .xcodeproj** — project.yml is human-readable, regenerable, git-friendly.
- **Per-tab WKWebView** — each tab gets its own WebView instance for full isolation. Shared WKProcessPool for memory efficiency.
- **Both tab layouts from MVP** — user wanted horizontal AND sidebar from the start, switchable. Not deferred.
- **System-adaptive colors** — follows macOS light/dark, no custom theming in MVP.

## Ready for Next Session
- ✅ **Working browser** — Opens, navigates, tabs work, history persists, new tab page functional
- ✅ **Clean architecture** — Clear separation: Browser layer (WebViewModel, Tab, TabManager, History, DB) and UI layer
- ✅ **PRODUCT.md** — Full context document for any future session to pick up from
- 🔧 **Favicon quality** — User noted favicons still don't look as good as Dia. May need favicon caching, better source selection, or SVG support
- 🔧 **URL bar auto-hide on scroll** — Specified in design spec but not yet implemented
- 🔧 **Keyboard shortcuts** — No shortcuts yet (Cmd+T, Cmd+W, Cmd+L, etc.)

## Context for Future
This session built the complete MVP of Vayu — a native macOS browser on WKWebView. The foundation is solid: clean architecture, zero deps, working tabs/navigation/history. The next phase per PRODUCT.md is either UI polish (auto-hide URL bar, keyboard shortcuts) or starting Phase 2 features (content blocking via WKContentRuleList, bookmarks, downloads). The long-term vision includes a WebExtensions compatibility layer for Chrome extension support — that's the "big lift" described in PRODUCT.md.
