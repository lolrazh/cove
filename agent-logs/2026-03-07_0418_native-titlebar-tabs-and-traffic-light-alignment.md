# Cove Browser — Native Titlebar Tabs & Traffic Light Alignment Session

**Date:** 2026-03-07
**Agent:** GPT-5.4
**Status:** ✅ Completed

## User Intention
User wanted Cove's top chrome to stop feeling like a clever approximation and start feeling like a real native macOS browser shell. The deeper goal was to keep real Apple traffic lights, avoid fake custom dots, make the relationship between the left window edge, the traffic lights, and the first tab feel balanced like apps such as Cursor, Ghostty, and Dia, and preserve that result with meaningful milestone commits. The user also wanted the solution to be architecturally correct rather than another pile of isolated spacing hacks.

## What We Accomplished
- ✅ **Landed a clean native control centerline fix** — corrected the native traffic-light Y alignment so the buttons target the same top strip centerline as the tab lane
- ✅ **Investigated how Electron/Chromium/native apps handle traffic lights** — confirmed that many "better proportioned" apps still use native macOS controls, but with richer titlebar/window APIs than plain SwiftUI/AppKit exposes publicly
- ✅ **Rejected the fake-controls path after validating user preference** — rolled back custom/fake traffic-light experiments and recommitted to real Apple `standardWindowButton` controls
- ✅ **Gave Cove a real AppKit titlebar/toolbar host** — added a true native toolbar/titlebar environment so the traffic lights are no longer living inside a purely synthetic shell context
- ✅ **Moved top tabs into a native titlebar accessory** — hosted the top tab strip in `NSTitlebarAccessoryViewController` so AppKit owns the lane beside the real traffic lights
- ✅ **Kept the browser shell intact under the titlebar** — preserved the Dia-style shell/content hierarchy while removing the fake SwiftUI ownership of the top tab lane
- ✅ **Synchronized the left titlebar lane across both native systems** — unified the traffic-light inset and the accessory-hosted first-tab offset under one shared token
- ✅ **Increased the native left titlebar inset after synchronization** — pushed the whole left titlebar composition right in a controlled way once the two systems were numerically linked
- ✅ **Validated each milestone in the running app** — rebuilt and relaunched after the host pass, the accessory pass, the synchronized inset pass, and the final inset increase
- ✅ **Preserved a clean commit trail for the native titlebar transition** — kept the work broken into native-host, native-accessory, synchronized-inset, and increased-inset checkpoints

## Technical Implementation

### Native Control Alignment Baseline
- Refactored native traffic-light placement so the buttons align to the top strip centerline instead of the titlebar container center
- Replaced the older `bandHeight` heuristic with an explicit top-anchored centerline model
- Relevant files:
  - `Cove/Sources/UI/BrowserView.swift`
  - `Cove/Sources/UI/Foundation/ChromeTokens.swift`
  - `Cove/Sources/UI/Foundation/WindowChromeAccessor.swift`
  - `Cove/Sources/UI/WindowChromeHost.swift`
- Commit:
  - `2681513` `refactor: align native controls to the strip centerline`

### Real AppKit Titlebar Host
- Updated `Cove/Sources/App/AppDelegate.swift` to give each window:
  - `.fullSizeContentView`
  - `.unifiedTitleAndToolbar`
  - a real `NSToolbar`
  - `toolbarStyle = .unifiedCompact`
- Updated `Cove/Sources/App/CoveApp.swift` to opt into `.windowToolbarStyle(.unifiedCompact)`
- This established a real native titlebar host before moving any top-strip content into AppKit-managed regions
- Commit:
  - `8d78bff` `refactor: give Cove a native titlebar host`

### Native Titlebar Tabs
- Added `Cove/Sources/UI/TitlebarTabStripAccessory.swift` as a native bridge that:
  - creates an `NSTitlebarAccessoryViewController`
  - hosts SwiftUI tab content in an `NSHostingView`
  - installs it on the left side of the titlebar beside the native traffic lights
  - resizes it as the window changes
  - hides/shows it with top-mode tab visibility
- Updated `Cove/Sources/UI/BrowserView.swift` to install the accessory only for top-mode tabs
- Updated `Cove/Sources/UI/TopBrowserShellView.swift` so the shell strip becomes the shell's visual band instead of owning the tabs directly
- Updated `Cove.xcodeproj/project.pbxproj` to include the new file in the target
- Commit:
  - `31908fc` `refactor: host top tabs in the native titlebar`

### Left Lane Synchronization
- Added `shellControlsEdgeBalanceInset` in `Cove/Sources/UI/Foundation/ChromeTokens.swift`
- Fed that token into:
  - `shellControlsLeadingInset` for native traffic-light positioning
  - `shellControlsReservedWidth` for the accessory width math
  - accessory-hosted tab leading padding in `Cove/Sources/UI/TitlebarTabStripAccessory.swift`
- This stopped left-edge tweaks from moving only the buttons or only the first tab
- Commits:
  - `b299e1f` `refactor: synchronize the native left tab lane inset`
  - `ab88f62` `refactor: increase the native left titlebar inset`

**Files Modified/Created:**
- `Cove/Sources/App/AppDelegate.swift`
- `Cove/Sources/App/CoveApp.swift`
- `Cove/Sources/UI/BrowserView.swift`
- `Cove/Sources/UI/TopBrowserShellView.swift`
- `Cove/Sources/UI/WindowChromeHost.swift`
- `Cove/Sources/UI/Foundation/ChromeTokens.swift`
- `Cove/Sources/UI/Foundation/WindowChromeAccessor.swift`
- `Cove/Sources/UI/TitlebarTabStripAccessory.swift`
- `Cove.xcodeproj/project.pbxproj`

