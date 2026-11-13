# Dia download flight: live reference

Date: 2026-11-14. Branch: `main`.

The user approved a physical mouse-event helper restricted to Virtual 16:9.
The helper checked the named display, Dia bundle ID, window ID, exact window
frame, and existing event permission before clicking. It focused the virtual
test window and clicked its local Slow file link. It did not change permissions.

This produced the full flying card that earlier computer-use clicks did not.
Capture: `build/download-motion-study/live/dia-physical-click.mov`.
The recording includes separate native windows within the browser's display crop.
Dia test window: 10302, `(2142, 206, 756, 614)` pt, virtual display 5, scale 2.

## Observations

Source click: `(306, 265)` pt relative to the window. Target: about `(167, 27)` pt.
The card appears below the click, dips farther down, tilts counterclockwise, then
accelerates upward. It stays close to full size through the dip and starts fading
during its last sweep. It does not shrink to a tiny, opaque icon before fading.

| Recording time | Card center, pt | Width, pt | Tilt |
| --- | --- | --- | --- |
| 12.683 s | 305, 289 | 228 | -0.8° |
| 12.733 s | 301, 303 | 233 | -3.3° |
| 12.783 s | 297, 306 | 224 | -6.0° |
| 12.867 s | 271, 277 | 218 | -3.7° |
| 12.933 s | about 218, 155 | about 193 | near level |
| 12.983 s | about 173, 43 | about 100 | near level, almost transparent |
| 13.050 s | absent | — | — |

First four rows use a dark-neutral connected-component mask and principal-axis
measurement. Last two are visual bounds because transparency joins the page
content. Rotation can bias the measured height. The base size remains 220 × 36 pt
from the prior static trace. The visible flight is approximately 350 ms; sampled
timestamps leave about 50 ms uncertainty at the endpoints. This is a fitted visual
reference, not a recovered animation function or a claim of 60 fps capture.

The capture has a brief solid dark native-window frame before the card renders.
Do not copy this capture/render artifact into Cove. A second attempt began with a
reference popover open and did not establish another flight; it is not a repeat
measurement. No app flags or animation counters were changed.

The live card uses a download-arrow ring before the file is ready. Pause/cancel
controls can become visible while the pointer overlaps it. Cove's flight overlay
is passive, so decorative controls that cannot be clicked will not be added.

Analysis files in the same local evidence directory: `dia-flight-frames.png`,
`dia-frame-times.txt`, `dia-measurements.json`, `measure.py`, and
`click-dia-virtual.swift`. These are ordinary capture/measurement evidence, not
REA tool output. Prior static findings remain in `card-addendum.md` one level up.
