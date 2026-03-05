# Vayu — The Browser That Breathes

*Sanskrit: वायु — God of Wind. Swift, invisible, essential.*

---

## Why Vayu Exists

Every browser today is broken in some way:

- **Dia** — Beautiful UI, great feel, but bloated with AI features nobody asked for, and absurdly memory-intensive (Chromium).
- **Safari** — Fast and private, but Apple forced Liquid Glass on it. No extension ecosystem worth a damn.
- **Orion** — Tried to be Safari + extensions. Bad design, tacky, too much Liquid Glass.
- **Zen** — Tacky. Bad sidebar. Overdesigned.
- **Brave** — Crypto nonsense, cluttered UI.
- **Comet / Atlas** — Tried and hated.
- **Helium** — Chromium = too heavy. Not even worth trying.

Vayu is the browser that should exist: **Dia's skin, Safari's soul, zero bullshit.**

---

## Core Philosophy

1. **A browser browses.** No AI copilots, no summaries, no suggestions, no "smart" anything. The browser renders web pages. That's it.
2. **No Liquid Glass.** Custom-drawn UI with full design control. We explicitly opt out of Apple's Liquid Glass via `UIDesignRequiresCompatibility`.
3. **Safari's engine.** WKWebView gives us WebKit — same renderer, same JS engine, same battery efficiency. 2-4x less memory than Chromium.
4. **Dia's aesthetic.** Super clean and minimal. The chrome disappears. Sites feel like apps. Address bar and nav buttons on top keep the essentials. Professional, not tacky.
5. **Zero bloat.** No dependencies. Pure Swift + Apple frameworks. No npm, no Electron, no web tech in the shell.

---

## MVP Scope

| # | Feature | Status |
|---|---|---|
| 1 | Xcode project scaffold + WKWebView loads a page | DONE |
| 2 | URL bar + navigation (back/forward/reload) | DONE |
| 3 | Tab model + horizontal tab strip | DONE |
| 4 | Vertical sidebar tabs + layout toggle | TODO |
| 5 | History persistence (SQLite) + search | TODO |
| 6 | UI polish pass (Dia-level clean/minimal) | TODO |

Content/ad blocking is **not** in the MVP — tabled for post-MVP.

---

## Design Spec

### Aesthetic Direction
- **Inspiration**: Dia browser — the cleanest, most minimal browser UI that exists today.
- **What we love about Dia**: The disappearing sidebar makes sites feel immersive, like apps. The address bar and nav buttons stay on top for essentials. It feels professional and delightful. Just clean.
- **What we hate about Dia**: AI features everywhere (copilot, summaries, suggestions). Insane memory usage because Chromium.

### Color Scheme
- **System-adaptive** — follows macOS light/dark mode automatically.
- No custom color theming in MVP. Just respect the system.

### Tab Layouts
- **Both** horizontal top tabs AND vertical sidebar tabs, **user-switchable**.
- Horizontal tabs are the default.
- Vertical sidebar should auto-hide to maximize content space (Dia-style immersive).

### URL Bar
- **Auto-hide on scroll** — slides away when scrolling down, reappears on scroll up. More immersive.
- **Smart input** — typing a URL (e.g. `github.com`) navigates directly. Typing text (e.g. `swift wkwebview docs`) does a Google search.
- Minimal style — not chunky, not Chrome-like.

### Navigation Controls
- Back / Forward / Reload buttons, left of URL bar.
- Small, clean, icon-only. Disabled state when not applicable.
- Reload becomes Stop (X) while loading.

### Progress Indicator
- Thin linear progress bar below the nav bar during page loads.

### Anti-Goals
- No Liquid Glass. Anywhere. Ever.
- No AI features. No copilot. No summaries. No suggestions.
- No tacky design (no Zen, no Brave shields, no crypto).
- No bloated sidebar with "spaces" or "profiles" in MVP.

---

## Technical Spec

