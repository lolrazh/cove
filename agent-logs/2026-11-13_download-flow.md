# Downloads: Dia comparison and Cove flow

Date: 2026-11-13. Branch: `codex/dia-browser-polish`.

## Request

Compare downloads with Dia, improve the whole flow, test on Virtual 16:9,
make small commits, and update the log.

## Reference observed

Tested Dia 1.57.1 with a local HTTP fixture on Virtual 16:9. The fixture sends
safe text files, a slow transfer, a transfer without a length header, and an
interrupted transfer. No account sign-in was needed.

Dia's compact download view uses a native translucent popover. It keeps the
file name above a short status line, with a separate Finder action. A small
completed download opens the popover. Its download button is in the sidebar
header. Command–Shift–J opens a full download-history page. That page has
pause/cancel actions and a separate list-removal action.

Cove follows the compact popover pattern. Its button sits beside the address
bar so it stays available with the sidebar hidden. Command–Shift–J opens the
same popover. The Library still provides access to the download list.
This is a comparison of observed behavior, not a claim of frame-identical
motion or a binary reverse-engineering result.

## Changes

- Added a compact native download popover. Opening it keeps the page and tabs
  in place. New foreground downloads show it; background profiles do not
  take focus.
- Rows keep a 22-point file icon, fixed text positions, a 24-point action area,
  and a reserved thin progress track. Progress retargets with a 180 ms ease-out
  transition. Reduce Motion removes that progress animation.
- The popover uses the window appearance, not the web page's contrast scheme.
  Live testing caught dark text on a dark popover above a white page; fixed it.
- Added explicit cancel, retry, open, Finder, copy-link, and remove actions.
  Completed file names remain accessible buttons. A moved/deleted file shows
  a clear status and a retry action where supported.
- Retry uses the same row and the owning profile's WebKit data store. It starts
  a new GET from zero. It does not replay POST requests or blob URLs.
- Progress updates from an old attempt cannot change a cancelled, failed, or
  completed item. Aggregate progress stays within 0–1. Unknown-size transfers
  show received bytes without an invented percentage.
- Reserved destination names prevent concurrent collisions. Final delivery
  checks the name again. The visible name matches the actual chosen name.
- Incomplete files stay in a temporary directory. Only completed files move
  into the selected folder. Cancellation and network failure remove their
  temporary files. This fixes the partial file found during the first live run.
- Download history is saved atomically per profile in `downloads.plist`.
  Downloads active at shutdown return as interrupted, with retry where safe.
  Private windows use a separate in-memory manager and data store.
- Clear removes finished records only. It does not delete downloaded files or
  stop active downloads. Failure also leaves an unread download indication.
- Save dialogs attach to the current window. Cancel creates no extra row.
  If a selected name exists, Cove keeps both files by adding a suffix.

## Verification

The final automated run passed **197 tests in 47 suites**, including six new
focused download tests. Coverage includes destination collisions and path
cleanup, terminal-state progress, interrupted restore, missing files, renamed
files, history persistence, non-destructive Clear, and private context isolation.

Live checks on Virtual 16:9:

| Check | Observed result |
| --- | --- |
| Start a slow download | Popover opens; received bytes and progress advance |
| Cancel, then retry | Cancel is immediate; retry keeps the row and completes |
| Break the connection, then retry | Failure shows a retry action; next attempt completes |
| Unknown size | Received bytes appear; no false percentage; cancellation leaves no destination file |
| Two same-name downloads together | Both finish with separate names and matching content |
| Clear during two transfers | Finished rows disappear; both active transfers continue; existing files remain |
| Switch from Personal to Space 2 | Space 2 has an empty list; Personal transfers continue |
| Quit and reopen Cove | Completed download records survive |
| Open the 76-byte text file | TextEdit displays the exact test text on the virtual display |
| Show in Finder | Finder selects that exact file in Downloads on the virtual display |
| Ask Every Time | Attached save sheet accepts a custom name; row and file use it |
| Cancel the save sheet | No extra record or stuck progress |
| Move a downloaded file | Row shows “File moved or deleted”; file was restored after the check |
| Restore settings | Downloads Folder restored after the save-sheet checks |

Both concurrent slow files were 1,048,576 bytes with SHA-256 prefix
`32ba732d9fc7a392`. The small text copies were 76 bytes with prefix
`77c81169d5909046`.

The browser windows were fully within Virtual 16:9 (display 5, origin
1710,0; size 2560×1440 points). TextEdit and a separate Finder test window
were placed there before file checks. The test windows were closed afterwards.
Cove's original page was restored. Test download records remain available for
review. The local test server and recording helpers were stopped at completion.

## Evidence and repeat test

Local recordings and extracted reference frames are in `build/download-study/`:

- `dia-download.mov` — reference start, cancel, history, and compact popover.
- `cove-download.mov` — first run; exposed the partial-file and contrast issues.
- `cove-final.mov` — corrected popover, retry, progress, and completion.
- `dia-popover.png`, `cove-popover.png` — extracted reference frames.

The movies are variable-frame-rate captures. The container's nominal frame-rate
field is not a measured UI refresh rate; no 600 fps claim is made.

Run `python3 CoveTests/Fixtures/download-server.py`, then open
`http://127.0.0.1:8768/` in each browser. The interrupted endpoint fails on its
first request and succeeds on the next. Stop with Control–C. The checked-in
fixture is the cleaned version of the local test server used for the live run.

Build/test logs: `/tmp/cove-download-all-tests.log` and
`/tmp/cove-download-final-tests.log`. Final result bundle:
`build/dia-polish/Logs/Test/Test-Cove-2026.11.13_23-52-05-+0530.xcresult`.

## Limits

- Retry restarts a safe HTTP(S) GET. Byte-range resume and pause are not added.
- No real authenticated download, multi-gigabyte transfer, external-volume
  destination, or physical hover test was run. Data-store isolation has unit
  coverage; the live profile check covered list separation.
- Record history from the old in-memory manager cannot be recovered after
  that process exits. Existing downloaded files are not changed.
- Reduce Motion is handled in code; its system setting was not changed during
  this run. No claim of frame-for-frame Dia parity.
- The requested Mintlify context tool was unavailable. Used the installed SDK
  and [Apple's WKWebView download documentation](https://developer.apple.com/documentation/webkit/wkwebview/startdownload(using:completionhandler:)).

## Small commits

- `57836ee` — durable, profile-scoped download state and focused tests.
- `4cc9236` — keep incomplete files out of Downloads.
- `5766d1a` — compact popover and stable rows.
- `b3bc4ae` — accessible completed-file buttons and failure indication.
- `2e9738e` — repeatable local download fixture.
- This log and the roundup are committed separately.
