# Favicon Overhaul & Downloads Feature

**Date:** 2026-03-06
**Agent:** Claude Opus 4.6
**Status:** ✅ Completed

## User Intention
User wanted to improve Cove's favicon quality and performance to match Chromium browsers like Dia and Helium (clean logomarks instead of ugly apple-touch-icon squares, instant loading via caching and parallel fetching), then build a full downloads feature with Safari-style UX — download button in the nav bar with progress ring, popover with file details, and proper state handling for active/completed/cancelled/failed downloads.

## What We Accomplished
- ✅ **BLOB support in SQLite Database wrapper** — enables storing binary favicon image data
- ✅ **FaviconStore with disk cache and pre-warming** — SQLite-backed, loads all cached favicons into memory at launch (Dia-style)
- ✅ **Favicon priority rewrite** — excluded apple-touch-icon (the ugly squares), prioritized SVG > standard icons > Google Favicon API > /favicon.ico
- ✅ **Parallel favicon fetching** — favicon resolution starts at `loadURL()` (not `didFinish`), cache check instant, Google API fires in parallel with page load
- ✅ **Subtle corner rounding on FaviconView** — 12% of icon size, matches macOS conventions
- ✅ **5 bug fixes from code review** — Tab observation forwarding, SwiftUI state leak isolation, history write race fix, FTS5 sanitization, favicon generation counter
- ✅ **localhost/IPv4/IPv6 URL detection** — `looksLikeURL()` now handles dev URLs
- ✅ **DownloadManager** — WKDownloadDelegate lifecycle, progress KVO, cancel/resume, file deduplication
- ✅ **Download detection in WKNavigationDelegate** — `canShowMIMEType` check converts non-displayable responses to downloads
- ✅ **Download popover UI** — file icon (NSWorkspace), circular progress ring, size tracking, format badge, click to open, reveal in Finder
- ✅ **Progress ring on nav bar download button** — aggregate progress visible without opening popover
- ✅ **Download sandbox entitlement** — added `files.downloads.read-write`
- ✅ **Tabular numerals** — `.monospacedDigit()` prevents digit jitter during progress updates
- ✅ **Distinct cancelled/failed download states** — greyed-out icon + label vs red ring + label

## Technical Implementation

### Favicon Pipeline (user later simplified further)
- JS extraction finds `<link rel="icon">` tags, excludes apple-touch-icon entirely
- Google Favicon API (`t1.gstatic.com/faviconV2`) as fast CDN fallback
- FaviconStore: SQLite `favicons` table (domain TEXT PK, image_data BLOB, updated_at REAL)
- Pre-warming: loads all cached favicons into `[String: NSImage]` dict at launch
- User subsequently simplified to canonical `/favicon.ico` + cache in a separate session (see previous logs)

### Downloads Architecture
- `DownloadItem`: ObservableObject tracking filename, sourceURL, fileURL, state, progress, bytesDownloaded, totalBytes
- `DownloadManager`: singleton, WKDownloadDelegate, maps WKDownload→DownloadItem
- Progress: KVO on `download.progress.fractionCompleted`, `.completedUnitCount`, `.totalUnitCount`
- File deduplication: appends `(1)`, `(2)` etc. if file exists in ~/Downloads
- Nav bar button: circular progress ring using `overallProgress` (aggregate of all active downloads)
- File icons: `NSWorkspace.shared.icon(for: UTType)` — matches Finder

### Bug Fixes
1. **Tab.objectWillChange forwarding** via Combine sink — views observing Tab now re-render on WebViewModel changes
2. **`.id(tab.id)` on ActiveTabView** — prevents @State leaking across tab switches
3. **Direct WKWebView read in didFinish** — avoids racy KVO-mirrored @Published state for history
4. **FTS5 input sanitization** — strips non-alphanumeric chars before MATCH query
5. **Favicon generation counter** (later replaced by siteKey + requestID by user)

