# Tools discovery and Notes polish

Date: 16 November 2026. Branch: `main`. Follow-up to the command bar and Notes pass.

## Request

The command cleanup hid too much. Restore Easel and make the rest of Cove's tools easy to find. Make Notes darker, fix format selection states, and soften table borders.

## Discovery audit and changes

| Area | Access after this pass |
| --- | --- |
| Notes and Easels | New Tab quick actions, command search, and All tools → Create. Existing documents stay searchable. |
| Capture and Boosts | All tools → Page Tools, with descriptions of page clippings, site styles, and hidden elements. Require a web page. |
| Pinned tabs, folders, groups, and profiles | Create and Tabs and Profiles categories. Added direct Group Selected Tabs and Remove Tabs from Group commands. Existing tab menus remain. |
| Split View and layout | Windows and Layout includes add, rotate, separate, and equal split sizes; sidebar/top tabs and visibility; Little Cove and private windows. |
| Media | Audio and Video lists mute/unmute, play/pause, and Picture in Picture. Playback commands keep their existing state checks. |
| Downloads, closed tabs, and history | Separate named commands in Library and Settings; no need to know that Library contains them. |
| Settings and extensions | Direct settings, appearance, privacy, and extension commands. General Settings points to the tools browser. Search terms also cover sleeping tabs, automatic archive, and search settings. |
| Peek | General Settings explains Shift-click on a link. Peek needs a link target, so it stays a link interaction. |

The command bar footer now has **All tools**. **Browser → Browse Cove Tools…**, **Help → Browse Cove Tools…**, and **⇧⌘P** open the same list. Six categories and short descriptions explain what each command does. Search matches names, aliases, and descriptions: “canvas” finds Easel; “CSS” finds Boosts.

The catalogue uses the existing command enum, not a second action registry. It lists every command once, including unavailable commands with a reason. Keyboard selection skips disabled actions. Both the view and model reject disabled actions. Tool search does not request web suggestions. Normal URL/search and Split View search keep their own result rules.

The empty command bar now shows up to three recent pages and three quick actions: New Note, New Easel, and Reopen Last Closed Tab. Alternate window/layout commands are searchable again.

## Notes

- Dark writing surface: white level 0.055, about #0E0E0E. Light appearance retains the native content surface.
- Text style is based on paragraph and font metrics, not exact font equality. Bold body text stays Body; italic headings stay Heading.
- Mixed text styles display **Mixed Styles**. Emphasis and list states read the whole selection. Mixed bold/italic selections apply the trait to all selected text.
- Native style picker and checked menu items show current style, list, highlight, and strikethrough states. The formatting bar does not edit a stale body selection while the title has focus.
- Native tables use collapsed 0.5 pt separator-color borders with 6 pt cell padding. Shared cell identity and document content are preserved. Saved tables get the same treatment on load.

## Checks

- Full Debug suite: **266 tests in 53 suites passed**. Output: `/tmp/cove-tools-final-tests.log`.
- Added checks for catalogue completeness, category order, description/alias search, and private-window disabled actions.
- Added Notes regressions for bold body/italic heading recognition, mixed selections, and table cell identity/borders.
- Built with full Xcode via `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`, derived data `build/dia-polish`. `git diff --check` passed.
- Computer-use tests ran on **Virtual 16:9** after moving the restarted Cove window there.
- Verified ⇧⌘P, the All tools footer, and the Help entry. Searched “canvas,” opened Easel, and named the owned fixture “Cove tools discovery check.”
- Searched “CSS” with a note active. Boost stayed visible, explained the web-page requirement, and Return did not run it.
- Verified note Heading → italic remained Heading; mixed heading/body selection showed Mixed Styles; choosing Subheading updated the text and toolbar; Undo restored Body.
- Viewed the darker surface and thin table grid in the existing owned fixture “Cove text and layout check.” No user note contents were changed.

Coverage limits: this pass tests discovery and the changed Notes behavior. It does not retest every existing tool end to end. Picture in Picture still uses its existing page-based availability check; video eligibility is resolved by the page implementation. No new Apple Notes parity claim.

Design guidance: better-layout, apple-design, better-ui, and better-typography from the preceding pass. Native SwiftUI/AppKit controls remain in use. Mintlify context was not exposed in this session; prior API checks used Apple documentation and installed SDK headers.

## Commits

- `b5f8f9c` Restore Easel and browser tools to command search.
- `b77147e` Fix note formatting states and soften the writing surface.
- `981ae37` Add a searchable catalogue of Cove tools.
- This log and the roadmap follow in a separate documentation commit.
