# App Store release preparation

The initial English listing is prepared under `copy/`. The artwork source and reproducible composition tools are under `design/`. `readiness.md` records the scope of the release checks and the remaining human and physical-device checks.

Version 1.0 (12) is live on the App Store. Version 1.0.1 (14) adds an optional companion Tip Jar and Paper & Grain in Other Apps. Its signed archive/export passed all 24 artifact checks, and final normal/largest-text Other Apps phone checks passed after the URL update. Apple processed build 14 as VALID; existing automatic all-builds internal TestFlight access, testing notes and the clean strict TestFlight validation are verified. Direct readback confirms build 14 selected in the unsubmitted version 1.0.1 draft. Its six review items contain the app and five configured consumables; metadata and reviewer notes match the prepared copy. Earlier build 13 evidence is retained in [readiness.md](readiness.md).

The updated listing preserves the approved feature description and adds a short explanation of optional tips. New What's New, TestFlight guidance and reviewer notes are prepared under `copy/`. The requested Humanizer 3.1.0 pass covered these edits. Name, subtitle, keywords, promotional text and existing screenshot captions are unchanged. The copy validator checks the 1.0.1 field limits locally; it does not save metadata to App Store Connect.

The source still keeps keyboard settings and snippets in the extension, with no Full Access or App Group. Companion previews stay temporary. StoreKit is confined to the companion app. The privacy review supports retaining Data Not Collected because transaction processing stays local and the app has no purchase backend, upload or transaction analytics. The matching [website policy draft](copy/privacy-policy-en-US.md) adds Apple's payment handling and corrects the bundled swipe vocabulary description. That policy update has not been published. The canonical [product page](https://www.jeremycollins.net/tabforge) and [privacy page](https://www.jeremycollins.net/tabforge/privacy) return HTTP 200, but the product page still says there are no in-app purchases and the live privacy text has no StoreKit section. Update both website statements before releasing the Tip Jar version. These website pages are separate from this repository; editing the local draft does not publish them. All 31 inherited screenshots are COMPLETE. All three 16-second App Previews are COMPLETE with matching remote MD5 checksums. One header placement was inherited. See [readiness.md](readiness.md) for current evidence and release steps.

The screenshot renderer uses real simulator captures with measured crop rectangles. It does not redraw the application interface. Device frames come from installed Apple Simulator resources or real Device Hub captures; partially opened geometry comes from the actual Device Hub pose. Selected optimized composites are published with the README. Original captures, Apple frame source files, private App Store records, signing resources, IPA/archive files, and upload receipts stay in the ignored `artifacts/` directory.

The six images cover programming keys, indentation, terminal controls, themes, available screen space, and the inspectable source. Phone and tablet exports use different canvas dimensions while preserving the captured UI's aspect ratio. Duo open, closed, and partially opened views share one App Store screenshot slot, so its final upload selection must contain no more than ten images combined.

The separate product-page header is brand artwork. Its prompt is retained in `design/header-prompt.md`.

## Reproduce the artwork

1. Run the opt-in `AppStoreCaptureTests` on the intended simulator with `TABFORGE_STORE_SHOTS=1`.
2. Export the screenshot and geometry attachments with `xcresulttool export attachments`.
3. Use the extraction utility under `design/` to construct the raw capture manifest, then inspect all measured crops.
4. Follow `design/renderer.md` to render the opaque PNG exports and review gallery.
5. Validate each chosen family with `asc screenshots validate` before staging it.
6. After verifying the selected build, create the review-only ZIP with `python3 release-prep/package-preview.py --build-number <validated-build>`. It includes listing artwork, public copy and companion previews, and excludes private release records and binaries.

Read the capture provenance before reusing a set. A composition can reuse a real UI capture proportionally at another product-page canvas size; that does not establish a separate device test. Keep those two claims distinct.

## Staging is separate from submission

Metadata, processed media and a validated build can be assigned to an editable version before App Review. The live version 1.0 (12) was approved after its October 18 submission. Version 1.0.1, its first consumable purchases and new App Previews need their own final readiness checks and review submission. Updated agreement acceptance is not yet confirmed; live website statements still need to match the release. The owner has requested release preparation. This documentation edit does not submit, publish or accept an account agreement.

Check the private remote receipts for the latest state. Public copy files are release inputs, not evidence that Apple has processed media or approved a build.
