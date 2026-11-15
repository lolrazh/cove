# Cove identity

A single soft coastline forms a C around an open, sheltered inlet. The broad shape and clear negative space are intended to work at small sizes.

`cove-mark-concept.png` is the flat black-on-white concept, generated with the built-in imagegen tool on 15 November 2026. It is the approved raster design study. The production SVG is a clean redraw of its silhouette; it does not retain the raster brush texture.

## Final generation prompt

A minimalist two-color logo on a pure white background. One single SOLID BLACK organic C-shaped mark in the center. The C resembles a sheltered bay viewed from above: thick rounded coastline surrounding an open white inlet, opening at the upper right. The upper arm extends slightly farther than the lower arm. Soft smooth curves, broad clean negative space. Flat black ink, like a clean SVG or a paper cutout. Absolutely no glow, no shadow, no gradients, no lighting, no texture, no colored haze, no 3D. Only black and white. No lettering or wordmark. Bold simple Swiss graphic design logo for the browser named Cove. One mark only, plenty of white margin. Wide square composition.

## Native app icon — 15 November 2026

- `icon-layers/cove-mark.svg`: clean white vector redraw of the approved silhouette.
- `icon-layers/painted-water.png`: generated paint texture, kept separate from the mark.
- `icon-experiments/index.html`: comparison of native exports, including 64 and 32 pixel previews.
- `icon-experiments/*.icon`: three editable Icon Composer documents: Lagoon, Tidal, and Painted water.
- `../../Cove/Resources/AppIcon.icon`: Tidal, the current build candidate.

The documents were created and checked in Apple's Icon Composer. The mark uses native Liquid Glass, with 30% translucency and a 28% neutral shadow. The painted background has glass and translucency disabled. The PNG previews were exported from Icon Composer with the Default appearance at 1024 points, 1x. They are review assets, not the build input. Xcode compiles the layered `.icon` document.

The blue-green base is sRGB (9, 123, 129). Lagoon uses a solid fill. Tidal uses Icon Composer's automatic gradient from that color. These are background experiments; the user has not yet selected a final background.

### Painted background generation prompt

Tool: built-in imagegen. Generated 15 November 2026.

Create a square edge-to-edge abstract painted background texture for a tiny macOS app icon. Blue-green sea colors: deep teal, lagoon turquoise, soft seafoam blue. A few broad loose brush strokes, as if a child confidently painted water with a wide brush, with slightly uneven handmade edges and very subtle paper/paint grain. Keep the middle quiet and fairly even in value so a white logo placed above it will read clearly. Tasteful, restrained, simple, charming, tactile. Flat overhead artwork, no perspective. Entire square filled with paint all the way to every edge. No white border, no rounded corners, no icon frame, no symbol, no C, no letters, no text, no waves drawn as outlines, no shadows or glass effects. This is ONLY the bottom background layer; Apple Icon Composer will apply the app icon shape and Liquid Glass effects separately.

### Apple workflow references

- https://developer.apple.com/icon-composer/
- https://developer.apple.com/videos/play/wwdc2025/361/

## Paint and glass revision — 15 November 2026

The first C retained a fully opaque white SVG fill. It had 30% native translucency, with blur material and refraction off. This made it look closer to a solid white object than glass.

Four new studies (`04` through `07`) use a separate glass foreground SVG with 55% white fill opacity. Native settings: 82% translucency, 12% blur material, 65% refraction strength, 45% depth, inside specular highlights, and an 18% neutral shadow. These are native Icon Composer material settings; no highlights are painted into the source SVG. The material was first configured in Icon Composer, then the saved JSON values were tuned for matched exports. Three fill-opacity trials (20%, 40%, 60%) were checked before selecting 55% for these studies.

- Sea glass: the original teal paint with the new foreground.
- Cobalt + mint: richer blue, turquoise, and mint paint.
- Coral + violet: coral, peach, lavender, and plum paint.
- Vivid tide: an editable SVG gradient with stops `#69E7C0`, `#078EAC`, and `#173D9B`.

The current production icon remains Tidal. These are options for the user to compare before choosing a replacement.

Exports use the `ictool` bundled inside Icon Composer, with platform `macOS`, rendition `Default`, design generation `27`, and scale `1`. Each new study has native renders at 1024, 56, and 32 pixels. The comparison page includes a light/dark backdrop control and the earlier versions. The page backdrop toggle is for contrast review; it does not switch the native icon rendition to Dark.

### New paint prompts

Tool: built-in imagegen, edit mode. Reference: `icon-layers/painted-water.png`. Outputs were saved in `icon-layers/` and copied into the corresponding native documents.

**Cobalt + mint**

Edit this painted texture into a richer palette: deep cobalt blue and ultramarine mixed with lagoon turquoise, with a few confident fresh mint green brush strokes. Preserve the broad handmade loose brush strokes and tactile fine paint grain of the reference. More contrast between the blue and mint areas, clearly visible color changes across the square, rich vibrant pigments but tasteful. No logo, no letters, no glass, no icon frame, no rounded corners. Full-bleed square background layer only. The paint has to look spontaneous and simple, like a child using a wide brush. Do not add small decorative objects or intricate patterns.

**Coral + violet**

Edit this painted texture into a warm and cool palette: rich coral and peach paint meeting saturated lavender violet and deep plum, with loose broad overlapping strokes. Preserve the handmade tactile fine paint grain and simple wide brush gestures of the reference. Let coral dominate upper left and violet lower right, with softly mixed pigment where they meet, asymmetrical and spontaneous. Richer contrast and more visible color variation than the reference, but tasteful. No logo, no letters, no glass, no icon frame, no rounded corners. Full-bleed square background layer only. As if a child confidently painted with a wide brush; avoid complex details.

## User material edits: Citrus Glass and Pearl

The user's edited Sea Glass has a pale yellow/lime gradient over teal paint. It is now saved exactly as received as `08-citrus-glass.icon`. Its JSON was not normalized or altered during the rename/copy operation.

The exact pre-edit Sea Glass document and preview are preserved under `icon-experiments/archive/04-sea-glass-original.*`. The current `04-sea-glass.icon` restores the original white color treatment and adopts the user's new material settings. Thus the archive preserves the original, while current Sea Glass stays consistent with the newer glass set.

Material settings from Citrus Glass are copied to current studies 04–07, including both foreground and background groups. Color fills, image references, and group names remain specific to each study. Current shared foreground values:

- Blur material: 0.1
- Lighting: combined
- Refraction: enabled, strength 0.8017578125, depth 0.21
- Shadow: layer-color, opacity 1
- Specular: true
- Translucency: enabled, value 0.75
- Blend mode: normal

`09-cobalt-pearl.icon` and `10-coral-pearl.icon` test a solid white layer fill with translucency reduced to 0.45. That is the intentional material difference; they retain the user's refraction, blur, lighting, specular, and shadow values. These are brighter white alternatives for comparison, not a replacement of the clearer painted studies.

All seven current studies (04–10) were rendered again with the native exporter at 1024, 56, and 32 pixels. The comparison page shows Citrus Glass, restored/current Sea Glass, the exact original, and paired clear/Pearl paint options. The production app icon remains unchanged.
