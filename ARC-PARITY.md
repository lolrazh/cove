# Arc Parity

An audit of Cove against Arc (as last shipped, before The Browser Company moved
to Dia), and the plan to close the gap. Cove keeps what it does better (WebKit,
native window chrome, top tabs, built-in blocking) and takes Arc's layout,
feel and features.

Audited 2026-10-26 against `804ca0d`, by reading all of `Cove/Sources` and
screenshotting the running app in every tab mode. Arc measurements are
approximate.

---

## Workstreams

Each workstream is one agent and one or more PRs. Order matters where noted.

| # | Workstream | Branch | Runs | Depends on |
|---|---|---|---|---|
| 1 | Bug fixes | `main` (small direct commits) | now | — |
| 2 | Layout | `arc-layout` | now | — |
| 3 | Command Bar | `command-bar` | now | — |
| 4 | Look and feel | `arc-look` | after 2 | 2 |
| 5+ | Features (split below) | one branch per feature group | after 4 | 2, 3, 4 |

---

## 1. Bugs

- [x] **Links from other apps open a new window each.** Opening three URLs gave
      four windows; the original stayed on the start page. `WindowGroup`
      creates a scene per external event. Route them to the existing window
      (`handlesExternalEvents`) and keep `ExternalURLRouter` as the one path.
- [x] **`<input type=file>` does nothing.** No `runOpenPanelWith` in the
      `WKUIDelegate` (`TabSession.swift`).
- [x] **`alert`, `confirm` and `prompt` are silently dropped.** No JavaScript
      panel delegate methods.
- [x] **Failed loads show a blank page.** `didFail` and
      `didFailProvisionalNavigation` are empty. Show an error page with Retry,
      and ignore cancellations (`NSURLErrorCancelled`, frame-load-interrupted).
- [x] **No HTTP authentication.** No `didReceive challenge` handling, so sites
      behind basic or digest auth can't be opened.
- [x] **Tabs are lost on quit.** No session restore.
- [x] **The address field stays highlighted after navigation** (visible in
      every screenshot): the URL is drawn selected when the field isn't being
      edited.
- [x] **Web Inspector is unavailable.** `isInspectable` is never set; add
      Develop › Show Web Inspector. *(Done as Inspect Element in the page's
      context menu; WebKit has no public API to open the inspector from a
      menu.)*
- [x] **Site permissions fall back to WebKit defaults.** Camera, microphone and
      geolocation need explicit, per-site prompts.
- [x] **`example.com` pages record an empty title in history.** The title isn't
      known at `didFinish`; update the visit when the title arrives.
- [x] **History opens pages in the frontmost browser window** even when
      History was opened from another window.

---

## 2. Layout

### Arc's sidebar, replicated

```
┌──────────────┬───────────────────────┐
│●●●  ◧  ← → ↻ │                       │  header row: traffic lights, sidebar
│ [ github.com ]│                       │  toggle, back, forward, reload
│ ▢ ▢ ▢ ▢      │                       │  URL pill: domain only; click opens the
│ ▢ ▢ ▢ ▢      │   page card,          │  Command Bar with the full URL
│── Pinned ────│   no toolbar          │  Favorites: grid of large tiles
│ ▣ tab        │                       │  Pinned tabs
│── ↓ Clear ───│                       │  divider with Clear (closes Today tabs)
│ + New Tab    │                       │  Today: New Tab row on top, newest first
│ ▣ tab        │                       │
│ ♪ media      │                       │  media player when audio plays
│ ⊞    • • ○  +│                       │  footer: Library · spaces · new space
└──────────────┴───────────────────────┘
```

- [x] **Navigation controls move into the sidebar header**, right of the
      traffic lights: sidebar toggle, back, forward, reload/stop.
- [x] **URL pill at the top of the sidebar.** Shows the domain only (with the
      site-controls/lock glyph). Clicking it, or ⌘L, edits the full URL.
- [x] **No toolbar above the page in sidebar mode.** The page card holds the
      page only. The downloads button moves to the sidebar footer.
- [x] **Sections:** Favorites grid, Pinned, a divider with **Clear**, Today.
      Layout only here, fed by empty TabManager collections; pinning lands
      with 5d and drop zones with drag to reorder in 5a.