**Files Modified/Created:**
- `Cove/Sources/Browser/Database.swift` — BLOB bind/read support
- `Cove/Sources/Browser/FaviconStore.swift` — new, SQLite disk cache + memory cache
- `Cove/Sources/Browser/WebViewModel.swift` — favicon rewrite, parallel fetching, download delegate hooks, localhost URL detection
- `Cove/Sources/Browser/Tab.swift` — objectWillChange forwarding via Combine
- `Cove/Sources/Browser/HistoryStore.swift` — FTS5 sanitization
- `Cove/Sources/Browser/DownloadManager.swift` — new, WKDownload lifecycle
- `Cove/Sources/UI/BrowserView.swift` — .id(tab.id) fix
- `Cove/Sources/UI/FaviconView.swift` — corner rounding
- `Cove/Sources/UI/NavigationBar.swift` — download button with progress ring
- `Cove/Sources/UI/DownloadPopover.swift` — new, download list popover
- `Cove/Resources/Cove.entitlements` — files.downloads.read-write

## Bugs & Issues Encountered
1. **URL bar auto-hide on scroll failed (3 attempts)**
   - Tried: JS scroll listener, NSScrollView observation, NSEvent scroll wheel monitor
   - None worked reliably with WKWebView. Scrapped for now — needs deeper investigation.

2. **Downloads failed silently**
   - **Root cause:** App Sandbox blocked write access to ~/Downloads
   - **Fix:** Added `com.apple.security.files.downloads.read-write` entitlement

3. **Swift 6 actor isolation in WKDownloadDelegate**
   - `WKDownload.originalRequest` is MainActor-isolated, can't access from nonisolated delegate method
   - **Fix:** Move the read inside `await MainActor.run {}` block

4. **`FaviconStore` not found in scope after creating file**
   - **Fix:** Run `xcodegen generate` to add new files to Xcode project

5. **Apple-touch-icon producing ugly square favicons**
   - **Root cause:** apple-touch-icons are designed for iOS home screen (solid color square + white logo)
   - **Fix:** Excluded entirely from favicon priority chain

## Key Learnings
- **apple-touch-icon is always the wrong choice for browser tab favicons** — it's designed for iOS home screens, always has a solid background square
- **Favicon speed is about when you start, not network speed** — the icon is 1-5KB vs 1-5MB for the page, it should arrive first if you start early
- **`.monospacedDigit()` in SwiftUI = `font-variant-numeric: tabular-nums` in CSS** — prevents digit width jitter in counters/progress
- **WKWebView scroll detection is hard on macOS** — JS `window.scroll` events don't fire for many sites, internal NSScrollView may not be accessible, NSEvent monitors don't seem to receive scroll events targeting WKWebView
- **App Sandbox requires explicit entitlements for ~/Downloads** even though it's a standard user directory
- **Swift 6 actor isolation is strict with WebKit delegate methods** — properties on WKDownload are MainActor-isolated

## Architecture Decisions
- **Singleton DownloadManager** — downloads are global state, not per-tab. Any tab's WKWebView can trigger a download, all go to the same list.
- **No NSSavePanel** — auto-save to ~/Downloads with deduplication. Matches Safari's default behavior. Less friction than asking the user where to save every file.
- **Aggregate progress on nav button** — single ring showing combined progress of all active downloads. More useful than per-download indicators in a toolbar.

## Ready for Next Session
- ✅ **Downloads feature complete** — working end-to-end with good UX
- ✅ **Favicon system solid** — cache, parallel fetch, correct icons
- ✅ **All previous open items closed** — localhost detection, build warnings clean
- 🔧 **URL bar auto-hide** — still unresolved, needs research into WKWebView scroll interception
- 🔧 **Keyboard shortcuts** — Cmd+T/W/L/[/] not yet implemented
- 🔧 **Phase 2 remaining** — bookmarks, settings, content blocking

## Context for Future
This session moved Cove from MVP into Phase 2 territory. The favicon system now matches Chromium browsers in quality and speed. Downloads are fully functional with Safari-style UX. The "parallel everything" philosophy is now a core project principle — documented in MEMORY.md. Next high-value features are bookmarks (SQLite-backed, similar architecture to history/favicons) and keyboard shortcuts (essential browser UX). Content blocking (WKContentRuleList) is the biggest remaining user-facing upgrade.
