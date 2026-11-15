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
