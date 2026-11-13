# Loading Light Lab

A standalone native SwiftUI editor for the address-bar loading light. It does
not change Cove's browser code. The selected Soft lift shape is now integrated
in `Cove/Sources/UI/PageProgressBar.swift`: upward spread 34, strength 0.19,
right spill 8.26, base brightness 0.45, curve 1.4, and line brightness 0.9.
This tool remains available for later comparisons.

## Build and open

From the repository root:

```sh
prototypes/loading-light/run.sh
open 'build/glow-study/Cove Glow Lab.app'
```

No extra packages are needed. The build uses the full Xcode developer directory.

## Use

1. Pick Soft lift, Wide wash, or Near strip.
2. Change the spread, strength, right spill, or theme color.
3. Drag the progress slider or click Replay load. The replay is a simulated load,
   not a network request or a measurement of Dia's timing.
4. Use Match color & progress for a spatial comparison with the real Dia capture.
5. Name a choice and click Save choice. Load it again to compare with another.

Choices persist in `build/glow-study/choices.json`. Copy settings puts the current
values on the clipboard. Keep the choices file before deleting build artifacts.

The preview uses a 32-point field, 28-point icon areas, 4-point gaps, a 1-point
line by default, and a continuous 8-point corner. The light is clipped to that
field. Its soft vertical falloff has no tapered top edge and draws nothing below
the strip. The right spill wraps softly around the finite strip: a small base blur
widens gently with height, and its intensity falls beyond the tip. The crisp
line still ends at the loading position. The close halo stays narrow. These values are
local prototype settings until a choice is integrated into Cove.

The reference PNG is a crop of the actual Dia Work-theme loading screenshot
captured on Virtual 16:9. It is fitted to the preview field's width and keeps its
original 36-point height (32-point field plus 4-point lower context).

The replay respects Reduce Motion. It can be stopped by changing the state,
starting another replay, or dragging the progress slider.
