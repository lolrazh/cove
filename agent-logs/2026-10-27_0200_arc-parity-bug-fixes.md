# Arc Parity: Bug Fixes

**Date:** 2026-10-27
**Agent:** Claude Opus 5.5
**Branch:** `main`: 11 small commits, pushed as they landed
**Status:** ✅ All 11 bugs in ARC-PARITY.md § 1 fixed; Web Inspector only through Inspect Element

## User Intention
Workstream 1 of ARC-PARITY.md: fix the bugs the audit found, directly on `main`, in small commits, while two other agents rewrite the layout and build the Command Bar in their own worktrees. Every fix had to be confirmed in the running app, and the code had to stay small and match the codebase.

## What We Accomplished
- ✅ **Links from other apps open in the open window** (`279479e`). Opening three URLs gave four windows before; now it gives one window with three tabs, and the first link reuses an untouched start page. A cold launch from a link also works.
- ✅ **History opens pages in the browser window that was active last** (`279479e`, same change).
- ✅ **The address field no longer shows the URL selected** (`80f62a7`).
- ✅ **History records titles that arrive late** (`9ea9fed`).
- ✅ **Web Inspector** (`9e625af`): right-click › Inspect Element opens it. No Develop menu (see below).
- ✅ **File inputs** open an `NSOpenPanel` sheet (`6767073`).
- ✅ **`alert`, `confirm`, `prompt`** are `NSAlert` sheets titled "example.com says" (`edc6a70`).
- ✅ **HTTP authentication**: a login sheet for basic, digest and NTLM; it says when the password was wrong and pre-fills the user name (`796d8a1`).
- ✅ **Error page** with Try Again, a SwiftUI `ContentUnavailableView` over the web view (`adea99e`).
- ✅ **Plain `http://` pages load** (`803c6ac`). Not on the list: App Transport Security blocked them all, which the new error page showed.
- ✅ **Camera, microphone and location prompts** naming the site, remembered per site until quit (`3be46ff`).
- ✅ **Session restore** (`5aee193`): every window's tabs, the active tab, and each tab's back/forward list.

## Root Causes and Fixes
1. **A window per external link.** With no `handlesExternalEvents`, `WindowGroup` makes a new scene for every URL event. And History handed pages to a shared `@Published` queue that every `BrowserView` drained, so whichever window drained first got the page.
   - Fix: `BrowserView` declares `.handlesExternalEvents(preferring: ["*"], allowing: ["*"])`, so SwiftUI delivers links to an open window and opens one only if none exists. The History `Window` declares `matching: []`.
   - `ExternalURLRouter` is now the one path for links and History. Each `BrowserView` reports when it becomes active (`appearsActive`, plus `NSApp.keyWindow` to bring it forward later). The router sends pages to the most recent window, and holds them until a window exists.
   - Gone: the queue, its `willSet` workaround, `AppDelegate.application(_:open:)` (SwiftUI already consumes the URLs; it was called with an empty array) and `NSApplication.frontmostBrowserWindow`.
   - ⚠️ `.handlesExternalEvents(matching: [])` on the `WindowGroup` was tried first: no window at all on a cold launch from a link.
2. **URL drawn selected.** When a page replaced the start page, AppKit gave focus to the next key view, the address field. Becoming first responder selects the text but doesn't start an edit, so `controlTextDidBeginEditing` never ran and the field looked unfocused with its text selected. After Return the field also stayed in editing, so it never showed the loaded URL.
   - Fix, as in Safari: the page takes focus when it comes on screen (`WebViewRepresentable.makeNSView`) and when a destination is submitted (`TabSession.navigate`).
