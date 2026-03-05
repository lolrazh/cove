# Vayu — The Browser That Breathes

*Sanskrit: वायु — God of Wind. Swift, invisible, essential.*

## Vision
A lightweight, native macOS browser. No AI. No Liquid Glass. Safari's speed. Dia's aesthetics.

## MVP Scope

| Feature | Status |
|---|---|
| Single WKWebView + project scaffold | DONE |
| URL bar + navigation (back/forward/reload) | DONE |
| Tab model + horizontal tab strip | TODO |
| Vertical sidebar tabs + toggle | TODO |
| History persistence (SQLite) + search | TODO |
| UI polish pass (Dia-level clean) | TODO |

## Design Spec
- **Color scheme**: System-adaptive (follows macOS light/dark)
- **Tab layouts**: Horizontal top tabs + vertical sidebar, user-switchable
- **URL bar**: Auto-hide on scroll, smart input (URL vs search)
- **Search engine**: Google (default)
- **Aesthetic**: Clean, minimal, immersive. Chrome disappears. Sites feel like apps.
- **Anti-goals**: No Liquid Glass, no AI features, no bloat

## Technical Spec
- **Engine**: WKWebView (WebKit — same as Safari)
- **UI**: SwiftUI + AppKit hybrid, custom window chrome
- **Target**: macOS 26 (Tahoe), `UIDesignRequiresCompatibility = YES`
- **Dependencies**: Zero — pure Swift + Apple frameworks
- **Storage**: SQLite for history/bookmarks (no CoreData)
- **Swift version**: 6.0
- **Build tool**: xcodegen (`project.yml` → `.xcodeproj`)

## Architecture
```
Vayu/Sources/
├── App/           # Entry point, AppDelegate
├── Browser/       # WebViewModel, WebViewRepresentable
└── UI/            # BrowserView, NavigationBar, (tabs, sidebar)
```

## Post-MVP Roadmap
- Content/ad/tracker blocking (WKContentRuleList)
- Bookmarks
- WebExtensions compatibility layer
- Downloads manager
- Settings/preferences UI
- Windows port (WebView2)
