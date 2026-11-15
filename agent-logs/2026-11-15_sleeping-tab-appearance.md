# Sleeping tab appearance — 15 November 2026

## Request

Remove tab dimming, keep tab sleeping, make small commits, push to main and update the log.

## Change

- Removed the 55% sleeping opacity and its fade animation from the shared tab row.
- Removed the separate 70% sleeping opacity from pinned tiles.
- Removed the unused opacity constant and the unverified Arc comparison comment.
- Sleep policy, memory release, wake/reload behavior and saved state are unchanged. Hover and active states remain.

Implementation commit: `aa77b47`.

## Checks

- Source search found no remaining sleep-driven appearance rules in the UI or profile views.
- Diff contains only nine deleted lines in the two UI files; no browser lifecycle files changed.
- Debug build passed with `build/dia-polish`; output: `/tmp/cove-sleeping-tab-appearance-build.log`.
- No new tests or computer-use pass for this presentation-only removal. The running app was not restarted.