3. **Empty titles.** No longer reproducible on example.com (the page changed), so it was verified with a local page that sets its title 800ms after load. `TabSession` remembers a visit recorded without a title, and fills it in once with `HistoryStore.updateTitle(_:forLatestVisitTo:)`.
4. **Errors.** Failures are ignored when they're `NSURLErrorCancelled` or `WebKitErrorDomain` 102 (a response that became a download). Otherwise `loadFailure` is set. The address bar keeps the URL that failed: URL changes are ignored while a failure shows, and `didStartProvisionalNavigation` clears the failure and resyncs the URL.

## Technical Implementation
**New files:**
- `Browser/PageDialogs.swift`: every sheet a page can ask for: alert, confirm, prompt, login, permission. Each names the site, so pages can't impersonate Cove.
- `Browser/SitePermissions.swift`: decisions per site (scheme, host and port) and device. Camera and microphone are tracked separately, so "both" asks only for what's unknown.
- `Browser/SessionStore.swift`: `SavedTab` / `SavedWindow`, a binary plist at `Application Support/Cove/session.plist`. It saves a second after changes (tabs, active tab, any tab's URL) and on `willTerminate`. Windows claim saved windows in order as they open.
- `UI/LoadFailurePage.swift`.

**Configuration:**
- Entitlements: user-selected files (read-only), camera, audio input, location.
- `Info.plist`: camera, microphone and location usage strings; `NSAllowsArbitraryLoadsInWebContent`.

**WebKit API notes:**
- Geolocation permission is public only from **macOS 27** (`webView(_:requestGeolocationPermissionFor:initiatedBy:)`). It's `@available(macOS 27.0, *)`; on 26 WebKit's default applies.
- `isInspectable` only allows remote inspection from Safari. The context menu item needs the `developerExtrasEnabled` preference, which has no public setter, so it's set with KVC. There's no public API to open the inspector from a menu, so there's no Develop menu.

## Testing Notes
- Every fix was checked in this build, launched with `open -n … --args -browser.showTabsInSidebar NO -browser.hideTabs NO`, via window screenshots.
  - Pages were served from a local `python3 -m http.server`: file input, dialogs, late title, getUserMedia, geolocation.
  - httpbin.org covered basic and digest auth; a `.invalid` host covered the error page; info.cern.ch covered http.
- Input: `CGEvent.postToPid` delivers keys to the instance without it being frontmost. That works for sheets, NSAlerts and the address bar, but not for:
  - the sandboxed open panel, which runs out of process, so System Events was needed there;
  - the secure password field (secure input);
  - WebKit context menus, which needed real HID events.
  Focus was often taken back by the user's terminal, so every HID event was gated on a frontmost check.
- Only the deny path of permissions was exercised: granting would trigger the system's camera and location prompts.
- Restore was checked by quitting with ⌘Q and relaunching: three tabs, the right one active, Back working into the pre-quit history.

## Problems Noticed, Not Touched
- **There's no New Window command.** `CommandGroup(replacing: .newItem)` swapped File › New Window for New Tab, so only SwiftUI's window restoration makes extra windows. Routing between several windows is therefore checked by design, not in the app.
- **Downloads may stall on a system prompt.** A system prompt, "Cove would like to access files in your Downloads folder", appeared during testing (the debug build's signature changed with the new entitlements) and was left for the user. Also, "Ask Every Time" saves through an `NSSavePanel`, which in the sandbox needs `files.user-selected.read-write`; only read-only was added. Unverified.
- **Restored tabs all load at launch.** Tab sleeping (5c) should make background tabs load lazily; `interactionState` is already saved per tab for it.
- **Dialogs in background tabs are dismissed, as if cancelled.** They have no window. Showing them when the tab is selected would be nicer.
- If macOS is set to close windows when quitting an app, SwiftUI reopens only one window. Saved windows beyond the first are then dropped.
- SwiftUI restores the History window on every launch if it was open at quit.

## Context for Future
`TabSession` is still the WebKit delegate for everything, but the UI it shows now lives in `PageDialogs`. `ExternalURLRouter` is the one way to open a page from outside a window, so the Command Bar and the Little Arc feature can route through it.
