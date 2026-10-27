# Pinned Tabs, Favorites and Folders

**Date:** 2026-10-27
**Agent:** Claude Fable 5.1
**Branch:** `pinned-favorites`, PR to `main`
**Status:** ✅ Code complete and unit-tested; section 5d and 5g's bookmark
import ticked in ARC-PARITY.md. The core flows were verified live once the
screen unlocked; the rest is listed under Verified for the coordinator.

## User Intention
Section 5d of `ARC-PARITY.md`: Arc's pinned tabs and Favorites. Pin a tab
(⌘D, context menu, Command Bar) into a section that outlives the Today
session; pinned tabs remember their pinned address, show the way back when
navigated away, and reset instead of closing; Favorites as a grid of icon
tiles above Pinned; drag between Today, Pinned and Favorites and reorder
within each; folders in Pinned that nest, rename and fold; a sensible
top-tab mode. Shape it so 5e's Spaces (a Pinned per space, Favorites
shared) and 5i's private windows (no pins) follow cleanly. Ran in parallel
with 5g (Library), 5h (media) and 5i (site controls), and rebased onto all
three; 5g's bookmark parsers were waiting for this model, so the import
landed here too.

## What We Accomplished

### The model (`SidebarTree`, `Pins`, `PinStore`; all tested)
- ✅ **`SidebarTree<Tab>`**: tabs and folders, generic over the tab so the
  saved form (`Pin`) and the live form (`TabSession`) share one shape and
  the moves are tested on plain values. `tabs` flattens folders,
  `visibleTabs` skips folded ones, `ids` is the pre-order. `remove`,
  `insert(at: SidebarPosition)` (`before`/`after` an item, `into` a
  folder, `end`), `update(tab:)`, `update(folder:)`, `map`. A folder never
  goes inside itself. `move(_:onto:)` is 5a's drag rule extended to a
  tree: the dragged item takes the place of the one under it, which shifts
  toward where the drag came from (pre-order decides which side).
- ✅ **`Pin`** is a bookmark: id, the pinned URL, the pinned page's title.
  **`Pins`** holds `favorites: [Pin]` (a row, no folders) and
  `pinned: SidebarTree<Pin>`, with `section(of:)`, `add`, `remove`,
  `update`, `move(to:at:)` between sections (folders stay in Pinned),
  `move(onto:)` for drags (Favorites come before Pinned, so a drop from the
  other section lands on the side it came from), and the folder calls.
  **For Spaces**: `pinned` becomes per space; `favorites` stays shared.
- ✅ **`PinStore`** (one per app, `Application Support/Cove/pins.plist`):
  `@Published pins`, changed through one `change { }` that publishes and
  saves once per change and forgets the tabs of pins that are gone; plus
  `record(_:for:)`/`savedTab(for:)`, the live tab behind each pin (URL,
  title, custom title, back/forward list) so a pinned tab comes back where
  it was left, like Arc. Saves are debounced a second and forced at quit.
  `PinStore(fileURL: nil)` keeps nothing: what private windows get.

### Live tabs (`TabManager`)
- ✅ `favorites: [TabSession]` and `pinned: SidebarTree<TabSession>` are
  derived from the store on every publish (`reconcilePinnedTabs`): a tab
  per pin, built asleep from its recorded state (or the pin's URL) with
  the pin's id, kept in a registry; tabs of pins that vanished (unpinned in
  another window) are closed unless they're back in this window's Today.
  Every window shows the same pins with live tabs of its own; two windows
  recording the same pin's tab is last-writer-wins.
- ✅ Each pinned tab's `savedTabChanges` (now including the page title)
  records its state to the store, and updates the pin's title while the tab
  is at its pinned page. `@Published` announces before setting, so the
  recorder waits a turn of the main queue.
- ✅ `tab(_:)` finds any tab; `allTabs`; `tabsInDisplayOrder` is Favorites,
  Pinned (visible ones in the sidebar, all in the strip), Today, so ⌃Tab,
  ⌘1–9, Close Tabs Below and the Command Bar's Switch to Tab cover pins.
  The media player sees pinned tabs' `nowPlaying` too.
- ✅ **Pin** (`pinTab(_:to:at:)`): a Today tab with a URL leaves `tabs`,
  gets `pinnedURL`, and its pin goes to the end of Pinned or Favorites (or
  a drop position). **Unpin** puts the live tab back at the top of Today
  (or where it was dropped). `togglePinned` for ⌘D. `moveTab(_:onto:)`
  now crosses sections; `moveTab(_:into:)` for folders; `moveTab(_:toEndOf:)`
  for a section's empty space.
