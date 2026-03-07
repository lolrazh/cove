# Corner Rounding Design System

**Date:** 2026-03-07
**Agent:** Claude Opus 4.6
**Status:** Completed
**Building on:** `2026-03-07_1400_traffic-light-native-ownership.md`

## User Intention
User noticed the content panel's bottom corners didn't look properly nested within the window shell — the gap between the shell border and panel border was inconsistent at the corners. They also wanted a design system improvement: a single source of truth for the rounding style so changing from `.continuous` (squircle) to `.circular` someday would be a one-variable change. After establishing the system, they iterated on radius values visually until landing on 14/10.5.

## What We Accomplished
- **Unified corner rounding design system** — `ChromeMetrics.cornerStyle` is the single source of truth for rounding style across the entire app
- **Shape factory method** — `ChromeMetrics.roundedShape(radius:)` ensures every `RoundedRectangle` uses the global style
- **Fixed nesting formula** — removed incorrect `0.65` multiplier, corrected to `outer - gap` (Apple's standard)
- **Fixed FaviconView** — was the only file missing `.continuous` style
- **Tuned radius values** — iterated through 10/10/10, 12/9/9, 14/7/7, 14/14/14, 14/10.5/10.5 — landed on 14/10.5

## Technical Implementation

### The Problem
Two issues caused visually incorrect corner nesting:

1. **Wrong nesting formula**: `max(outerRadius - (inset * 0.65), minimum: 8)` — the `0.65` multiplier made inner radii too large, so the gap between shell and panel wasn't uniform at corners. Correct formula: `inner = outer - gap`.

2. **No centralized rounding style**: `.continuous` (squircle) was hardcoded in 6 separate files. `FaviconView` was missing it entirely (defaulting to `.circular`).

### Solution
Added to `ChromeMetrics`:
- `cornerStyle: RoundedCornerStyle = .continuous` — single source of truth
- `roundedShape(radius:) -> RoundedRectangle` — factory that always applies the style

Replaced all inline `RoundedRectangle(cornerRadius:, style: .continuous)` calls with `ChromeMetrics.roundedShape(radius:)`.

Changed radius values from computed (via nesting formula) to explicit constants after iterating visually:
- `panelCornerRadius = 14` (content panel inside shell)
- `controlCornerRadius = 10.5` (buttons, interactive surfaces)
- `fieldCornerRadius = 10.5` (text fields)
- `tabCornerRadius = 10.5` (tab items)

**Files Modified:**
- `Cove/Sources/UI/Foundation/ChromeTokens.swift` — Added `cornerStyle`, `roundedShape()`, fixed nesting formula, tuned radii
- `Cove/Sources/UI/Foundation/ChromePanelSurface.swift` — 2 shapes routed through factory
- `Cove/Sources/UI/Foundation/ChromeButtonStyle.swift` — 1 shape routed through factory
- `Cove/Sources/UI/Foundation/ChromeFieldStyle.swift` — 1 shape routed through factory
- `Cove/Sources/UI/FaviconView.swift` — Fixed missing `.continuous`, routed through factory
- `Cove/Sources/UI/NewTabPage.swift` — 2 shapes routed through factory

## Key Learnings

- **Apple's nested corner radius formula is simply `inner = outer - gap`.** No multiplier. The `0.65` factor was producing inner radii that were too large, breaking the visual nesting illusion at corners.

- **SwiftUI `RoundedRectangle` defaults to `.circular`, not `.continuous`.** macOS windows use continuous (superellipse/squircle) rounding. Any view using `.circular` will look subtly wrong next to the window frame. Always specify `.continuous` — or better, use a centralized factory.

- **Visual tuning beats math for corner radii.** The mathematically "correct" nested values (14/8/6) looked too sharp on inner elements. The user preferred 14/10.5 which feels balanced even if not geometrically perfect nesting. Design is about what looks right, not what calculates right.

## Architecture Decisions

- **Explicit constants over computed nesting** — After trying the formula, explicit values gave better visual results and are easier to reason about. The nesting formula is kept in code for reference but not currently used.

- **Factory method over protocol/extension** — `ChromeMetrics.roundedShape(radius:)` is simpler than a custom `Shape` wrapper or `View` extension. It returns a plain `RoundedRectangle` so it works everywhere SwiftUI expects a shape.

## Context for Future
The corner rounding design system is now centralized. To change the rounding style app-wide, edit `ChromeMetrics.cornerStyle`. To adjust any radius, edit the four constants in `ChromeTokens.swift`. All 6 files that create rounded rectangles go through the factory method.
