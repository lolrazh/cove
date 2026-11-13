# Dia pinned tiles: bounded static study

Date: 2026-11-13. Method: installed macOS/Xcode tools, read-only executable inspection.

**Result:** Dia has a separate dock tile view, an image-based selected outline, and a 120 ms ease-out path for dock tile layout. The exact favicon-to-image pipeline and row balancing rule are not proven by this pass.

## Target and scope

- Target: `/Applications/Dia.app/Contents/MacOS/Dia`.
- Dia 1.56.2, build 90792, `company.thebrowser.dia`.
- SHA-256: `76c924d9bb5ea8e370f00329455607e31bb3f01cf2d0bd0a5014c89222a776d9`.
- The hash was checked again. It matches the earlier theme and tab studies, so their ObjC metadata remains applicable.
- No UI actions, profile-data reads, product edits, installs, network calls, or commits.
- Used the Reverse Engineer Anything skill's static fallback. Neither the REA MCP nor CLI was available. This report is ordinary static tool evidence, **not REA Evidence**.
- All code addresses below are unslid.
- Disassembler symbol labels are often the nearest unrelated surviving symbol. The linked ObjC metadata, selector stubs, and import table establish the relevant names. Do not use those nearest-symbol labels as function identities.

## Direct evidence: image-based selection outline

`TabUI.TabDockItemView` is an NSControl. Its metadata names these separate pieces:

- `restingDebossedView` and `backgroundLayer`;
- `flatSelectionView` and `selectionOutlineView`;
- `iconView` and `backgroundImageView`;
- `glossGradientLayer` and `glossGradientMaskLayer`;
- `itemCornerRadius`, `hoverInset`, `animationStyle`, and paging opacity state.

The private `TabUI.SelectionOutlineView` is an NSView. It owns `style`, `cornerRadius`, `strokeWidth`, `imageView`, `imageMaskLayer`, and `saturationFilter`.

A style branch at `0x10465a8d0` reads an image-like object from the style payload. It then:

1. assigns `imageMaskLayer` to the view layer (`setMask:` at `0x10465a98c`);
2. assigns the payload to `imageView` (`setImage:` at `0x10465a9bc`);
3. makes that image view visible (`setHidden: false` at `0x10465a9d4`);
4. updates its appearance through `0x10465b2b8`.

The other style branches clear the image mask and hide the image view. They include ordinary layer border-color paths. Thus a flat outline and an image-based outline both exist in this build. The case names and the runtime rules that choose them were not recovered.

### Filter values are linked to the outline

The lazy `saturationFilter` getter at `0x10465ab74` calls factory `0x10465abdc`. This factory constructs the string `CIColorControls`, calls `filterWithName:`, and sets:

| Input | Value | Evidence |
| --- | ---: | --- |
| `kCIInputSaturationKey` | 2.0 | `fmov d0, #2.0` at `0x10465ac4c`; NSNumber bridge; key pointer `0x1076d8a08`; `setValue:forKey:` at `0x10465ac6c` |
| `kCIInputBrightnessKey` | -0.1 | double bits `0xbfb999999999999a` at `0x10465ac8c`–`0x10465ac98`; key pointer `0x1076d89f0`; setter at `0x10465acb8` |

Import-table entries resolve both keys and the Double-to-NSNumber bridge. These are not guesses from nearby constants.

The outline appearance path calls `effectiveAppearance` at `0x10465b2d4`, passes the result to a helper, and uses that helper's Boolean to:

- choose image alpha **0.75 or 1.0** at `0x10465b360`–`0x10465b370`;
- choose whether to include the saturation filter in the image layer's filter list before `setFilters:` at `0x10465b4b4`.

The helper's exact light/dark mapping was not recovered. Do not label one of those values a dark-mode value without further proof.

### What this means

Direct proof: an image can supply the selected outline, with a shape mask and optional color adjustment. It is not limited to one average color.

Inference: this is consistent with the user's screenshot, where the Gmail tile rim has several favicon-like colors. An enlarged/soft image clipped to a rounded rim is a reasonable clean-room approximation.

Unknown: this pass does **not** prove that the assigned image is the raw favicon, that a Gaussian blur runs here, its radius, how the image is scaled, or how favicon transparency is filled. The image may have been processed upstream. `TabIconProcessorImpl` owns a `ciContext`, but that name alone does not prove the pipeline.