- [x] **New Tab row at the top of Today.** New tabs appear at the top of Today.
- [x] **Footer:** Library/Downloads (leading), space dots (center), new space
      (trailing, arrives with Spaces).
- [x] **Resizable sidebar:** drag the trailing edge, 220–400pt (the header's
      controls need the room beside the traffic lights), remembered.
- [x] **Page card inset about 8pt** from the window edges, like Arc (Cove: 6).
- [x] **Hidden sidebar shows no chrome at all.** The floating sidebar carries
      the controls and the URL pill when revealed.
- [x] **Top tabs stay.** Keep the navigation bar in the card for top-tab mode
      only. Revealing hidden top tabs should float over the page, like the
      hidden sidebar, instead of pushing it down.

---

## 3. Command Bar

Arc's signature: ⌘T and ⌘L open one floating palette instead of a new-tab page.

- [x] Centered floating panel over the page, with a large search field and a
      results list. Escape or a click outside dismisses it.
- [x] **⌘T** opens it empty; Return opens the result in a new tab.
- [x] **⌘L** (and clicking the URL pill) opens it prefilled with the current
      URL, selected; Return navigates the current tab.
- [x] Results, ranked and grouped: switch to an open tab, history (FTS5),
      search suggestions from the selected engine, a direct URL, and commands
      (e.g. "Copy URL", "Toggle Sidebar", "Reopen Closed Tab", "Settings").
- [x] Keyboard: ↑/↓ moves, Return opens, Tab completes the top match,
      ⌘Return opens in a new tab.
- [x] Inline autocomplete of the top history match in the field.
- [x] Favicons for tabs and history; SF Symbols for commands.
- [x] Replaces the start page in sidebar mode; the start page stays an option
      in Settings.

---

## 4. Look and feel

- [x] **Theme color.** An optional tint for the frame (window background
      behind the card), default system gray. Per-space later. Subtle, never
      full-window glass. *(`ChromeTheme`, a value read from the environment;
      Settings › Appearance has swatches and a custom color.)*
- [x] **Page card shadow**: soft elevation like Arc's floating page, no
      outline.
- [x] **Thin progress indicator** (about 2pt) instead of the system progress
      bar 8pt into the page, or Arc's shimmer on the active tab. *(A 2pt line
      along the page's top edge, so it shows in every tab mode.)*
- [x] **Link hover preview**: the hovered link's URL in the bottom-leading
      corner of the page.
- [x] **Copy URL toast** (⌘⇧C): "Copied URL" capsule that fades out.
- [x] **Motion:** sidebar slide with a spring, tab close "poof", space switch
      paging, Command Bar scale-and-fade in. Respect Reduce Motion. *(Space
      paging arrives with Spaces, 5e.)*
- [x] **Start page polish:** remove the thin "Cove" title or give it intent;
      tiles without a favicon need a better fallback than a letter.
- [x] **Active sidebar tab** matches Arc: raised, slightly lighter than the
      frame in dark mode.
- [x] **Settings window restyle**, consistent with the chrome.

---

## 5. Features

Grouped by agent. ⭑ marks the more complex groups, which need the stronger model.

### 5a. Tab basics
- [x] Switch tabs: ⌃Tab / ⌃⇧Tab, ⌘1–8, ⌘9 for the last tab. *(In the order
      tabs are shown, so the sidebar's newest-first Today counts from the
      top.)*
- [x] Drag to reorder (top strip and sidebar), and between sections.
      *(Within a list. Drops into Pinned and Favorites come with 5d, on the
      same drag type.)*
- [x] Tab context menu: Pin, Duplicate, Rename, Copy Link, Mute, Close, Close
      Others, Close Below. *(Pin comes with 5d; the Tab menu has the same
      actions for the active tab.)*
- [x] Rename a tab (double-click); the custom title persists.
- [x] Audio indicator and mute button on tabs.
- [x] ⌘S toggles the sidebar; ⌘⇧C copies the URL.

