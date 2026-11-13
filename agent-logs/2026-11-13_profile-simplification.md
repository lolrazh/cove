# Profiles, pinned tabs, and regular tabs — 2026-11-13

## Product decision

The user approved removing Spaces and Favorites as separate concepts.
After reviewing the saved data, the user chose **one profile per former space**,
not a merge into Personal. The user said there are no important sign-ins yet.
Keep the unused Test Profile too. No user tabs or profiles were discarded.

Current model:
- A profile has a name, theme, pinned tabs, and regular tabs.
- Dots, swipe paging, keyboard shortcuts, and the Profiles menu switch profiles.
- One Pin Tab / Unpin Tab action. Top-level pins keep the accepted balanced tiles
  and soft favicon color plus continuous color edge. Optional folders remain.
- Closing the last regular tab leaves a start page.
- Each profile owns history, archived tabs, download records, notes/easels,
  favicons, page colors, site zoom, content-blocking exceptions, and login data.
- General app preferences and installed extension packages remain app-wide.
  WebKit extension storage and site permissions remain in the browsing context.

Future request, **not implemented**: offer “Share sign-ins with another profile”
when creating a profile. Sharing sign-ins must not share tabs or themes.
The current build uses separate login stores.

## Migration and recovery

`ProfileMigration` runs before stores open. It writes a staging directory,
then publishes it with one directory rename. A decode or write failure stops
launch before stores can overwrite the source. A second run does not replay
old data over new browsing.

New live data: `~/Library/Application Support/Cove/Profiles-v1/`.
Original files remain at `~/Library/Application Support/Cove/` as the migration
backup. An additional full copy with file SHA-256 hashes was made at:
`~/Library/Application Support/Cove Backups/before-profile-validation-20261113-161347/`.
This copy was taken after an initial migration launch; it includes both the
untouched legacy files and the first migrated snapshot.

- Personal keeps the original default WebKit store.
- Each additional former space uses its old space ID as its new profile ID.
- A former profile's first space keeps that profile's WebKit store ID.
- Profiles with no spaces are kept.
- Favorites are copied into each former space's pins. Copies have independent
  IDs, saved interaction state, and remapped active-pin selection.
- Tabs retain URL, title, custom title, interaction state, last-used date,
  split membership, document positions, selection, and window placement.
- Notes used by another profile get an independent copy there.
- Old shared history and archives have no reliable ownership labels. They stay
  in Personal; new records are scoped. Old unfiled documents stay there too.
- Profile deletion does not transfer anything to Personal. It closes pages,
  clears the deleted profile's records and site data, and removes its files.
  Startup removes any late leftover files. Downloaded user files are retained.

## Implementation and checks

- Removed the Space model and PinScope, the Favorites model and commands,
  Favorites UI, and the redundant single-case pin section/drop abstraction.
- Removed context-reassignment logic that was only needed when a space changed
  its parent profile. A profile's identity is now stable.
- Command Bar, Library, start page, History menu, full History windows, and site
  controls read the selected profile's stores. All full-history entry points
  pass the profile ID. Opening a historical page returns to that profile.
- A child page opened by a parked tab stays in its source profile.
- Profile switching dismisses page-bound tools and the previous search results.
- Unit-test app launches use a temporary data root and skip real-store cleanup.

Full suite: **190 tests in 46 suites passed**. The new checks cover migration
failure and retry, unchanged legacy files, independent Favorite copies, saved
selection and tab state, profile-owned records, isolated synthetic cookies,
profile switching, background child tabs, and profile deletion. Two migration
tests also passed after adding checks for multiple windows, remapped active
pins, and independent document copies. Existing tab
close, sidebar paging, page-color, pin-color, and split tests still pass.

Local saved-data checks before UI tests:
- Four spaces and the unused Test Profile became five profiles.
- All seven saved regular tabs retained their URLs under the correct profile.
- All four saved pinned-tab session IDs survived.
- Original names and themes were retained, including the user names “Space 2”,
  “Space 3”, and “Space 4”. These are names, not a remaining Spaces feature.

## Virtual-screen check

Cove was moved through Window > Move to Virtual 16:9. The virtual-only helper
confirmed display ID 5 and Cove's window entirely within its bounds.

Observed through computer use:
- Personal, Space 2, Space 3, and Test Profile select with the matching sidebar,
  dot, theme, and page. Personal's four pins and four regular pages remain.
- The compact name/color popover remains anchored below the profile name.
- Pinning Example Domain in Test Profile produces its tile. It does not appear
  in Personal. The context menu has Unpin Tab and no Favorites action.
- Unpinning returns it to regular tabs. Closing it leaves a start page.
- Test Profile's Recent and Library History show its Example Domain visit,
  without Personal's visited pages.
- Switching back restores Personal and dismisses the previous profile's Library.
- After restarting the latest build, both Library > Show All History and the
  Command Bar Show All History command display only Test Profile's Example
  Domain record. The old process was still running before this restart; its
  result was not used to validate the fix. Personal was restored afterward.

The Example Domain test is closed. Test Profile keeps its resulting history and
archive record, plus an empty start page. No new test profile was added.

Local evidence (not committed):
- `build/profile-migration-study/profile-switching.mov`
- `build/profile-migration-study/switch-contact-sheet.jpg`

The recording is a visual smoke check, not a claim of measured app frame rate.
Physical trackpad feel and real account sign-in were not tested in this pass.
The tests use isolated synthetic cookies for login-store separation.

## Commits

- `c1c38af` Stage migration without changing legacy files.
- `d476fb7` Replace spaces and favorites with profile-owned tabs.
- `2e81917` Isolate browser records and site settings.
- `4a1952d` Keep background tab requests with their profile.
- `ac027e8` Remove obsolete pin sections and drop targets.
- `27103a8` Clear deleted profile data without transfer.
- `39af6b4` Open full history for the selected profile.
- `d06b80d` Test copied notes and active-pin migration.
- `e202358` Clarify profile ownership in source comments.