## Direct evidence: dock tile layout and motion

`TabSurface.TabDockView` stores:

- `maximumItemsPerRow`, `maximumNumberOfRows`;
- `minimumItemWidth`, `maximumItemWidth`, `itemHeight`;
- `interItemSpacing`, `contentInsets`;
- `itemStrokeWidth`, `itemHoverInset`, `itemCornerRadius`;
- `shouldAnimateItemLayout`, `hasCompletedInitialLayout`;
- `itemViews`, `dragDropState`, and placeholder drop-target geometry.

Its ObjC `layout` implementation is `0x105654f8c`, which forwards to `0x105654aa4`. That body reads and clears `shouldAnimateItemLayout`, passes it to `0x105654afc`, then marks `hasCompletedInitialLayout` true.

Within the layout helper, a flagged branch configures closure `0x105657be0` and calls the known NSAnimationContext wrapper `0x1008feb30` at `0x105654e10`. The thunk forwards to `0x105655220`.

The closure at `0x105655220`:

1. enables implicit animation at `0x105655254`;
2. constructs double `0x3fbeb851eb851eb8` = **0.12 seconds** and calls `setDuration:` at `0x105655270`;
3. loads import `0x1076d9410` = **kCAMediaTimingFunctionEaseOut**;
4. calls `CAMediaTimingFunction.functionWithName:` and then `setTimingFunction:`;
5. calls the tile's `setFrame:` at `0x1056552c8`;
6. calls `layoutSubtreeIfNeeded`.

Other branches set the frame directly or reuse an existing animation context. Thus 120 ms is a concrete **dock tile reflow code path**, not a guaranteed duration for every pin/unpin/drag operation.

This curve is the named Core Animation ease-out curve. Do not replace it in the report with the older tab-list study's custom cubic curve; they are distinct paths.

## Row arrangement: evidence boundary

The dock metadata proves configurable row/column limits and equal-size geometry inputs. This bounded pass did not reconstruct the full layout algorithm or recover the runtime limit values. In particular it does not independently prove `4 = 2+2` and `5 = 3+2`.

Use the user's explicit layout rule as the product specification:

| Count | Row sizes |
| ---: | --- |
| 1 | 1 |
| 2 | 2 |
| 3 | 3 |
| 4 | 2, 2 |
| 5 | 3, 2 |
| 6 | 3, 3 |

Each row should fill the available width. A final short row should stretch its tiles. Keep stable tab identity across row changes so a tile can move instead of being destroyed and inserted again.

## Implementation guidance

- Use one compact layout rule with stable identities. Keep the row computation separate from rendering.
- Start tile reflow at 120 ms ease-out, then verify on the virtual display. This is a static starting value, not a measured visual match.
- Keep the favicon crisp and centered. Put any enlarged or softened image in a separate clipped layer.
- A faithful reference option is an image-colored rim with a quiet tile fill. A softer alternative is a low-opacity image wash with a thin neutral rim. Label the latter as a Cove design option.
- If used, generate the favicon treatment when the favicon changes, not on each hover or selection. The static study does not establish Dia's cache policy.
- Test missing, transparent, monochrome and multicolor icons. The active state must remain clear without a usable image.

## Evidence files

All files are in `build/pinned-tabs-study/`:

- `dia-binary-identity.txt`
- `dia-pin-metadata-excerpts.txt` (original metadata line numbers retained)
- `dia-selection-outline-disassembly.txt`
- `dia-selection-outline-annotated.txt`
- `dia-dock-layout-disassembly.txt`
- `dia-dock-layout-annotated.txt`
- `dia-dock-animation-thunk.txt`
- `dia-dock-layout-animation-disassembly.txt`
- `dia-dock-layout-animation-annotated.txt`
- `dia-pin-import-proof.txt`
- `annotate-selectors.py` (local, reproducible Mach-O selector-stub annotation)
- `dia-pin-color-strings.txt` (initial search only; unlinked names, not proof)

The previous `build/tab-motion-study/dia-tab-timing-evidence.md` proves the reused animation wrapper's NSAnimationContext identity. The current dock timing and outline findings are new bounded traces against the same verified binary.
