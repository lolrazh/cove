# Repository cleanup and command bar — 2026-11-12

## Scope and evidence boundary

The user expanded cleanup from the page host to the repository, reported the
Clear separator, last-tab close restriction, and slow hidden-sidebar exit, then
requested a command-bar design refresh using the UI skills.

The user chose to keep the window open on a start page after the last tab closes.
The existing working tree contained earlier accepted glow, profile, and tab work;
that work was preserved. The pre-pass tracked diff is saved locally at
`build/repo-cleanup/before-this-pass.patch`.

Repository-wide inventory and symbol/reference scans covered all shipping Swift
source, tests, project configuration, and resources. The initial inventory was
146 Swift source files and 20,104 lines. The unused sidebar address component was
removed. No third-party packages were added. Development prototypes and recorded
studies are not app target sources and were retained as evidence.

This was not a line-by-line audit of every feature. Detailed reads followed the
reported interactions and ownership through AppServices, TabManager/TabSession,
command bar, frame/chrome, persistence, documents, content blocking, settings,
spaces, extensions, Library, downloads, Peek, and Little Cove. Symbol scans do
not prove that a protocol callback or runtime selector is unused; these were kept.
Existing conventions came from ChromeTokens/ChromeSurfaces, PRODUCT.md, the
historical ARC-PARITY.md checklist, and the earlier cleanup log. The user's newer
Dia direction takes precedence over the old Arc checklist.

## Repository changes

- Deleted the unused SidebarAddressPill component and its Xcode references.
- Deleted SidebarClearLine, its button symbol, and the now-unused Clear Today
  method. A second tab no longer inserts a separator above Today.
- Removed unused toggleLayout, openSelection, overflow symbol, and isLoaded API.
- Removed the frame's observation of the active page. NavigationBar and PageView
  still observe it; progress no longer invalidates the whole shell through that
  subscription.
- Removed the sidebar's 600 ms hide task and 1,200 ms fallback. One stable hover
  region follows the pointer. Exit has no intentional wait and uses a 90 ms
  ease-out slide; entry is 140 ms. Reduce Motion uses a short opacity change.
- Last-tab close first installs a fresh start-page tab, then archives and closes
  the old tab. The window and selection stay valid. This keeps the existing
  one-tab invariant; the start page is still a row, not a zero-tab window.
- A regression test exposed immediate-close data loss: the requested URL was not
  retained until WebKit sent its callback. The shared loadRequest path now keeps
  it synchronously, so a page closed before loading can still be reopened.
- Content blocking uses one weak collection of tracked controllers, instead of
  tracked plus pending lists that could attach the same rules twice. Detach also
  removes exemption bookkeeping. Concurrent loads share a simple in-flight
  guard. AppServices no longer starts a second startup load; the settings
  observer owns it. Its supplied UserDefaults now reach the blocker.
- Note, DocumentStore, PinStore, and SessionStore own notification subscriptions
  through AnyCancellable, so subscriptions end with the owner. SessionStore also
  ensures its destination directory exists before saving.

## Command-bar skill review

Applied Better Layout, Better Typography, Better UI, Better Accessibility,
Better Colors, and Better Writing, then consolidated with Better Interface.
Emil design engineering and Write Swift informed the implementation. These are
native SwiftUI/AppKit controls; CSS-only instructions, 320 px mobile layouts, and
browser page zoom do not describe this app's supported window size.

| Domain | Evidence inspected | Result |
| --- | --- | --- |
| Accessibility | CommandBarField handlers; live AX names, roles, selection; Tab/Shift-Tab, arrows, completion, Return, Escape, close button | Rows are native buttons; field and close control named; keyboard route checked. Full VoiceOver walk not verified. |
| Layout | CommandBarView; live default, search and long-URL states; docked and hidden sidebar | Full row fills and two-line page results verified. Minimum-window resize not verified: computer-use drag did not resize the virtual window. |
| Writing | Existing command titles and result groups; footer and close label | Existing vocabulary retained; Select/Open/Close hints describe the keys. |
| Typography | System font roles and captured text | Input 20 pt, title 14 pt medium, detail 12 pt; full values available through AX/help and editing. |
| Colors | Dark-mode recording and adjacent text/fill samples | Sampled pairs exceed 4.5:1. Light appearance and increased contrast not verified. |
| UI polish | Native icons, panel/row radii, selection, immediate presentation | No open/close or hover delay on command bar; 20 pt outer / 10 pt inner radius with 10 pt inset. |

