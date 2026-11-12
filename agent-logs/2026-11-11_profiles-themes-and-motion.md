# Profiles, themes, and browser motion

Date: 2026-11-11
Branch: `codex/dia-browser-polish`
Base commit: `c49487a`
Status: Local changes. No commit, push, or release was made in this session.

## Scope and decisions

The user asked for Dia's layout and motion while keeping Cove's extra features.
Work proceeded through the browser controls, loading light, profiles, themes,
and repeated revisions to space switching. The user tested the physical
trackpad and gave feedback between revisions.

This log records the final behavior and the checks made during that work.
The [earlier comparison log](2026-11-08_dia-browser-polish.md) records the
initial layout changes and the loading-light studies in more detail. Values
in that log describe successive experiments; the final values below take
precedence where they differ.

## Address field and loading light

- Navigation stays above the page. Address editing opens near the toolbar.
- Browser controls use SF Symbols with shared sizes and weights. Site icons
  and extension icons come from their respective sources. Spaces can use
  symbols or emoji; macOS supplies window controls.
- The toolbar is 40 points high. Control spacing is 2 points, button areas
  are 28 points, and the address field is 32 points high.
- The loading strip is 1 point high. Its color follows the Space theme.
  There is no white highlight or repeating shimmer.
- The selected Soft lift light spreads upward from a finite strip. Its short
  right spill softens the end without adding another light source past it.
- The address field's rounded shape clips the light, including its left edge.
- Final settings: upward spread 34 points, glow strength 0.19, right spread
  8.26, intensity base 0.45, curve 1.4, and line strength 0.9.
- Progress comes from WebKit. Stop and completion clear the indicator.

Built `prototypes/loading-light/GlowLab.swift` so the user could compare
presets, colors, progress, and loading states. It includes saved choices and
the actual Dia reference crop. The selected settings were then added to Cove.

Reference artifacts under `build/glow-study/` include `dia-reference.png`,
`dia-address-crop.png`, `balanced-tip-comparison.png`,
`cove-chosen-glow.png`, and `cove-chosen-glow-warm.png`. These are local build
artifacts, not a measured match of Dia's frame timing.

## Profiles, Spaces, and page colors

Profiles keep cookies, logins, and site data separate. Spaces hold tabs, a
name, an icon, and a theme, and select which profile to use. Creating a profile
alone does not create an item in the sidebar.

- Tested creation of Test Profile and its Test Work Space.
- Tested separate cookies and local storage for Personal and Test Profile.
- Checked that names, icons, themes, tabs, and test data survive a restart.
- Removed a delayed selection that could apply after a more recent click.
- The toolbar reads WebKit's page background color and adjusts control
  contrast. The outer frame retains the Space theme.
- Checked live light, dark, and warm page-color changes.

The test profiles and Spaces remain available for the user's review. This
work did not change the product's shared history or downloads behavior.

## Space switching: final motion

The first crossfade was unsuitable for trackpad swipes. It was replaced with
adjacent tab lists that move horizontally together. Preparing a neighboring
list does not select its Space or wake its web pages.

One transition state now controls the tab lists, heading, Space icons, and
frame color. It has idle, tracking, and settling phases. A revision token
prevents an old completion from applying after a reversal or cancellation.

The final revision uses the Emil Kowalski and animation skills:

- During a drag, the lists follow input directly. There is no spring lag.
- On release, a critically damped spring uses the current position and swipe
  velocity. Velocity is bounded to prevent overshoot and a pull back.
- The response parameter is 0.18 seconds. The maximum settle time is 0.28
  seconds; this is a cap, not a fixed wait. A nearly complete swipe ends sooner.
- A display link drives release motion on the window's display. The spring
  integration follows the same mathematical path at 60 Hz and 120 Hz.
- Edge resistance applies at unavailable neighbors and beyond the adjacent
  page. Each gesture selects at most one adjacent Space.
- A new drag can interrupt the release from its current visible position.
- The moving icon highlight and icon scaling were removed. Icons use a
  restrained brightness change from the shared progress value.
- A completed change requests one light haptic cue where supported.
- Reduce Motion commits the Space switch without the release animation.

The earlier fixed 280 ms release and spring during dragging were rejected
because they felt slow and resistant. They are not in the final implementation.
After the final revision, the user said "Okay, perfect."

## Page changes and blank frames

The web view now uses a stable host instead of creating a new host for each
selected tab. Incoming views receive valid bounds before attachment.

The outgoing page stays visible while the replacement is prepared. The host
waits for loading to finish and requests a WebKit snapshot after screen updates.
It then crossfades over 0.18 seconds (0.08 with Reduce Motion) before exposing
the live incoming view. This addresses the reproduced case where a document
was parsed but a blocking script had prevented the page from being painted.

During preparation, a new request replaces the pending destination. Once a
fade starts, it finishes; only the latest further request is retained. Request
IDs reject stale render callbacks. Focus callbacks also check the current
page and window. The old page cannot receive clicks during the handoff.

A snapshot failure uses an outgoing-page fade as a fallback. A slow incoming
page can keep the old page visible until loading completes. This is a known
tradeoff, not a claim that all website flicker is eliminated.

## Validation and evidence

Final automated run: **178 tests in 37 suites passed**.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project Cove.xcodeproj -scheme Cove \
  -configuration Debug -derivedDataPath build/dia-polish \
  test CODE_SIGNING_ALLOWED=NO
```

Result bundle:
`build/dia-polish/Logs/Test/Test-Cove-2026.11.11_00-41-51-+0530.xcresult`

Console log: `/tmp/cove-balanced-swipe-tests.log`.
`git diff --check` passed. Earlier runs of 155, 160, 168, and 177 tests were
intermediate checks; 178 is the final recorded suite count.

The added tests cover direct drag tracking, release velocity, no overshoot,
60/120 Hz integration, interruption, short remaining distances, state
revisions, page request ordering, stale callbacks, and page-host bounds.

Computer-use checks on Virtual 16:9 covered:

- Loading, completion, Stop, address editing, and multiple theme colors.
- Profile creation, site-data separation, and restart persistence.
- Live page-color changes and control contrast.
- Repeated keyboard Space switches and the final selected page.
- Separate browser windows and focus.
- A 14-second paint-blocked page: the old page stayed visible until the new
  page was ready. Captures: `build/profile-study/slow-page-hold.png` and
  `build/profile-study/slow-page-ready.png`.

The computer-use scroll command supplied no horizontal trackpad movement.
It therefore did not validate physical swipe feel or haptic feel. The user
performed those checks. Exact Dia curves, frame pacing under load, and a
system-level Reduce Motion session remain unmeasured.

Temporary motion test controls and tracing were removed before the final
build. The revised app was checked on Virtual 16:9, then moved to Built-in
Retina Display for the user's test.

Build: `build/dia-polish/Build/Products/Debug/Cove.app`.
Local fixtures used ports 18766 (slow load) and 18767 (profiles and colors).
Their scripts and logs are temporary local files, not repository dependencies.

## Next review

The agreed feature review order was browser controls; profiles, Spaces, and
themes; tabs; page tools and Library; then advanced features.

The recent motion and page-handoff work is complete at the level described
above. No separate unfinished code task was found in the chat history. The
next planned area was tabs: create, close, reorder, pin, group, and restore.
The user confirmed this scope. See the [tab review log](2026-11-11_tab-review.md)
for the subsequent fixes and 180-test result. The accepted Space motion and
loading light were kept intact.
