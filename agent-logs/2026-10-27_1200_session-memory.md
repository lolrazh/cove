# Session and Memory: Tab Sleeping and Auto-Archive

**Date:** 2026-10-27
**Agent:** Claude Fable 5.1
**Branch:** `session-memory`, PR to `main`
**Status:** ✅ Complete; section 5c of ARC-PARITY.md ticked

## User Intention
Workstream 5c of `ARC-PARITY.md`, after session restore landed with the
bug fixes: sleep background tabs after inactivity (release the `WKWebView`,
keep title, favicon, URL and interaction state, wake on select; never a tab
playing media, capturing, or holding typed input; restored tabs start
asleep), auto-archive Today tabs untouched for a setting's worth of time
into a searchable archive (Command Bar now, Library later), and sleep
eagerly under memory pressure. The tab model is shared with the 5a and 5b
agents, so the awake/asleep distinction had to be one explicit state, not
optional web views checked all over.

## What We Accomplished

### The page state (`TabSession.Page`)
- ✅ `TabSession.page` is `.awake(WKWebView)` or
  `.asleep(interactionState: Data?)`. `wake()` is the one place web views
  are made (configure, observe, restore the interaction state or load the
  URL afresh) and `sleep()` the one place they're released, so the dozen
  former `webView.` call sites read `wake().goBack()`, and only
  `stopLoading`, `savedTab` and `dialogWindow()` pattern-match the state.
  Replacing the web view behind the synthetic start page became
  `discardPage()`: release, `.asleep(nil)`, and the next navigation wakes.
- ✅ **The selected tab is always awake.** `TabManager.activeTabID`'s
  `didSet` wakes it, so every path that selects (open, close, restore,
  reopen) gets it for free, and `ActiveTabView` shows the web view from
  the `.awake` case. `WebViewRepresentable` now takes the web view and an
  `onAppear`, not the tab.
- ✅ **Lazy restore.** Restored tabs are built asleep with their saved
  interaction state, title and cached favicon; the window selects its
  active tab, which wakes it. A launch loads one page per window instead
  of every page. The same path restores a tab out of the archive.
- ✅ A page that failed to load sleeps without its interaction state, so
  waking tries the URL again instead of restoring the page before it.

### The policy (`TabIdlePolicy`, pure, tested)
- ✅ Given a snapshot (active, asleep, has a page, in use, last used) and
  the two delays: archive when idle past the archive delay, else sleep when
  idle past the sleep delay and awake with a page; never the selected tab
  or one in use. An empty tab is never slept but is archived, which just
  closes it. `underMemoryPressure` is the same policy with a zero sleep
  delay: everything that can sleep does, even when sleeping is set to Never.
