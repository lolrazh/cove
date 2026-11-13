# Download card and number correction

Date: 2026-11-14 (Asia/Kolkata). Branch: `main`.

## Request and correction

The user rejected the first download flight. It used a faint file icon and took
620 ms. The first binary trace did not establish what the flying view contained.
That was insufficient evidence for the implementation. This entry supersedes the
flight and number-format choices in `2026-11-14_download-motion-and-session-indicator.md`.

- Show at most one decimal, without trailing zeros: `0.1 of 2.1 GB`, then
  `1 of 2.1 GB`. Select one unit from the total and use it for both numbers.
- Keep tabular digits and a reserved number column. Use the same formatter for
  accessibility and completed downloads. Tests cover GB and decimal-comma locales.
- Replace the icon with a 220 × 36 pt card: a 20 pt file icon, filename,
  and `Downloading…` subtitle. Use a 16 pt corner, 0.5 pt border, and system colors.
- Shorten the flight to 300 ms. Keep full opacity until the final 12% and keep
  the card at readable size through the first 58%, then shrink into Downloads.
- Keep the existing queue limit, source-window routing, Reduced Motion path,
  hidden-sidebar reveal, and landing feedback. No new animation dependency.

## Deeper Dia evidence

Applied reverse-engineer-anything and animate. REA tools were unavailable, so this
is ordinary read-only static analysis, not REA Evidence. Same Dia 1.57.1 binary and
SHA-256 as the earlier log. The Mintlify context tool was unavailable.

`DownloadMagnetAnimationView` embeds a real `DownloadItemView`, not a loose icon.
The container and item are 220 × 36 pt (`0x1052e941c–0x1052e946c` and
`0x1052e95e8–0x1052e960c`). The icon is 20 × 20 pt, row inset and gap are 8 pt,
title is 12 pt with middle truncation, and subtitle is 10 pt with end truncation.
The corner is 16 pt on macOS 26+, 12 pt on older systems. The card uses system
window background and secondary fill border colors. This trace does not show a
blur material. Both motion styles retain the full card.

Dia generates its duration from a state-dependent frame sequence. A virtual-only
recording still showed only its indicator response under computer-use input.
Its complete flight duration remains unverified. The 300 ms duration is Cove's
tuning in response to the user's speed feedback, not a recovered Dia constant.
Permission was requested for a virtual-only physical click helper; no answer had
arrived, so that helper was not run. No frame-for-frame parity claim.

## Verification

- Build succeeded. Final suite: **199 tests in 47 suites passed**.
- Recorded Cove on Virtual 16:9, display 5, browser frame `(2143, 206, 900, 680)`.
- Frame review confirmed readable filename, subtitle, icon, and landing. It caught
  missing truncated filenames in the initial CATextLayer version. Explicit font,
  font size, and resolved foreground color fixed the rendering.
- The slow download showed the concise shared-unit progress. Small and slow files
  completed. The hidden sidebar revealed for the card and closed after landing.
- A repeated coordinate-click attempt selected a sidebar tab after reveal; it was
  not a valid burst test. The page was restored. No new rapid-burst claim is made.
- Final build remains on Virtual 16:9, with Downloads open over the original Spoke
  page. The fixture tab is closed. Server and recorders stopped. Test records remain.

Local evidence under `build/download-motion-study/`: `card-addendum.md`,
`dia-download-assets.json`, `dia-card-reference.mov`, `cove-card-readable.mov`,
`cove-card-readable-frames.png`, and `cove-card-hidden.mov`.

Test log: `/tmp/cove-download-card-final-tests.log`.
Result: `build/dia-polish/Logs/Test/Test-Cove-2026.11.14_00-52-47-+0530.xcresult`.

## Small commits

- `979717e` — concise counts in one shared unit.
- `15d3fbf` — readable card and faster flight.
- This log is a separate commit.

Earlier work was pushed and merged through PR #19, merge commit `53ed35d`.
These corrections continue on `main`, as requested.
