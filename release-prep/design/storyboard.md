# TabForge App Store storyboard

Prepared 18 October 2026. Six images tell the core story for phones and tablets. The shared Duo slot uses seven selected images to include real closed, open and tabletop poses. The first three must work on their own in the store's preview strip. All featured interfaces must be captured from the current app using synthetic examples.

The current source no longer requests Full Access or shares preferences with the companion app. Keyboard settings and snippets are managed inside the installed keyboard; the companion keyboard and layout guide are explicitly temporary previews. Replace captures that show old companion keyboard controls or omit the current preview labels. The source/privacy slide should show the companion's information and links, not imply that it configures the installed keyboard. Earlier processed screenshot receipts describe the older UI.

## Shared layout

Use the warm chalk/graphite/lime direction in [reference-review.md](reference-review.md). Let the keyboard take 55–70% of the visual area on a typical portrait slide. Headlines and captions should remain readable at thumbnail size. Keep most slides to a headline and one brief caption.

Keep complete genuine Simulator device frames in every image. Do not stretch a phone capture into an iPad or Duo canvas. Capture each layout at the right size, then compose within the accepted screenshot dimensions. A detail crop is fine when it includes complete keys and has an honest source capture. The first image in every device set should immediately show the keyboard that device receives.

## Screenshot set

| # | Headline | Supporting copy | Capture and composition |
| --- | --- | --- | --- |
| 1 | A keyboard for writing code | Keep braces, brackets and Tab within reach. | Warm chalk. A large real keyboard with its dedicated punctuation row, Tab and toolbar clearly visible. Include a small area of the native playground with a short synthetic function. Use the actual phone, iPad or Duo layout for that set. Use a whole genuine device frame, with a real key detail where needed. |
| 2 | Indent without leaving the keys | Indent or outdent a line and keep your place. | Warm chalk. Native playground with a short, readable multi-line code block and the keyboard below. Enlarge a complete indent/outdent key pair as a precisely labeled keyboard detail if the base capture is too small. Show a real selection or cursor state; do not fabricate a before/after animation. |
| 3 | Keep terminal controls close | Use Escape, arrows and modifiers from the keyboard. | Graphite. Show the actual dark keyboard toolbar and a little code above it. The glyphs remain native. Include a plain caveat: terminal shortcuts depend on the client forwarding them. For compact landscape, show the real Fn layer instead of pretending the full toolbar is always visible. |
| 4 | Choose your keyboard theme | Follow the iOS appearance or choose a code palette. | Warm chalk. Pair three complete genuine device frames with large captured keyboard detail strips for standard light/dark and Darcula. No invented palette swatches or UI. Label the actual theme names. |
| 5 | Make room for your work / Use the space you have | A compact landscape layout leaves more space for your app. / A larger layout makes room for numbers, symbols and editing keys. | Warm chalk. Device-specific adaptation: phone landscape with compact rows; full iPad with expanded keys; Duo with actually captured closed, open and tabletop poses. Use the same short synthetic code across captures. Avoid an unsupported promise that the keyboard controls the host's final placement. Duo-specific features require iOS 27.1. |
| 6 | See how your keyboard works | Read the MIT licensed source, privacy policy and security guidance. | Graphite. Real app settings showing the repository/privacy/security links. A small plain-text `github.com/jdodsoncollins/TabForge` may appear if it remains readable. Do not use a padlock illustration or imply a security audit. Explain that the keyboard has no analytics or typed-text logging and that preferences, snippets and the playground draft stay on device. |

The copy can be adjusted to fit after reviewing real captures. If a long caption competes with the keyboard, shorten the caption rather than shrinking the UI.

## Device-specific adaptations

- **Phone portrait:** keep complete punctuation and modifier controls readable; do not devote most of the image to an empty code editor.
- **Phone landscape:** show the compact keyboard on a landscape canvas or as a labeled wide detail. The real Fn layer demonstrates the height tradeoff honestly.
- **iPad:** use the larger layout and more visible code. Scale the keyboard for readability, not to imitate a phone. Leave the actual safe areas intact.
- **Duo open:** show the wider real layout. Use a separate capture for the closed layout if needed.
- **Duo tabletop:** use an actual pose capture if the simulator and host expose it reliably. If not captured, omit the pose claim from the artwork and document the gap; never draw a fictional laptop keyboard state.

“All device types” here means the iPhone, iPad and Duo families supported by the app and current App Store Connect slots. TabForge has no Apple Watch, Apple TV, Mac or Vision Pro app to illustrate.

## Header image

Create header artwork separately from the screenshot set. The release-readiness review confirmed the current App Store product-page header specification of 3840 × 1646 px, opaque PNG or JPEG. This is brand artwork; screenshots continue to use real UI. The final header prompt and processing notes are in [header-prompt.md](header-prompt.md).

- App Store export: 3840 × 1646 px, opaque sRGB. A separate social crop may be exported with safe margins if useful.
- Left: actual TabForge icon, product name and one line: **A keyboard for writing code**.
- Right/bottom: one upright close-up of the genuine punctuation and navigation keys, comfortably within the edge. Keep complete key faces visible.
- Background: warm chalk. A single fine olive rule can align the headline and keyboard detail.
- Optional small line: **An open-source keyboard for iPhone and iPad.**
- Do not add an App Store badge before an approved public product link exists. Do not put private TestFlight information, device identifiers or release records in the artwork.

## Capture examples

Use short synthetic source such as a function that formats a list. Avoid real repositories, hostnames, emails, account names, secrets, terminal output from a personal machine and private snippets. Where a terminal profile is shown, capture its real menu in TabForge; do not style the companion playground as a third-party terminal app.

## Release review

Review the set as thumbnails and at full size. Confirm key labels are uncut, UI text is readable, crops are proportional, theme names match the app, and all statements match [DESIGN.md](../../DESIGN.md) and [PRIVACY.md](../../PRIVACY.md). Preserve raw capture provenance and validate opaque PNG/JPEG dimensions with `asc screenshots validate` before any upload. The user asked for a prepared listing and a review in the thread, with no submission for review.
