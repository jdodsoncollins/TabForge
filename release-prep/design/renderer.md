# Screenshot renderer

The final release uses `render-framed-screenshots.mjs`. It keeps complete genuine device frames in every image. The older `render-screenshots.mjs` is the archived frameless composition workflow; its first artwork set is preserved under the ignored `frameless-v1` artifact folder.

```sh
node release-prep/design/render-framed-screenshots.mjs --preview --family iphone-medium --slide 1
node release-prep/design/render-framed-screenshots.mjs
node release-prep/design/export-readme-images.mjs
node release-prep/design/render-review.mjs
```

The framed renderer requires macOS, an installed iOS Simulator device profile/chrome library, Poppler's `pdftocairo`, Node, Playwright and Sharp. `--chrome-root` and `--device-types` override the installed resource roots. Apple PDF originals are rasterized only into ignored local working files, never copied into the public repository.

Phone and tablet feature screens use unchanged native captures inside Apple's real Simulator corners and straight bezel sections. Straight edges adapt to the captured display dimensions; the corners retain their original geometry. A native camera-island cutout is retained where the legacy profile sensor PDF is empty. Portrait and landscape use the correct orientation of the same captured phone frame.

Duo closed, open, tabletop and Terminal scenes use actual Device Hub chassis captures. The partially opened hardware is never drawn or inferred. Additional real theme and Settings UI captures are proportionally placed inside the same real flat-open chassis, using a display outline measured from the native frame. Render receipts distinguish these compositions from whole-window pose captures.

`device-cutout.mjs` removes only edge-connected white exterior around the dark hardware boundary. It preserves opaque interior pixels and converts the one-pixel exterior antialias fringe to transparency. The finished marketing canvas is opaque warm chalk. The README exports contain the same complete native device figures without marketing headlines.

`render-review.mjs` treats `screenshots/framed-render-receipt.json` as authoritative, so an older unselected image cannot leak into the final gallery. The shared Duo slot has seven distinct selected images in `duo-selection.json`: closed, open, tabletop, indentation, terminal, themes and source settings. It remains below Apple's ten-image cap. Final images have an asset manifest with dimensions, hashes, composition provenance and exact selected file paths.

## Archived frameless workflow

`render-screenshots.mjs` composes genuine simulator captures with HTML/CSS, then renders opaque PNGs with Playwright. It does not generate or redraw application UI. Installed system fonts are rendered into the artwork; no font files are copied.

Run from the repository root with Node 22+ and the `playwright` and `sharp` packages. Scripts first resolve ordinary local Node packages, then an available bundled desktop runtime. Set `TABFORGE_NODE_MODULES` to explicitly select a `node_modules` directory. `--chromium /path/to/chromium` or `TABFORGE_CHROMIUM` can select an installed headless browser when the Playwright package and cached browser revisions differ. The verified local tooling used Playwright 1.62.1 and Sharp 0.35.5; both are Apache-2.0 tooling dependencies and are not linked into the app.

```sh
node release-prep/design/render-screenshots.mjs --preview --family iphone-medium --slide 1
node release-prep/design/render-screenshots.mjs
```

Internal layout-only previews may use `--preview --placeholders`. That watermark and explicit capture-pending panel cannot be used in final output. A normal run fails if a genuine capture or crop is missing.

## Raw capture manifest

Use `extract-captures.mjs` after exporting the capture test's attachments with `xcresulttool`. It finds the named PNG attachments and the `capture-geometry` JSON, converts XCTest screen points to pixel crops, verifies proportional scale, and records source hashes and original geometry. Ordinary captures are copied byte for byte. If an EXIF rotation makes the displayed image match the captured window while the encoded raster does not, it preserves the original under `raw/<family>/originals/` and applies a lossless orientation normalization. This rearranges existing pixels without resizing, interpolation or generated content; both hashes and the transform are recorded.

```sh
node release-prep/design/extract-captures.mjs \
  --attachments artifacts/app-store-release-2026-10-18/attachments/iphone-medium \
  --family iphone-medium \
  --source-result artifacts/app-store-release-2026-10-18/captures-iphone.xcresult
```

