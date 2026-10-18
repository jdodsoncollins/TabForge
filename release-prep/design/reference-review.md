# TabForge listing design reference review

Reviewed 18 October 2026. This is a direction for TabForge's release artwork; the other apps' artwork is reference material only and is not copied into this repository.

## References inspected

I inspected the finished Codable App Store gallery, the finished Taktung listing contact sheet, and one full-size Taktung phone slide. These were scoped reads of existing marketing images, not application records or source data.

| Reference | Existing visual language | TabForge should differ by |
| --- | --- | --- |
| Codable | Pale blue and navy; strong blue emphasis in heavy sans-serif headings; blue ribbon-like curves; tilted devices; floating white detail cards; small uppercase category labels | Warm neutral fields, one acid-lime accent, upright real keyboard details, a quieter serif headline, no ribbons or floating cards |
| Taktung | Cool pale gray and near-black; teal labels and slide numbers; large heavy sans-serif titles; a centered full phone beneath the headline; restrained device hardware frames | Keyboard-first composition, no sequence numbers, no teal, no repeated full-phone template, typography that does not resemble the existing headline treatment |

Changing only the colors would leave TabForge too close to those listings. The stronger distinction is the subject: the keyboard occupies most of the useful image area. The final user direction requires complete genuine Simulator device frames in every image; keyboard detail insets keep the keys readable.

## Direction: an everyday programming instrument

Use warm chalk, graphite and the lime of the app icon. Keep surfaces flat. The design should feel like a well-set page in a programming handbook, with an authentic working keyboard as its main illustration.

- Background: warm chalk `#F2F0E9`; alternate dark slide `#21251F`.
- Main ink: `#20261F`; secondary ink: `#555D50`.
- Accent: pale lime `#D4E9A5`, with darker olive `#3B4C2F` for text when needed. Lime is a highlight, not a full-page glow.
- Rules: a muted warm gray such as `#D7D9CD`, used sparingly to align annotations.
- Headlines: a restrained serif, preferably the system New York or Iowan Old Style. A rendered Georgia fallback is acceptable. Use regular/medium weight with generous line spacing; avoid bold condensed display type.
- Labels and small copy: Menlo or system monospaced text. Prefer sentence case. Reserve monospaced uppercase for a very small product identifier if one is needed.
- Native UI: preserve captured app fonts and colors. Do not restyle screenshots to match the marketing typography.

Do not bundle system font files. Rendering installed system fonts into the final artwork does not require adding those files to the project.

## Composition rules

The main phone image uses a complete genuine Simulator frame. Editing and theme images pair device context with a labeled real keyboard detail. The final user direction also requires actual Duo closed, open and tabletop chassis views.

Use two or three composition types across the set: a close keyboard view, an editing demonstration, and a wider real-device layout. Give the real UI room to breathe rather than repeating the same centered device eight times.

If a detail is enlarged, label it as a keyboard detail. Keep its source capture and crop rectangle so the result remains auditable. Do not create synthetic UI or move keys to places the app does not put them. Keep the full hardware frame and every featured key intact. The only removed pixels are plain window exterior outside the device.

In the screenshots, use the actual current app icon without a new bevel, an ornamental key cloud, or an AI-generated keyboard. Avoid gradients, abstract ribbons, particles, giant quotation marks, stacked floating cards, excessive shadows, and pill-shaped marketing badges. The separate product-page header is brand artwork, with its source prompt recorded in [header-prompt.md](header-prompt.md).

## Writing guardrails

Lead with visible functions: braces, Tab, arrows, Escape, profiles, themes and public source. A useful short sentence beats an abstract benefit claim.

Use straightforward headlines and natural sentences. Do not split a list into a sequence of one-word sentences or add punctuation to make ordinary feature names sound like slogans. The approved headline is “A keyboard for writing code,” not a stylized list of key names.

Avoid “unlock,” “supercharge,” “seamless,” “revolutionary,” “AI-powered,” “built for the way you work,” and unsupported claims about productivity, touch accuracy, memory survival, unrestricted swipe typing or compatibility with every app. Do not use “zero data” or “nothing is stored”: preferences, snippets and the playground draft are saved locally.

The keyboard cannot synthesize arbitrary hardware key events. Use “Terminal · ANSI profile” and explain client forwarding in the listing description. Voice input belongs to the companion app. Experimental swipe is not a lead screenshot claim. Prose correction is optional, English-only and field-dependent.

## Verification before staging

The screenshot pipeline and size-validation skills were read for this review. Exact accepted slots and dimensions must be queried from the installed `asc` CLI rather than inferred from the reference apps. Use current real captures, preserve aspect ratios, render opaque sRGB images, and validate the finished files for each supported device slot.

This review does not establish physical-device behavior or App Store approval. Header artwork is separate from the screenshot set. The release-readiness review confirmed Apple's 3840 × 1646 product-page header specification; see [readiness.md](../readiness.md) and [Apple's creative-asset specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications).
