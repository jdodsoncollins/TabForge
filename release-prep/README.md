# App Store release preparation

The initial English listing is prepared under `copy/`. The artwork source and reproducible composition tools are under `design/`. `readiness.md` records the scope of the release checks and the remaining human and physical-device checks.

Version 1.0 (12) is live on the App Store. Version 1.0.1 (15) and its five consumable tips were submitted on October 21, 2026. The version, parent review and each tip are WAITING_FOR_REVIEW, with release type AFTER_APPROVAL. Build 15 remains VALID and available to the existing internal TestFlight group. Scene-aware Apple purchase presentation passed 22 focused simulator checks, and all 24 archive/export checks passed. Exact testing notes, listing metadata and reviewer notes match the saved copy. Submission succeeded with zero blockers; strict TestFlight and post-submission purchase validation have no issues. See [readiness.md](readiness.md) for exact evidence and remaining physical-device checks.

The updated listing preserves the approved feature description and adds a short explanation of optional tips. New What's New, TestFlight guidance and reviewer notes are prepared under `copy/`. The requested Humanizer 3.1.0 pass covered these edits. Name, subtitle, keywords, promotional text and existing screenshot captions are unchanged. The copy validator checks the 1.0.1 field limits locally; it does not save metadata to App Store Connect.

Keyboard settings and snippets remain in the extension, with no Full Access or App Group. Companion previews stay temporary and StoreKit stays in the companion app. The public Data Not Collected label was freshly verified. The canonical [product page](https://www.jeremycollins.net/tabforge) and October 21 [privacy policy](https://www.jeremycollins.net/tabforge/privacy) are published and freshly verified HTTP 200. They describe optional Apple-operated tips, all features remaining free, fixed English/programming vocabularies, payment handling, bounded in-memory deduplication and no TabForge backend, upload or purchase history. The reviewed [policy copy](copy/privacy-policy-en-US.md) is retained here. All 31 inherited screenshots and three 16-second App Previews are COMPLETE; preview MD5 checksums match local files. One header placement was inherited.

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

Metadata, processed media and a validated build can be assigned to an editable version before App Review. The live version 1.0 (12) was approved after its October 18 submission. Version 1.0.1 (15), its first five consumables and new App Previews were submitted on October 21; the review is pending and approval has not been granted. Release after approval is configured. No legal agreement was accepted during this submission.

Check the private remote receipts for the latest state. Public copy files are release inputs, not evidence that Apple has processed media or approved a build.
