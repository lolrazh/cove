# Command bar and native notes

Date: 16 November 2026. Work on `main`, in small commits.

## Follow-up

The later tools-discovery pass restores Easel and alternate layout/window commands, adds All tools, and fixes Notes selection states and table styling. Current behavior and checks are in `2026-11-16_tools-discovery-and-notes-polish.md`. The entries below record the earlier pass.

## Changes

- Empty command search shows four recent pages and up to two quick actions: New Note and Reopen Last Closed Tab. It fits the normal panel without scrolling. Settings, history, and other useful commands remain searchable.
- Search suggestions sit beside the main search result. Notes, easels, profiles, extensions, history, and commands have separate sections. Duplicate suggestions are removed.
- Removed drawing and alternate window/layout actions from the command bar; their app menus remain. Page actions are hidden while a note is active or when no page is available. Split View search offers pages and eligible open tabs, without unrelated commands, notes, profiles, or extensions.
- Notes use native SF text: 17 pt body, 28 pt title, 22 pt heading, 17 pt bold subheading, and 15 pt monospaced text. The writing column is capped at 640 pt. Paragraphs have 4 pt line spacing and 6 pt spacing after body paragraphs.
- The formatting bar groups text style, emphasis, lists, checklists, links, and find. Bold/italic/underline/checklist buttons reflect the selection. Controls have labels, hover feedback, and keyboard support.
- Added Notes-style heading/body/monospaced/list shortcuts, automatic list prefixes, Tab/Shift-Tab list indentation, keyboard checklist completion, and proper Return/Backspace behavior. Inserting in the middle of a numbered list updates later numbers. A heading returns to body style after Return.
- Added block quote indentation, a translucent highlight, native table insertion/settings, and note printing. Table Tab/Shift-Tab moves between cells; Return moves down and grows simple tables at the bottom. Shift-Return moves up. Merged imported tables retain their structure; structural changes use the native table panel.
- Find in Note uses the native incremental find/replace bar. Browser page search no longer receives the note's Find command.
- Shared browser row text is 14 pt and supporting text is 12 pt in tabs, groups, folders, note tabs, profile labels, library rows, find, site controls, previews, and toasts. Website fonts remain website-controlled.

## Text-rendering findings

| Finding | Fix |
| --- | --- |
| The editor set `font` after attaching shared text storage. This setter changes stored formatting. | Attach a layout manager without assigning a font over the document. Set typing defaults instead. |
| AppKit writes the proportional system font to RTF as Helvetica Neue. Reopening changed the font family. | Restore SF from the RTF alias while keeping size, bold, italic, and links. Upgrade Cove's old small default sizes. Other families, such as Georgia, remain intact. Helvetica Neue in imported notes also uses this normalization. |
| RTF discards highlight alpha. | Restore translucent highlight backgrounds on load, so they remain readable in dark mode. |
| Small callout/caption styles made common browser labels look weak. | Use shared 14/12 pt native system roles in the listed surfaces. |
| Empty notes could read a character at an invalid storage index when testing for a list. | Guard empty storage and empty trailing paragraphs. |
| The default NSTextView table Tab inserts a tab inside the cell. | Navigate native RTF cells explicitly, without a separate document model. |

No global font-smoothing override or text rasterization layer was found. No OS font preferences were changed. Native text rendering, automatic font metrics, and semantic foreground colors remain in use. Adaptive dark appearance handles pasted component colors.

## Reference and skills

Applied better-layout, apple-design, better-ui, and better-typography. Adapted their principles to AppKit/SwiftUI rather than copying CSS rules into a native app.

Apple Notes was moved to Virtual 16:9. A temporary reference note was created to inspect body/title layout and the format menu. That reference note was moved to Recently Deleted afterward; existing notes were not edited.

Primary references:

- https://support.apple.com/guide/notes/keyboard-shortcuts-and-gestures-apd46c25187e/mac
- https://support.apple.com/en-ie/guide/notes/apd1955d3b21/mac
- https://developer.apple.com/documentation/appkit/nstextview
- https://developer.apple.com/documentation/appkit/nstextview/usesfindbar

The Mintlify context tool was not exposed in this session. API details were checked against Apple documentation and the installed AppKit SDK headers. Direct Apple Support page opens returned HTTP 429; indexed Apple Support content supplied the shortcut table. Native Notes was also inspected directly.

This delivers the core text-editing flow, not full Apple Notes parity. Collapsible headings, internal note links, Markdown round-trip, and the complete Notes table/attachment UI are not implemented. Block quotes use paragraph indentation rather than Notes' exact decorative rule. The title remains a separate field and is not part of the body find bar.

## Verification

- Full Debug build and test run: **260 tests, 53 suites passed**. `/tmp/cove-notes-final-tests.log`.
- New regression coverage: shared editors preserve fonts/links/attachments; formatting undo/redo; empty Return; heading-to-body Return; paragraph selection boundaries; all four list types; list exit/undo; multi-paragraph selection; automatic prefixes; checklist continuation; saved indentation; ordinary tab-separated text; legacy font upgrade; custom fonts/links; current styles/highlights after reopening; quotes; highlight selection; table navigation/growth/undo; middle-of-list numbering.
- Command-bar tests cover the short empty state, split open-tab choices, result order, duplicate suggestions, and searchable extensions without empty-state clutter.
- Virtual-screen checks: create note from command bar, enter title/body, use heading shortcut, continue body, make/check/continue/exit checklist, native Find and result highlight, bold selection state, undo/redo, hide Copy URL while a note is active, restart and reopen saved formatting, highlight persistence, table insertion, cell navigation, Return to next row, and automatic row growth. Final empty command panel fit without scrolling.
- Visual checks used the current dark appearance. Light appearance was not visually checked. Exact Apple Notes typography/pixel parity is not claimed.
- An early synthetic undo test manually closed AppKit's event group and caused a test-host exception. The harness was corrected to clear preparation actions without manipulating the event group. Final native undo tests and live undo/redo passed.
- The saved review fixture, `Cove text and layout check`, remains open in Cove on Virtual 16:9. No existing Cove notes were edited.
- Local capture, excluded from Git: `build/notes-ux-study/final-note.mov` and `final-note.png`. The approved recording helper rejected other displays and captured only the Cove window inside Virtual 16:9.

## Commits

- `d4a1eac` — simplify command search and result sections.
- `af3308b` — preserve note formatting and improve native text sizing.
- `7faadc0` — refine notes, lists, shortcuts, and saved system fonts.
- `5f4ce17` — consistent readable browser text roles.
- `8827e73` — short empty command search without scrolling.
- `ddc126f` — quotes, highlights, and native table controls.
- `9ef32ca` — table navigation and numbered-list insertion.