| Severity | Domain | Location | Before | After | Why |
| --- | --- | --- | --- | --- | --- |
| HIGH | Accessibility | CommandBarView.swift:128 | Clickable text rows | Named native buttons with selected state and full detail | Controls expose their action and state. |
| HIGH | Accessibility | CommandBarField.swift:103 | Tab could leave the overlay for the underlying page | Accept completion, otherwise move selection; Shift-Tab moves back | Keep keyboard work in the search flow. |
| HIGH | Layout | CommandBarField.swift:37 | Long input could push the close control out of view | Native field can compress horizontally and scroll its text | Keep close available with long addresses. |
| MEDIUM | Layout | CommandBarView.swift:198 | Highlight covered the text line, although row reserved 36 pt | Full 44 pt action rows and 56 pt page rows | Align visible selection with the hit area. |
| MEDIUM | Typography | CommandBarView.swift:213 | Title and URL competed on one line | Title above URL, with separate size/weight roles | Preserve identity and address. |
| MEDIUM | Layout | CommandBarRanker.swift:57 | Six recent pages crowded commands below the fold | Four recent pages; commands remain searchable and scrollable | Show both groups on first opening. |
| MEDIUM | Colors | CommandBarView.swift:122 | Tertiary section labels | Secondary semibold labels | Improve section recognition; measured in dark appearance. |
| LOW | Writing | CommandBarView.swift:163 | No visible keyboard guidance | Select/Open/Close footer | Make frequent actions discoverable. |

The shared AppKit field editor changes delegates when focus moves. Focus restore
now captures the prior control before that change, rather than consulting the
shared editor after dismissal.

## Checks

- Full Debug suite: **186 tests in 39 suites passed**. The new test closes the
  only page immediately, verifies the empty start page and valid selection, and
  reopens the original requested address.
- Existing rapid open/close/reopen, document, pin, archive, profile, WebKit color,
  and page ownership tests remain in the suite.
- Build and `git diff --check` passed.
- Live tests ran on Virtual 16:9. Opened Wikipedia through the command bar,
  closed the final page to the start page, and restored Wikipedia with Cmd-Shift-T.
  Two Today rows showed no Clear separator.
- Verified command-bar arrow selection, Tab/Shift-Tab selection, inline address
  completion, Enter navigation, Escape dismissal, and the named close button.
- A long-address check exposed the compression bug; the rebuilt app showed the
  close button again while the native field scrolled the full address.
- Recording: `build/repo-cleanup/command-bar-and-tabs.mov`.
  Dark image: `build/repo-cleanup/command-bar-dark.png`.
- Dark screenshot contrast samples: selected title 10.19:1, selected URL 5.26:1,
  section label 5.98:1, footer hint 5.80:1. Used the 99th percentile of a glyph
  region against its flat adjacent fill. This is a sampled rendering check, not
  a complete accessibility certification. Values are in
  `build/repo-cleanup/command-bar-contrast.json`.

## Pending visual check

Computer-use clicks and drags did not deliver hover events on Virtual 16:9. A
short-lived diagnostic trace produced no pointer events and was removed from
source. Asked permission for a helper restricted to the virtual Cove window.
The helper is prepared in `build/repo-cleanup/virtual-pointer.swift`; it refuses
any path outside Cove on Virtual 16:9. It has not been run without approval.

Source timing is verified; physical reveal and mouse-exit timing is not yet
measured. This is a verification limit, not a passed hover test.

Approve the inspected command-bar states only. Full VoiceOver, light appearance,
minimum-window resizing, and physical hover behavior remain not verified.

## Handoff

The final build is open on the main display with the refreshed command bar
focused. Verified placement through the Window menu, which now offers Move to
Virtual 16:9. Restored the hidden-sidebar preference after the tests.

Escape closes the command bar, but the live accessibility check on the start
page reported focus on the window rather than its search field. Exact focus
return to that field remains unresolved; do not count it as a passed check.

## Follow-up: sidebar corners and compact centered command bar

The user tested sidebar hover and approved its feel. They chose to test pointer
behavior themselves; the prepared mouse helper was not run.

Applied Better Layout and Better UI to these specific follow-up changes:

