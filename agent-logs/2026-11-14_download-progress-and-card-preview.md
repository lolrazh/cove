# Download progress and paused card preview — 2026-11-14

## Request

Show the flying card at rest with recent file downloads, so its corners and text
can be inspected. Keep a decimal and use `25.8/258 MB · 18s`. Remove number
flicker and test size, digit, speed, and time changes.

## Changes

- Download progress is now one published snapshot: bytes, total, and ETA update
  together. One timer samples the active transfer every 250 ms. It replaces the
  per-chunk KVO tasks and separate published updates. Terminal states cancel it.
- Downloaded amounts retain one decimal in scaled units. Both amounts use the
  total's unit. Byte counts remain integers. Unknown totals keep kB and omit ETA.
- Digits use tabular widths and a reserved amount column. Text uses an identity
  content transition with animation disabled. The progress track still animates.
- ETA uses a smoothed rate, a short warm-up, and compact seconds/minutes/hours/days.
  It hides after three seconds without new bytes and returns when bytes resume.
- The native card renderer is shared with a local preview tool. Its shipping
  appearance and 350 ms flight are unchanged: 220 × 36 pt, 16 pt corners.
- The preview compares 16, 12, and 10 pt corners, dark/light appearances, and
  actual/2× sizes. It also renders progress cases with the production SwiftUI
  component. The alternatives are preview options, not app settings.
- Added a local 16 MiB fixture with a four-second stall and faster final phase.

## Evidence

Build and **202 tests in 47 suites passed**. Log: `/tmp/cove-progress-tests.log`.
Coverage includes 99.9 → 100.0, whole decimals, shared GB units, locale separators,
bytes, unknown totals, TB, 59 s → 1 min, hours/days, warm-up, rate changes, stalls,
terminal-state guards, retry resets, and one publication per coherent update.

On Virtual 16:9, the new executable completed the slow, variable-speed, and
unknown-size fixtures. AX showed `0.3/1 MB · 24s`, a variable-speed estimate
changing from `1.0/16.8 MB · 2m 9s` to `5.7/16.8 MB · 18s`, and an unknown-size
count without an ETA. All three reached completed records.

The slow-transfer capture is `build/download-motion-study/live/progress-current.mov`.
Sampled frames show stable text positions and no opacity transition. A crop is
`progress-check.mp4`; this is a sampled visual check, not proof for every frame
or every network condition. The variable-transfer recording did not cover the
progress panel and is not used as visual evidence of stall handling. Stall
hide/resume behavior is covered by deterministic estimator tests.

The local preview is `build/download-motion-study/live/card-preview/index.html`.
It uses eight recent non-image file names and sizes only; no file contents were
read and no real files were downloaded again. Private names and generated images
remain under ignored `build/`. The reusable tool is `prototypes/download-card/`.
Its corner, appearance, and zoom controls were checked in Cove on Virtual 16:9.
The preview remains open there. The fixture server and recorders were stopped;
the preview-only localhost server remains on port 8771 for review.

Commits: `04f3b1a` progress fix, `bcdc5cf` native preview tool, `e1de630` fixture.
Work remains on `main`; this log is a separate small commit.

## Selected corners and variation sheet

The user chose 12 pt corners. The flight card now uses that radius. Its shadow
path reads the card's radius, so the two cannot drift. The flight timing is
unchanged. The local preview now marks 12 pt as current and adds `cards/files.png`:
eight recent file names shown in dark and light appearances, including long-name
truncation. `cards/progress.png` shows nine progress and ETA combinations using
the production SwiftUI view. Both sheets were rendered and inspected.

The updated Debug build passed (`/tmp/cove-download-radius-build.log`). No new
unit tests were needed for the radius-only change. The previous progress run
remains 202 passing tests; the live checks and recording limits above still
apply. Private filenames and rendered sheets remain local under ignored build/.