The settings capture initially uses the complete real screen because its exported geometry does not include individual source-link row frames. Inspect it and pass a measured `--crop-overrides <json>` before rendering final artwork. Override JSON uses `{ "families": { "iphone-medium": { "settings": { "detail": { "x": 0, "y": 0, "width": 100, "height": 100 } } } } }` with actual source-pixel rectangles.

`--reuse-for iphone-large` explicitly reuses one family as proportional frameless UI for another output size and records the original source family. It never fabricates another device shape. Prefer dedicated native captures when available.

`--captures compact` updates only a fresh compact attachment and its provenance while preserving the other family entries. This supports a focused screenshot recapture. The original exported attachments remain untouched.

Geometry can be an aggregate `captures` array or per-frame `{ "capture": { ... } }` attachments. The extractor deduplicates identical records and rejects conflicting geometry for a named frame. A five-frame Duo run can use `--captures standard,dark,darcula,terminal,settings` because its adaptive screenshot uses the real expanded layout.

Default location: `artifacts/app-store-release-2026-10-18/raw/manifest.json`. File paths are relative to that manifest and must remain inside `raw/`.

```json
{
  "families": {
    "iphone-medium": {
      "standard": {
        "file": "iphone-medium/standard.png",
        "keyboard": {"x": 0, "y": 1400, "width": 1206, "height": 1100},
        "working": {"x": 0, "y": 1000, "width": 1206, "height": 1500}
      },
      "dark": {"file": "iphone-medium/dark.png", "keyboard": {"x": 0, "y": 1400, "width": 1206, "height": 1100}},
      "darcula": {"file": "iphone-medium/darcula.png", "keyboard": {"x": 0, "y": 1400, "width": 1206, "height": 1100}},
      "compact": {"file": "iphone-medium/compact.png", "keyboard": {"x": 0, "y": 500, "width": 2622, "height": 600}},
      "settings": {"file": "iphone-medium/settings.png", "detail": {"x": 0, "y": 1000, "width": 1206, "height": 1200}}
    }
  }
}
```

The example bounds are illustrative, not capture evidence. Every actual rectangle must be measured in the original image's pixels. Preserve complete keycaps; include the full toolbar when relevant. `working` is optional and defaults to the keyboard plus a bounded strip above it. The app settings `detail` rectangle must show the actual source/privacy/security area. The archived workflow requires real source captures for each featured state. A compact state may be portrait when it is explicitly selected through the app preference; only a source whose recorded window orientation is landscape may be captioned as landscape.

Supported family IDs: `iphone-medium`, `iphone-large`, `ipad-13`, `ipad-11`, `duo-closed`, `duo-open`. The requested export dimensions are encoded in the renderer. Device slot labels must be checked against the current ASC CLI before staging; a local output directory does not establish App Store acceptance.

The manifest can override local output slot labels with a top-level `"slots"` map keyed by family ID. Use that to record the current ASC slot mapping after validating it.

The open Duo export uses the accepted landscape transposition, 2853 × 2007 px, so its full-width keyboard remains readable. Its native capture is normalized only for EXIF orientation and composed proportionally. The closed Duo export stays 1398 × 2034 px.

Final output: `artifacts/app-store-release-2026-10-18/screenshots/en-US/<slot>/01.png` through `06.png`. Both Duo layouts map to `APP_IPHONE_DUO`, with filenames prefixed `duo-open-` and `duo-closed-` to preserve both local sets. Select at most ten combined images before staging that slot; the twelve local outputs are a review pool, not an upload batch. Preview HTML is self-contained and preserves source/crop metadata. A render receipt records dimensions, alpha presence, source manifest, and bounds checks. Inspect the outputs visually and run `asc screenshots validate` for the chosen slots before staging.

`render-review.mjs` generates a clickable `index.html`, an all-family `previews/contact-sheet.png`, and a readable three-column `previews/iphone-contact-sheet.png` from the final images currently present. Run it after rendering to refresh the thread-review artifacts. It describes proportional capture reuse explicitly, marks the selected Duo upload images, includes the product-page header when present, and writes hashes for every final asset to `screenshots/asset-manifest.json`.