| Severity | Location | Before | After | Why |
| --- | --- | --- | --- | --- |
| MEDIUM | BrowserShellView.swift, floatingSidebar | Rounded background beneath a square header backing | Clip all sidebar content to a continuous 10 pt rounded rectangle, then draw the shadow outside | The header cannot cover the top-right curve. |
| MEDIUM | ChromeTokens.swift, sidebarRevealWidth | 8 pt approach region | 24 pt for the sidebar; top strip stays 8 pt | Reveal sooner without changing exit timing or intercepting page clicks. |
| MEDIUM | BrowserShellView.swift, CommandBarOverlay | Overlay centered inside the page card and anchored at the top | Overlay covers the whole shell | Centering no longer shifts with the docked sidebar. |
| LOW | CommandBarView.swift, layout metrics | 680 pt width, 64 pt field, 44/56 pt rows, 420 pt list cap | 600 pt width, 56 pt field, 40/48 pt rows, 360 pt list cap | About 12% narrower and 14% shorter at full height, with existing text sizes retained. |

The full 444 pt panel footprint is centered vertically. Shorter result lists
shrink upward from the bottom while the input stays at the same position. This
avoids moving the field under the pointer as local or remote results arrive.

Reference comparison, checked 2026-11-12:

- Arc screenshots show a central floating command palette. This was a visual
  reference, not a live measurement of Arc: https://allthings.how/how-to-use-the-arc-browser/
- Ardia's current source uses a 652 pt centered bar at typical page widths,
  36 pt suggestion rows, and places its centered panel's top at 22% of card
  height. Its regular address panel can instead anchor to the toolbar/sidebar.
  Source: https://github.com/ardia-browser/ardia/blob/main/apps/browser/src/components/ntp/NewTabPage.tsx
  and https://github.com/ardia-browser/ardia/blob/main/apps/browser/src/components/omnibox/CommandPanel.tsx
  and https://github.com/ardia-browser/ardia/blob/main/apps/browser/src/components/omnibox/tokens.ts
- Cove keeps two-line page results, so 48 pt rows retain useful address detail.
  No Ardia dependencies or source implementation were copied into Cove.

Validation: all 186 tests in 39 suites passed (2.631 seconds); build and
git diff --check passed. Result bundle:
`build/dia-polish/Logs/Test/Test-Cove-2026.11.12_14-42-14-+0530.xcresult`.
Live Virtual 16:9 checks covered centered placement with docked and hidden
sidebar, stable input placement while typing, command execution, outside-click
dismissal, and the rounded floating surface through its Library state. Physical
hover entry remains for the user to test. Minimum-window resize and light mode
were not retested. Approve only these inspected states.

Returned Cove to the main display, restored hidden tabs, and left the command
bar open and focused for review. The existing page and tabs were preserved.

## Follow-up: larger favicons and XMLPrompt.dev color

The user withdrew the layout changes and deferred address-bar hover styling.
Only command-bar page favicons grew, from 16 to 22 pt inside the existing 24 pt
slot. Row geometry, headings, text, and address hover styles are unchanged.

Live DOM inspection of XMLPrompt.dev found a white body, a nested cream app
shell (#FEF7CD), and a nested green full-width header (#9AE66E). The old detector
only composited html/body, so it reported white despite those visible surfaces.

PageBackground now follows the ancestors at the top-center of the viewport and
composites broad surfaces in paint order. Small controls are excluded by their
width/height. The observer only schedules work for the sampled ancestors and
mount points; unrelated descendant content edits do not schedule a repaint.
Existing stylesheet, theme, resize, and page-show invalidations remain. Identical
RGB values do not publish updates; the per-context URL cache remains unchanged.
No polling, screenshot sampling, or per-tab-selection recalculation was added.

Added a real WKWebView regression test covering delayed app mount, nested header
color, a small red control that must not set the toolbar color, content edits,
reattachment, style change, header removal, and translucent compositing.
All **187 tests in 39 suites passed** (2.985 seconds), and git diff --check passed.
Result bundle: `build/dia-polish/Logs/Test/Test-Cove-2026.11.12_15-02-22-+0530.xcresult`.

Live Cove checks on Virtual 16:9 showed the green toolbar matching XMLPrompt's
header and the larger Recent favicons without shifting the existing row layout.
Dia comparison was attempted, but the selected reference window changed before
a loaded-page comparison was available; exact Dia color parity is not claimed.
The detector covers CSS background colors, not arbitrary background images or
gradients. Cove was returned to the main display with XMLPrompt.dev open.
