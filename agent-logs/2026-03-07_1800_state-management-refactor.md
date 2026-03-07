# State Management Refactor — Single Source of Truth

**Date:** 2026-03-07
**Agent:** Claude Opus 4.6
**Status:** Completed
**Building on:** `2026-03-07_1600_corner-rounding-design-system.md`

## User Intention
User wanted the View menu commands (Show Tabs in Sidebar, Hide Tabs) to work reliably on first click. Switching between top and sidebar mode required multiple clicks — sometimes 2-3 before anything happened. They wanted a structurally sound solution, not a bandaid ("make me a better bone").

## What We Accomplished
- **Single source of truth for tab state** — TabManager owns `tabLayout`, `hideTabs`, and `areTabsVisible`. No Combine subscribers, no circular data flow.
- **Pure state machine** — TabManager has zero `withAnimation` calls. Model manages state, view layer manages presentation.
- **Reliable menu commands** — `@FocusedObject` is the only SwiftUI mechanism that triggers Commands re-evaluation. Confirmed via failed `@FocusedValue` experiment.
- **Explicit animation only** — Removed implicit `.animation(value:)` from BrowserView. All animation is via `withAnimation` at call sites.
- **Clean hover handler** — No redundant `areTabsVisible` writes when `hideTabs` is off.

## Technical Implementation

### Root Causes Found

**1. Dual source of truth with circular Combine sync**
TabManager and BrowserSettingsStore both claimed ownership of `tabLayout` and `hideTabs`. They were synced via Combine subscribers + UserDefaults notifications — a circular async loop that caused state thrashing and competing non-animated updates.

**Fix:** Removed all Combine subscribers from TabManager. TabManager reads settings on init, then owns the state. Settings is just fire-and-forget persistence.

**2. @FocusedValue struct snapshot staleness**
The original `BrowserCommandContext` struct was a snapshot published via `.focusedSceneValue`. The Toggle read stale state between re-evaluations, causing the `set` closure to fire with the wrong inverted value.

**Fix:** Switched to `@FocusedObject` with TabManager directly. Commands observe the live object.

**3. @FocusedValue doesn't trigger Commands re-evaluation**
Attempted `@FocusedValue` + `.focusedSceneValue` as an alternative (theory: more reliable than `@FocusedObject` for scene-level publishing). Result: tabManager was permanently nil because `@FocusedValue` doesn't subscribe to `objectWillChange`. Commands body never re-evaluated after initial load.

**Lesson:** `@FocusedObject` is the ONLY SwiftUI mechanism that subscribes to an ObservableObject's changes AND triggers Commands body re-evaluation. `@FocusedValue` is for passive values, not live objects.

**4. Redundant @Published writes from hover handler**
`handleChromeHover` wrote `tabManager.areTabsVisible = true` on every mouse hover event when `hideTabs` was off. `@Published` fires `objectWillChange` on every write regardless of value change. This flooded SwiftUI with re-evaluation cycles, creating timing interference with menu interactions.

**Fix:** Early return when `hideTabs` is false. No writes, no noise.

**5. Double animation contexts**
BrowserView had `.animation(ChromeMotion.shell, value: tabManager.tabLayout)` (implicit) AND menu commands wrapped in `withAnimation(ChromeMotion.shell)` (explicit). Two animation contexts on the same state change. Additionally, TabManager embedded `withAnimation` inside `revealTabs()` and `hideTabsIfNeeded()`, mixing model and presentation concerns.

**Fix:** Removed implicit `.animation` from BrowserView. Removed `withAnimation` from TabManager. Animation lives at call sites only — menu commands, hover reveal, delayed hide.

### Architecture After Refactor

```
Menu Click
  -> @FocusedObject reads TabManager (live reference, triggers re-eval)
    -> withAnimation { TabManager.setLayout() }  (caller owns animation)
      -> @Published tabLayout changes             (pure state mutation)
        -> BrowserView re-evaluates               (@StateObject observation)
          -> BrowserShellView re-evaluates         (@ObservedObject observation)
            -> Layout animates                     (from withAnimation context)

No circular flow. No async hops. No competing animations.
```