- ✅ **In use** (`TabSession.isInUse`): sound playing (`isPlayingAudio`,
  from 5a's `PageAudio`, muted or not), camera or microphone capture
  (`cameraCaptureState`, `microphoneCaptureState`), or typed input.
- ✅ **Typed input** (`FormInput`): a user script in the main frame, built
  like `LinkHover`, remembers the fields that got `input` events and, on
  every input, key-up or click, posts whether any still differs from its
  default (or, for an editable element, still has text). Re-checking on
  keys and clicks catches composers a page empties itself, like a chat box
  after Return. Reset on each main-frame navigation and on sleep.
- ✅ **Last used** (`TabSession.lastUsedAt`): set when a tab is selected
  and again when it's left, so idle time counts from the moment you looked
  away. Saved in `SavedTab` (optional, so older session files still
  decode), so idle time survives a relaunch.

### The sweep
- ✅ `TabSweepClock` publishes a tick a minute (a Combine `Timer`) merged
  with `DispatchSource.makeMemoryPressureSource` warnings and criticals
  (flagged `true`). `TabManager` subscribes with its existing
  `cancellables` and runs `sweepIdleTabs(underMemoryPressure:now:)` over
  Today, sleeping or archiving per the policy. One clock per window; the
  pressure source is cancelled in `deinit`.
- ✅ **Settings › General › Tabs:** "Sleep background tabs after" 5 / 15 /
  30 minutes, 1 hour, Never (default 30 minutes); "Archive unused tabs
  after" 12 / 24 hours, 7 / 30 days, Never (default 24 hours). Keys
  `browser.sleepTabsAfter`, `browser.archiveTabsAfter`.

### The archive (`TabArchive`)
- ✅ SQLite at `Application Support/Cove/archive.db`: id, url, title,
  interaction state (blob), archived-at. `entries` (`ArchivedTab`: id,
  url, title, archivedAt; newest first) is `@Published` for the Library to
  list; `add(_:at:)` takes a `SavedTab` (start pages are dropped, which is
  how an idle empty tab simply closes) and keeps the newest 500;
  `take(_:)` removes an entry and returns it as a `SavedTab`, which
  `TabManager.reopenArchivedTab` turns into a tab through the restore path,
  back/forward list included.
- ✅ **Command Bar:** an **Archive** group between Switch to Tab and
  History, up to three rows matching every typed word, newest first among
  equals, with favicon, title and address. A page shows once: an open tab
  beats an archived one, which beats history. `CommandBarResult.Kind
  .archived(UUID)`.

### Rebased on tab basics (PR #7) and page tools (PR #8)
- ✅ `wake()` goes through `configureWebView`, so a woken tab gets its
  `PageAudio` again, handed the tab's `isMuted`; `sleep()` drops the
  monitor and clears `isPlayingAudio`. `customTitle` is restored in `init`
  for every tab (start pages included), untouched by sleeping, and kept
  through the archive (a `custom_title` column; the entry goes by it).
  Nothing to add to `savedTabChanges`: `lastUsedAt` only changes with the
  active tab, which already saves.
- ✅ `findInPage` reads the web view through `wake()`, so the find bar
  follows a woken page; its state is per tab and is left alone by sleep
  (⌘G searches the new page from the top). `pageZoom` answers the site's
  remembered zoom while asleep and wakes to set; `didCommit` re-applies the
  zoom when the woken page loads. Print, Save Page As, View Source and
  Picture in Picture act through `wake()`.
- ✅ `TabSession.webView` stays as a read-only optional (nil while asleep)
  for the two callers that only want the page's window; everything that
  acts on the page starts at `wake()`.

### Sidebar and strip
- ✅ A sleeping tab's favicon and title fade to 55% in `ChromeTabItem`
  (`ChromeMotion.fade`), and come back under the pointer; nothing else
  about the row changes. Same component, so the top strip gets it too.

### Tests (10 new)
- `TabIdlePolicyTests`: the delay boundary, selected and in-use tabs left
  alone, sleeping and empty tabs not slept, archive winning, Never, and
  memory pressure (sleeps now, still respects active/in-use/asleep, keeps
  the archive delay).
- `TabArchiveTests` (a temp directory per test): round trip with the
  interaction state and the custom title and take-once, persistence across
  instances newest first, start pages dropped and the limit trimming the
  oldest.
- `CommandBarRankerTests`: the Archive group and its dedup against
  history; an open tab beating the archive.

## Verified
Screenshots in the session scratchpad, `session-memory/`:
- `01-restored-lazy.png`: a seeded session of five tabs (two left 2 and 3
  days ago, two left minutes ago, example.com active). Only example.com
  loaded; the other four sit dimmed with their saved titles and cached
  favicons.
- `02-after-first-sweep.png`: 60 s later the two tabs idle for days are
  gone from Today; the recent ones stayed.
- `03-commandbar-archive.png`, `03b-…-selected.png`: typing `wkweb` lists
  the archived Apple docs tab under **Archive** with its favicon, title and
  address, below the search row and above the suggestions.
- `04-reopened-from-archive.png`: Return on it brings the tab back,
  selected, loading, with its title already in the sidebar.
- `05-settings-general.png`: the Tabs section with both pickers and the
  footer; the pane still fits the 520×400 window.
- `06-slept-after-five-minutes.png`: with `-browser.sleepTabsAfter
  fiveMinutes`, the tabs left five minutes earlier dimmed at the next tick
  while the selected one stayed awake.
- `07-rebased-restored.png`, `08-woken-by-shortcut.png`: the build rebased
  on tab basics and page tools restores the same way, and ⌘3 wakes the
  third sidebar tab, which undims and renders while the one left behind
  stays awake.

Unit tests: `xcodebuild test`, 40 tests in 7 suites pass after the rebase
(10 of them new).

## Key Learnings
- **`didSet` on a `@Published` property is the right seam for an
  invariant** like "the selected tab is awake": it fires for assignments
  made in methods (including ones called from `init`), so no caller has to
  remember to wake.
- **Worktrees share refs.** `origin/main` moved under a rebase when a
  sibling agent fetched after PR #8 merged; autosquashing onto the first
  commit's own parent (`<sha>^`) keeps a follow-up rebase on the base you
  resolved against. A keep-both regex for conflict hunks slipped twice
  (a duplicated argument, a lost brace), which the build caught; worth a
  look at each hunk instead.
- **`DispatchSource` event handlers are `@Sendable`**; the clock captures
  `[weak self]` (a `@MainActor` class is `Sendable`) and uses
  `MainActor.assumeIsolated` since the source runs on `.main`, instead of
  capturing a `PassthroughSubject` directly.
- Keystroke testing on this Mac: `⌘T` opened a start page because the
  user's `browser.newTabPreference` is Start Page; `⌘L` opens the Command
  Bar regardless. Other agents' Cove builds take focus often enough that
  every keystroke needs the frontmost check the brief asks for; one run
  found `loginwindow` frontmost for a moment without the screen being
  locked (`CGSSessionScreenIsLocked` was false).

## Decisions for the coordinator
- **Manual closes don't archive.** Arc's archive holds every closed Today
  tab; here `closeTab` still records to `RecentlyClosedTabs` only. Folding
  that list into `TabArchive` (same shape: take by id, newest first) is a
  natural step for 5g's Library, and would give Reopen Last Closed Tab the
  back/forward list too. Left alone to keep out of 5a's `closeTab` changes.
- **Pinned and Favorites aren't swept.** The sweep runs over `tabs`
  (Today) only, and only Today should be archived. When 5d fills the other
  collections, the sleep pass should include them (the policy already
  takes a per-tab `hasPage`/`isActive`; a section flag for archiving is the
  only addition).
- **Memory pressure overrides Never** for sleeping (never for archiving).
  The in-use guards still hold.

## Deferred
- The Library's archive list (5g) reads `TabArchive.entries`; it will want
  `remove(_:)`/`clear()` when it exists.
- Form input in subframes isn't detected (`forMainFrameOnly: true`), to
  keep one flag per tab.
- Memory pressure wasn't exercised live (`memory_pressure -l warn` needs
  root); the policy path is unit-tested.