- ✅ **Closing a pinned tab** (`closeTab`, ⌘W, the row's X): the next tab
  takes its place on screen, then `TabSession.resetToPin(title:)` drops the
  page and its history, puts the tab back at its pinned address, asleep,
  with the pin's remembered title. The last tab in the window (a pinned
  one with Today empty) resets and wakes instead. `canCloseTab`: a Today
  tab unless it's the last tab in the window; a pinned tab while awake or
  away from its pin. Today may now be empty: closing its last tab selects
  the pinned tab nearest the Clear line.
- ✅ **Sleeping, never archiving:** the sweep runs the idle policy over
  Today as before and `policy.neverArchiving` over pinned tabs.
- ✅ **Folders:** `newFolder(in:around:)` (end of Pinned, inside a folder,
  or around a pinned tab in its place), `renameFolder`,
  `toggleFolderCollapsed` (persisted), `deleteFolder` (its tabs go back to
  Today). `folderToName` tells the sidebar which new folder to name.
- ✅ **Private windows** get `PinStore(fileURL: nil)`; `isPrivate` hides
  Pin Tab, Add to Favorites, New Folder and Import in the menus and the
  Command Bar, and the sidebar's drop zones.

### `TabSession`
- `pinnedURL` (nil for Today), `isAwayFromPin` (trailing slash ignored),
  `returnToPin()` (loads the pinned address on top of the history),
  `resetToPin(title:)`. Rename works unchanged: `customTitle` is part of
  the recorded state, so a pinned tab's name survives relaunch.

### Sidebar (`SidebarTabView`)
- ✅ **Favorites**: a `LazyVGrid` of adaptive 30–40pt favicon tiles, 6 to a
  row at the default width and 10 at the widest; tiles select, dim while
  asleep, carry the full context menu and are drag sources and targets.
- ✅ **Pinned**: `SidebarPinnedList` renders the tree recursively; a
  folder's contents sit 14pt in. `SidebarFolderRow`: folder glyph, name,
  a chevron that turns when open; click folds, double-click renames in
  place (Return keeps, Escape cancels, empty keeps the old name), and a
  new folder opens its name field at once; context menu Rename Folder…,
  New Folder (nested), Delete Folder. Folders drag like tabs; a tab or
  folder dropped on a folder row goes inside it, with the row lit while
  targeted.