**Files Modified:**
- `Cove/Sources/Browser/TabManager.swift` — Removed Combine import/subscribers/cancellables, added `hideTabs` property, added `setHideTabs()`, removed `withAnimation` from internal methods, removed dead `apply()` method
- `Cove/Sources/App/BrowserCommands.swift` — Replaced `BrowserCommandContext` struct with `@FocusedObject TabManager`. Removed FocusedValueKey infrastructure.
- `Cove/Sources/UI/BrowserView.swift` — Removed `@ObservedObject settings`, removed `.animation(value:)`, replaced `.focusedSceneValue` with `.focusedObject`, removed command context computed property
- `Cove/Sources/UI/BrowserShellView.swift` — Replaced `settings.hideTabs` with `tabManager.hideTabs`, removed settings observation, added `withAnimation` at reveal/hide call sites, fixed `handleChromeHover` to not write when `hideTabs` is off

## Bugs & Issues Encountered

1. **Layout switch requiring multiple clicks**
   - **Root cause:** Circular Combine sync + stale FocusedValue struct
   - **Fix:** Single source of truth in TabManager + @FocusedObject

2. **Top-to-sidebar direction worse than sidebar-to-top**
   - **Root cause:** 44pt top chrome hover zone fires `handleChromeHover` as mouse reaches menu bar; 6pt zone in sidebar mode barely registers. Redundant `areTabsVisible` writes created asymmetric timing interference.
   - **Fix:** Early return in `handleChromeHover` when `hideTabs` is off

3. **@FocusedValue experiment — complete failure**
   - **Root cause:** `@FocusedValue` doesn't subscribe to `objectWillChange`. Commands body evaluated once with nil, never re-evaluated.
   - **Resolution:** Reverted to `@FocusedObject` — the only mechanism that works for live objects in Commands.

4. **withAnimation inside model methods**
   - **Root cause:** Mixing presentation (animation) with state management
   - **Fix:** Moved to call sites in BrowserShellView

## Key Learnings

- **`@FocusedObject` is the only viable mechanism for Commands + per-window ObservableObject on macOS.** `@FocusedValue` doesn't trigger re-evaluation. The SwiftUI Commands system is genuinely weak — this is a known pain point.

- **`@Published` fires `objectWillChange` on every write, even when the value doesn't change.** Always guard writes: `if areTabsVisible != newValue { areTabsVisible = newValue }`. Redundant writes create unnecessary SwiftUI re-evaluation cycles.

- **Never mix implicit `.animation(value:)` with explicit `withAnimation` on the same state.** Two animation contexts competing on the same change can cause subtle timing issues. Pick one. Explicit `withAnimation` at call sites is cleaner.

- **Models should be pure state machines.** `withAnimation` is a presentation concern — it belongs in the view layer. TabManager.setLayout() changes state; the caller wraps in `withAnimation` if they want animation.

- **Circular data flow is the root of state management hell.** A → B → notification → A creates timing-dependent behavior that's nearly impossible to debug. One source of truth, one direction of flow.

## Architecture Decisions

- **@FocusedObject over @FocusedValue** — Despite focus system quirks, it's the only mechanism that subscribes to object changes and triggers Commands re-evaluation. The alternative (@FocusedValue) was a dead end.

- **TabManager as single state owner** — Settings is persistence-only. No subscribers, no sync. TabManager reads on init, writes on change. Unidirectional.

- **Explicit animation over implicit** — `.animation(value:)` on BrowserView created a hidden animation scope over the entire tree. Explicit `withAnimation` at call sites makes animation intent clear and prevents competing contexts.

## Ready for Next Session
- **Layout switching works** on first click in both directions
- **Hide/show tabs works** reliably
- **No Combine in TabManager** — zero async, zero subscribers, zero circular flow
- **TabManager is a pure state machine** — easy to reason about, easy to test

## Context for Future
The SwiftUI Commands system on macOS has known limitations. `@FocusedObject` is the least-bad option for bridging per-window state to menu commands. If menu reliability becomes an issue again, the nuclear option is AppKit's responder chain (NSMenuItem + target/action), which is battle-tested but requires bridging out of SwiftUI.

The state architecture is now clean: TabManager owns all runtime state, Settings is persistence, views observe TabManager, Commands access TabManager via @FocusedObject. Any future state should follow this pattern — one owner, unidirectional flow.