### 5b. Page tools
- [ ] Find in page (⌘F, ⌘G, ⌘⇧G), a find bar in the card.
- [ ] Zoom: ⌘+, ⌘−, ⌘0, remembered per site.
- [ ] Print (⌘P), Save Page As, View Source.
- [ ] Picture in Picture for the playing video.

### 5c. Session and memory ⭑
- [x] Restore windows and tabs (with back/forward history via
      `interactionState`) on relaunch. *(Done with the bug fixes:
      `SessionStore`.)*
- [ ] Sleep background tabs after inactivity: release the `WKWebView`, keep
      title, favicon, URL and interaction state; wake on select.
- [ ] Auto-archive Today tabs after 12h / 24h / 7d / 30d (setting); the
      archive is searchable in the Library and the Command Bar.

### 5d. Pinned tabs and Favorites ⭑
- [ ] Pin a tab (⌘D): moves to Pinned, persists across launches.
- [ ] Pinned tabs remember their pinned URL; navigating away shows a "back to
      pinned URL" affordance; closing a pinned tab resets it.
- [ ] Favorites: a grid of icon tiles above Pinned; drag in and out.
- [ ] Folders in the sidebar, nestable, collapsible.

### 5e. Spaces and profiles ⭑
- [ ] Spaces: each has a name, icon, theme color, its own Pinned and Today.
- [ ] Switch spaces: footer dots, two-finger horizontal swipe on the sidebar,
      ⌃1–9 / ⌘⌥← →.
- [ ] Profiles: separate `WKWebsiteDataStore` per profile; a space belongs to a
      profile.
- [ ] Air Traffic Control: rules that route external links to a space.

### 5f. Peek, Little Arc, Split View ⭑
- [ ] Little Arc: links from other apps open in a small floating window with
      "Open in Cove" to move the page into the main window (setting).
- [ ] Peek: links opened from Favorites and Pinned tabs on another site open
      in an overlay card; expand to a full tab.
- [ ] Split View: up to four tabs side by side, resizable, ⌃⇧=; split tabs
      show as one entry in the sidebar.

### 5g. Library, bookmarks, downloads
- [ ] Library panel: Downloads, Archive, History, in the sidebar footer.
- [ ] Bookmarks via Pinned/Favorites/folders (Arc's model), plus import from
      Safari and Chrome.
- [ ] Downloads also show progress in the sidebar footer.

### 5h. Media
- [ ] Media player in the sidebar when a background tab plays audio or video:
      title, site, play/pause, skip, open the tab.

### 5i. Site controls
- [ ] Per-site menu from the URL pill: permissions, content blocking on/off,
      zoom, clear site data, connection security.
- [ ] Private window (non-persistent data store).

### 5j. Boosts ⭑
- [ ] Per-site custom CSS (and optionally JS) via `WKUserScript`, toggleable,
      edited in a small panel. Zap mode: click elements to hide them.

### 5k. Extensions ⭑
- [ ] WebExtensions per PRODUCT.md Phase 3. Large; scheduled last.

### 5l. Easels, Notes, Capture ⭑
Big, self-contained builds; scheduled after the core features.
- [ ] Capture (⌘⇧2): select a region or element of the page; copy, save, or
      send it to a Note or an Easel.
- [ ] Notes: rich-text notes that live in the sidebar like tabs, pinnable.
- [ ] Easels: a freeform canvas of text, images, drawings and live web
      clippings (a selected page region that stays live).

### Later: AI that stays out of the way
At the very end of the roadmap, and only the kind that works quietly in the
background. The model is undecided (Apple's on-device models are an option but
weak); pick one before starting.
- [ ] Link previews: hold Shift over a link for a short summary.
- [ ] Tidy tab titles: shorten long page titles.
- [ ] Tidy downloads: rename downloaded files sensibly.
- [ ] Ask on Page: ask a question about the current page.

### Not replicated
- Chatbots: no ChatGPT in the Command Bar, no chat panels.

---

## Where Cove already beats Arc
- WebKit: a fraction of Chromium's memory and battery.
- Native macOS 27 window chrome and concentric corners throughout.
- Top tabs and sidebar tabs in one browser, with animated switching.
- Built-in content blocking (27.5k EasyList rules).
- Favicons adapt to light and dark mode; native History window.
- About 4,800 lines, zero dependencies.