- ✅ **Drop zones**: while a drag is in progress, an empty Favorites or
  Pinned shows a dashed "Favorites"/"Pinned" slot; a drop on a section's
  empty space goes to its end, unless the tab is already there (it passed
  over the section's tabs on the way), when the drop just ends.
- ✅ One animation key for the whole sidebar (favorites, visible pinned
  tabs, Today, folder ids), so moves between sections and folding animate
  with `ChromeMotion.tab` like 5a's reorder.
- ✅ Rows show a **back-to-pin** accessory (↩, "Back to github.com") beside
  the audio and close buttons while the tab is away from its pinned page.

### Top-tab mode
- ✅ Favorites and pinned tabs lead the strip as `ChromeTabItem`'s new
  `.compact` presentation: 42pt wide, favicon only (the audio control in
  its place while there's sound), the title as a tooltip, the same active
  shape, drag and context menu. Folders are flattened, since the strip has
  no place for hierarchy; in top mode ⌘1 is the first favorite. Chose
  Safari's familiar convention over hiding pins in top mode: the pins stay
  reachable and the layout stays one row.

### Menus and Command Bar
- ✅ `TabActions` opens with pinning: Today → Pin Tab (⌘D from the Tab
  menu), Add to Favorites; pinned → Unpin Tab (⌘D), Add to Favorites /
  Move to Pinned, Back to Pinned Page while away, New Folder with Tab.
  Close Tab is enabled by `canCloseTab`; Close Tabs Below only counts
  Today tabs.
- ✅ Command Bar: Pin Tab, Unpin Tab, Add to Favorites, New Folder,
  Import Bookmarks; Switch to Tab lists pinned tabs; favicons come from
  any tab.
- ✅ **File › Import Bookmarks…** (and the Command Bar): an open panel
  (defaulting to `~/Library/Safari`), `BookmarkImport.bookmarks(from:)`,
  and the tree becomes a Pinned folder "Imported from Safari" or "…Chrome"
  (`BookmarkImport.source(of:)` is new), nesting kept, with a toast of the
  count or "Couldn't Read Bookmarks".

### Tests (16 new; 74 in 15 suites pass)
- `SidebarTreeTests`: flattening and visibility, find/remove anywhere,
  insert at every position, a folder never inside itself, drag-onto in
  both directions and out of a folder, update in place and `map`, plist
  round trip.
- `PinsTests`: sections, moves between them (folders stay), drop sides,
  title update, folder deletion returning its pins, imported bookmarks.
- `PinStoreTests`: pins and recorded tabs survive a relaunch, removed
  pins' tabs forgotten, an unchanged layout isn't republished, the
  in-memory store keeps nothing.

## Verified
- `xcodebuild test`: 74 tests in 15 suites pass after rebasing on #10,
  #11 and #12.
- Live, in a build from this worktree with a seeded four-tab session
  (`seed.plist`), screenshots in the session scratchpad,
  `pinned-favorites/`. The screen was locked for the first two hours
  (`CGSSessionScreenIsLocked=Yes` in `ioreg -n Root -d1`: a new app gets no
  window and no input lands), and once it unlocked the user was working on
  the Mac, so every keystroke went through a frontmost check and the run
  stopped when the user closed the windows.
  - `01-seeded.png`: the session restored, three tabs asleep.
  - `02-pinned.png`: ⌘D moved the active Apple tab above the Clear line;
    `pins.plist` appeared a second later.
  - `03-pinned-menu.png`: the pinned row's menu: Unpin Tab, Add to
    Favorites, New Folder with Tab, then the usual items.
  - `08-new-folder-naming.png`, `10-dblclick-rename.png`: New Folder with
    Tab put a folder around Apple in its place, indented it, and opened the
    name field at once; typed text landed in the field. Return committed
    the name (it's in `pins.plist`). The doubled "Apple StuffApple Stuff"
    came from the second rename: a field focused from code kept its
    insertion point instead of selecting the name, so typing appended.
    Fixed: `RenameField`, shared by tabs and folders, selects all as it
    takes focus.
  - `16-relaunched.png`: after quit and relaunch the folder and its pinned
    tab are back, the tab asleep.
  - `17-top-mode.png`: in top mode the pinned Apple leads the strip as a
    favicon-only tab before the Today tabs.
  - `19-away-from-pin.png`: ⌘L on a Today tab navigates as before with
    pins present.
  - `21-cmd1.png`: ⌘1 selects the pinned Apple tab (an earlier attempt,
    `18-…`, ran while the user's app had focus and didn't register; the
    order is now a pure `TabLayout.displayOrder`, tested).
  - `22-away.png`: with the pinned tab active, ⌘L `apple.com/mac/` Return
    switched to the open Today tab "Mac - Apple" instead of navigating:
    the Command Bar's top hit for an open page is that tab. Not a pin
    bug; the doubled folder name in `16`/`19` was the rename field not
    selecting its text, fixed by `RenameField`.
  - `24-away.png`: ⌘L `apple.com/ipad/` Return navigates the pinned tab
    away and its row shows the ↩ back-to-pin accessory.
- **Not verified live** (the user was working on the Mac; focus was lost
  before these ran and the windows were closed): ⌘W resetting a pinned
  tab, the ↩ click itself, the Favorites grid and its drop zone, drags
  between sections and onto folders, the private window, Import
  Bookmarks….

## Key Learnings
- **One `change { }` on the store** keeps structure edits atomic: a move
  between Favorites and Pinned is one publish, so the window's reconcile
  never sees the pin missing and closes its live tab by mistake. The
  registry is what lets a pin's tab survive a cross-section move: the tab
  is adopted before the store learns of the pin, and released into Today
  before the store forgets it.
- **Direction decides the drop side.** With live "make room" moves, a tab
  entering a target from above must land below it and vice versa; in a
  tree the pre-order index gives the direction, and across sections the
  display order (Favorites, Pinned, Today in both layouts) does, which is
  why the same `moveTab(_:onto:)` serves the sidebar and the strip.
- **`xcodebuild test` runs inside the app**, so a test must not post
  `willTerminateNotification`: every store in the host would save. The
  store's `save()` is internal instead.
- **`#expect` can't hold a mutating call** on a captured value; the result
  goes in a `let` first.
- **A locked screen looks like a hang**: the process idles with zero
  windows and empty stderr. `ioreg`'s `CGSSessionScreenIsLocked` is the
  tell; `CGSessionCopyCurrentDictionary` from a script says the same.

## Decisions for the coordinator
- **Pinning puts the tab at the bottom of Pinned** (just above the Clear
  line), the shortest move from Today; Arc does the same for ⌘D.
- **Delete Folder returns its tabs to Today** rather than closing them,
  so nothing is lost by accident.
- **Private windows can't pin** (hidden, not read-only): a private window
  that showed the user's pins would open them on the private data store,
  and pins made there would vanish with the window either way.
- **`SavedWindow.activeTabIndex` still indexes Today.** If a pinned tab
  was active at quit, the first Today tab is selected on relaunch; pins
  restore asleep regardless. Worth a `activePinID` when Spaces touch the
  session format.
- **Favorites tiles are 30–40pt** per the brief (6–10 per row), smaller
  than Arc's four-up tiles; a one-line change in `ChromeMetrics` if the
  larger look is wanted.

## Deferred
- Live verification and screenshots (above).
- Peek (5f) for links opened from Favorites and Pinned.
- Multi-window: pins reconcile across windows, but which window's recorded
  tab state wins is last-writer; fine until Spaces give each window a
  space.