### Engine
- **WKWebView** (WebKit) — Apple's native web renderer. Same engine as Safari.
- ~15-30MB per tab (vs Chromium's ~80-150MB). 20-30% better battery life than Chromium.
- Automatic performance improvements when macOS updates Safari/WebKit.
- Shared `WKProcessPool` across tabs (saves memory, slightly less crash isolation).

### UI Layer
- **SwiftUI** for all chrome (tabs, URL bar, sidebar, settings).
- **AppKit** (`NSWindow`, `NSApplicationDelegateAdaptor`) for window-level control — custom titlebar, no system chrome.
- `windowStyle(.hiddenTitleBar)` + `titlebarAppearsTransparent` for full control.

### Platform
- **macOS 26 (Tahoe)** — minimum deployment target is macOS 15.0 for broader compat, but developed/tested on Tahoe.
- `UIDesignRequiresCompatibility = YES` in Info.plist to disable Liquid Glass.

### Dependencies
- **Zero.** Pure Swift + Apple frameworks (SwiftUI, AppKit, WebKit, SQLite via C API or Swift wrappers).
- No SPM packages. No CocoaPods. No Carthage. No third-party anything.

### Storage
- **SQLite** for history and bookmarks. Not CoreData — too heavyweight and magical.
- FTS5 (full-text search) for history search.

### Build System
- **xcodegen** — project defined in `project.yml`, generates `.xcodeproj`.
- Run `xcodegen generate` to regenerate after changing project structure.
- Swift 6.0, `@MainActor` isolation for all UI/browser code.

### Entitlements
- App Sandbox enabled.
- `com.apple.security.network.client` — outgoing network access for WKWebView.

---

## Architecture

```
Vayu/
├── project.yml                    # xcodegen spec → generates .xcodeproj
├── PRODUCT.md                     # this file
├── Vayu.xcodeproj/                # generated, don't edit by hand
├── Vayu/
│   ├── Sources/
│   │   ├── App/
│   │   │   ├── VayuApp.swift              # @main, WindowGroup, hiddenTitleBar
│   │   │   └── AppDelegate.swift          # NSWindow config, anti-Liquid Glass
│   │   ├── Browser/
│   │   │   ├── WebViewModel.swift         # ObservableObject wrapping WKWebView
│   │   │   ├── WebViewRepresentable.swift # NSViewRepresentable for WKWebView
│   │   │   ├── Tab.swift                  # Tab model (ID + WebViewModel)
│   │   │   └── TabManager.swift           # Tab lifecycle (add/close/switch)
│   │   └── UI/
│   │       ├── BrowserView.swift          # Main view composing everything
│   │       ├── NavigationBar.swift        # URL bar + back/forward/reload
│   │       └── TabStripView.swift         # Horizontal tab strip
│   └── Resources/
│       ├── Info.plist                     # UIDesignRequiresCompatibility = YES
│       └── Vayu.entitlements              # Sandbox + network
```

### Key Classes
- **`WebViewModel`** — owns a `WKWebView`, publishes reactive state (currentURL, pageTitle, canGoBack, canGoForward, isLoading, estimatedProgress). Handles URL parsing (URL vs search query). One per tab.
- **`Tab`** — thin wrapper: UUID + WebViewModel. Each tab is independent.
- **`TabManager`** — array of Tabs, tracks active tab, handles add/close/switch. Always keeps at least one tab.
- **`NavigationBar`** — URL text field + nav buttons. Binds to active tab's WebViewModel.
- **`TabStripView`** — horizontal scrollable tab bar. Shows page titles, close buttons on hover, + button for new tab.
- **`BrowserView`** — top-level composition: TabStrip → NavigationBar → ProgressBar → WebView.

---

## Post-MVP Roadmap

In rough priority order:

### Phase 2 — Essential Features
- **Content blocking** — native ad/tracker blocking via `WKContentRuleList` (JSON rules, no extension needed). Aggressive by default: ads, trackers, cookie banners, social widgets.
- **Bookmarks** — SQLite-backed, simple UI. Import from Safari/Chrome.
- **Downloads** — `WKDownload` delegate, download progress UI, configurable download location.
- **Settings/Preferences** — SwiftUI settings pane. Search engine picker, default download path, privacy toggles.
- **Keyboard shortcuts** — Cmd+T (new tab), Cmd+W (close tab), Cmd+L (focus URL bar), Cmd+[ / Cmd+] (back/forward), etc.

### Phase 3 — WebExtensions
The big lift. A compatibility layer that lets Chrome/Firefox extensions run in Vayu.

- **Extension runtime** — JavaScriptCore for background scripts, WKUserScript for content scripts, WKWebView popover for popup UIs.
- **Tier 1 APIs** (covers ~80% of extensions): `tabs`, `runtime`, `storage`, `webRequest`, `scripting`, `action`, `contextMenus`, `permissions`, `cookies`, `i18n`.
- **Tier 2 APIs** (next ~15%): `alarms`, `notifications`, `windows`, `bookmarks`, `history`, `downloads`, `commands`, `management`.
- **Target extensions**: uBlock Origin, Bitwarden/1Password, Dark Reader, Vimium, SponsorBlock, Stylus.
- Manifest V3 first (simpler, future-proof). V2 support later if needed.

### Phase 4 — Polish & Platform
- **Tab groups** — group related tabs, collapse/expand.
- **Profiles** — separate cookie jars, bookmarks, history per profile.
- **Sync** — iCloud or custom sync for bookmarks/history across devices.
- **Windows port** — WinUI 3 + WebView2 (Chromium) backend. Same chrome layer, different renderer.

---

## Performance Targets

| Metric | Target | Rationale |
|---|---|---|
| Memory per tab | ~15-30MB | WKWebView baseline, 2-4x better than Chromium |
| Cold start | < 500ms | Native app, no web runtime to boot |
| New tab | < 100ms | WKWebView instance creation ~50ms after first |
| Battery | Safari-tier | Same WebKit engine, same efficiency |

---

## What Vayu Is NOT

- Not a Chromium wrapper (no Electron, no CEF, no WebView2 on macOS)
- Not an "AI browser" — no copilot, no summaries, no suggestions, no LLM anything
- Not a "productivity browser" — no built-in todos, notes, or calendar
- Not a crypto browser — no wallet, no Web3, no tokens
- Not a social browser — no built-in messaging, no feed reader
- It's a browser. It browses. Fast, private, beautiful, done.