## Bugs & Issues Encountered
1. **Native traffic lights were still misaligned even after earlier shell cleanup**
   - **Root cause:** native buttons were being solved against the titlebar container center rather than the shell's top strip centerline
   - **Fix:** changed the native button math to target the shared strip centerline and committed it as `2681513`

2. **Trying to make native traffic lights bigger led to unstable or inauthentic results**
   - **Root cause:** public AppKit lets us move `standardWindowButton` controls, but it does not expose a clean "larger native traffic lights" primitive; scaling/faking controls changed the look and geometry in ways the user rejected
   - **Fix:** rolled back the fake/custom traffic-light branch and recommitted to real Apple controls only

3. **The titlebar host looked better, but tabs were still effectively in a separate synthetic lane**
   - **Root cause:** even with a real toolbar/titlebar environment, the SwiftUI shell still owned the top tabs instead of AppKit's native titlebar area
   - **Fix:** moved the top tab strip into a real `NSTitlebarAccessoryViewController` hosted beside the native traffic lights

4. **The first left-inset tweak moved the perceived balance the wrong way**
   - **Root cause:** the native traffic lights were positioned by `WindowChromeAccessor`, while the first tab lived inside `TitlebarTabStripAccessory`; changing only the traffic-light leading inset did not move the whole left titlebar lane together
   - **Fix:** added a shared edge-balance token and applied it to both the native controls and the accessory-hosted tab start

5. **The first titlebar accessory pass failed under Swift 6 actor isolation**
   - **Root cause:** AppKit view controller/window mutations were being made from nonisolated contexts and Sendable notification closures
   - **Fix:** made the accessory bridge `@MainActor` and switched resize handling to selector-based AppKit notifications

6. **Changing `.unifiedCompact` to `.unified` did not solve the user's actual left-edge complaint**
   - **Root cause:** toolbar style changes affect the native host chrome, but the specific mismatch the user cared about was between manual native button positioning and the accessory tab start
   - **Fix:** reverted the toolbar style experiment and tuned the synchronized left-lane token instead

## Key Learnings
- **Real Apple traffic lights and native titlebar accessories are two separate public AppKit systems** — they can be made to feel unified, but AppKit does not hand us a single public layout container that owns both
- **Electron/Chromium often look better because they have more window-frame leverage** — many of those apps still use native traffic lights, but they get richer positioning APIs or deeper frame hooks than stock SwiftUI/AppKit exposes
- **Public AppKit does not provide a clean "bigger native traffic lights" setting** — if authenticity matters, the better path is titlebar hosting and proportion, not custom dots
- **If tabs live in a titlebar accessory, left-edge tuning must drive both sides** — moving only the buttons or only the tabs is guaranteed to feel wrong
- **A real native toolbar/titlebar host is worth having before titlebar accessories** — it gives the traffic lights a more natural environment and makes subsequent titlebar work less ad hoc
- **Fake controls are only "easy" if authenticity does not matter** — once the user made it clear the dots must stay genuinely Apple-native, the architecture had to change

## Architecture Decisions
- **Keep real Apple `standardWindowButton` traffic lights** — do not fake, redraw, or scale them
- **Keep a real AppKit titlebar/toolbar host under the SwiftUI browser shell** — the window should participate in native titlebar behavior rather than pretending the whole top lane is pure SwiftUI
- **Host top tabs in a native left titlebar accessory in top mode** — AppKit should own the titlebar tab lane beside the real traffic lights
- **Use `WindowChromeAccessor` only for native control placement/visibility** — do not expand it into a fake unified shell layout system
- **Treat the left titlebar edge as a shared lane** — the traffic-light inset and the first-tab start must come from the same tokenized model
- **Continue this work on `refactor/two-layer-browser-shell`** — this is the active branch for the native titlebar direction

## Ready for Next Session
- ✅ **Top mode now uses real Apple traffic lights** — no custom/fake dots remain in the accepted path
- ✅ **Cove has a real AppKit titlebar host** — the browser is no longer forcing native traffic lights to live in a completely synthetic top strip
- ✅ **Top tabs now live in a native titlebar accessory** — the top tab strip is hosted beside the real traffic lights in AppKit-managed titlebar space
- ✅ **Left-edge balance is tokenized across both native systems** — the traffic-light lane and first-tab start now share a synchronized inset model
- ✅ **Recent native-titlebar milestones are committed** — `8d78bff`, `31908fc`, `b299e1f`, and `ab88f62` preserve the progression cleanly
- 🔧 **Open item:** if more top-mode polish is needed, tune `shellControlsEdgeBalanceInset`, `shellControlsGapToTabs`, and accessory width math together rather than reopening fake-control ideas
- 🔧 **Open item:** decide whether sidebar mode should keep its current handling or be ported toward the same native titlebar/accessory philosophy
- 🔧 **Open item:** branch has new native-titlebar work that may need pushing/merging depending on the user's next step

## Context for Future
This session was the "keep it native" correction. The user explicitly rejected fake traffic lights and wanted Cove to feel like a real macOS browser window, not a visually convincing imitation. The biggest breakthroughs were: accepting that real traffic lights and titlebar accessories are separate AppKit systems, giving the window a real native titlebar/toolbar host, moving the top tabs into a native titlebar accessory, and then synchronizing the left edge with one shared token instead of independently nudging buttons and tabs. If a future session continues from here, the safest next move is small token-level tuning or sidebar parity work, not another attempt to fake or resize the native traffic lights.
