# TabForge icon family

Created with the built-in image-generation tool, then revised at Jeremy’s request to reduce the bevel by about 90%. All nine keycaps fit inside the icon mask; the outer source image is square and opaque. The center brace key retains TabForge’s lime accent in Light and Dark.

Final assets (1024 × 1024 PNG):
- `App/Assets.xcassets/AppIcon.appiconset/AppIcon.png` — Light / Any.
- `App/Assets.xcassets/AppIcon.appiconset/AppIcon-Dark.png` — Dark.
- `App/Assets.xcassets/AppIcon.appiconset/AppIcon-Tinted.png` — neutral grayscale for system tinting.

The generated 1254-pixel masters were copied to `artifacts/qa/icon-sources/` and downsampled with macOS sips. The tinted export was normalized to a grayscale ICC color space; its decoded RGB channel difference is exactly zero. No Python image editing was used. None of the assets contains alpha. The catalog supplies the `luminosity` appearance values `dark` and `tinted`.

## Prompt set

Master: “Create ONE polished production iOS app icon master for TabForge, a developer keyboard. Square 1024 by 1024 full-bleed opaque RGB artwork; NOT a mockup, no device, no outer border, do NOT pre-round the outside square (iOS applies its own icon mask). Design a beautiful modern precision-made section of a keyboard seen perfectly straight down, symmetric 3 by 3 grid of EXACTLY NINE complete rounded-square keycaps. All nine keycaps and their subtle shadows must fit comfortably inside the central 78 percent of the square so nothing is cut off even by an iOS superellipse mask. Equal-size keycaps, consistent generous gutters, large clean monospaced legends. Exact glyph arrangement: top row '[' then ']' then '/'; middle row '<' then '{}' then '>'; bottom row Tab arrow '⇥' then Command symbol '⌘' then Return arrow '↵'. The central '{}' key is the sole restrained soft chartreuse/lime accent (#BFE58B) and establishes a memorable code identity. Other eight keys are warm porcelain white, glyphs deep graphite green. Full square background is a refined pale cool gray (#E4E8E7). Subtle tactile ceramic key surfaces, tiny bevels and short soft shadows, premium native Apple-adjacent product craft, crisp vector-like typography and disciplined geometry; avoid toy-like gloss, neon, excessive gradients, tilted perspective, drop shadow outside the whole icon, branding text, or any cropped/partial keys. The result should remain legible and distinctive at tiny home-screen icon sizes.”

Dark edit: preserve the master’s exact nine-key composition; use background #111719, eight graphite-slate caps #293438, off-white legends, and the original lime center with charcoal braces. Preserve all glyphs, masks and margins.

Tinted edit: preserve the master’s exact composition; use strictly neutral grayscale, near-black background, charcoal caps, silver/white legends, and a lighter silver central brace key with near-black braces, suitable for the system’s selected tint.

Final revision applied separately to all three generated variants: “Refine this exact app icon as requested: MUCH LESS BEVEL. Preserve all nine complete keys, their exact 3x3 arrangement, sizes, glyphs, colors, center '{}' emphasis, margins and square framing. Flatten the keycaps into sleek modern low-profile keys: reduce the original bevel and extrusion by about 90 percent. Flat matte top faces, no domed or pillowed surfaces, no raised inset lip, no thick sidewalls, no glossy rounded edges. Only an almost imperceptible 1–2 pixel edge and a very short soft shadow to distinguish each key from the background. Use clean restrained native UI geometry, rounded-square key shapes, and precise dark/light legends exactly as in the input. Preserve this input's palette exactly, including strict neutral grayscale if the input is grayscale. No outer rounded mask, no crops, no added objects. Opaque square production app-icon art.”

## Verification

`assetutil` confirms the default, `UIAppearanceDark`, and `ISAppearanceTintable` renditions. Simulator Home Screen customization visibly uses the expected icon in Default, Dark, Tinted Light and colored Tinted Dark modes. Captures: `artifacts/qa/icon-home-light.jpg`, `icon-home-dark.jpg`, `icon-home-tinted.jpg`, `icon-home-colored-tint.jpg`. The simulator was restored to Default afterward.

## Reference

[Apple: configuring an app icon using an asset catalog](https://developer.apple.com/documentation/xcode/configuring-your-app-icon).

## Outer-corner refinement — October 17, 2026

At Jeremy’s request, the four corner keycaps now use a broader continuous curve on their outward-facing corner, following the iOS icon contour. The `[` upper-left, `/` upper-right, Tab lower-left and Return lower-right corners are more curved; inward-facing corners retain the tighter keycap radius. The nine-key arrangement, restrained bevel, readable symbols and lime center are retained.

The built-in image-generation tool edited the Light master first. Dark and Tinted then used that revised geometry as their edit target and the previous respective assets as palette references. The exact [prompt set](icon-corner-radius-prompts.json) records all three calls. Generated masters are preserved in `artifacts/qa/icon-corner-radius/{Light,Dark,Tinted}-master.png`, with the previous production assets under `before/`.

The three production PNGs at the asset paths above were updated, downsampled to 1024 × 1024 with macOS sips, and kept opaque. The tinted export uses a grayscale ICC profile. No Python image editing was used. The source and compiled asset metadata confirm RGB Light/Dark, Monochrome Tinted, three opaque 1024-pixel renditions and the expected appearance names. The simulator build/install/launch passes. Fresh asset metadata is saved in `artifacts/qa/icon-corner-radius/asset-info.json`; the Home Screen screenshots in the earlier verification section predate this corner refinement. This corner refinement is included in TestFlight build 1.0 (8). The release IPA retains all three opaque appearance renditions for both phone and pad, verified in `artifacts/testflight/asset-info-8.json`; no new Home Screen appearance check is claimed.
