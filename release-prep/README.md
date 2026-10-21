# App Store release preparation

The initial English listing is prepared under `copy/`. The artwork source and reproducible composition tools are under `design/`. `readiness.md` records the scope of the release checks and the remaining human and physical-device checks.

Build 12 improves optional offline swipe recognition with a bundled English dictionary and programming words. Its archive/export and all 19 artifact checks passed, and Apple processing returned VALID. Access for the existing internal TestFlight group and exact testing notes were verified. The source checks passed 88 core methods, five build-configuration checks and final focused swipe checks of 19 methods / 24 executions on each of phone, iPad and Duo. See [readiness.md](readiness.md) for scope and physical-device limits.

The listing and image copy received the requested Humanizer 3.1.0 pass. The updated description and reviewer notes match build 12’s swipe vocabulary and read back exactly. Promotional text, name, subtitle and keywords are unchanged from the earlier pass; the 31 screenshot captions and header needed no changes. Keyboard settings and snippets remain local to the extension, with no Full Access or App Group; companion previews remain temporary.

Build 11’s earlier submission was withdrawn and replaced with build 12. Version 1.0 (12) and its linked header were submitted on October 18, 2026 and both read back as Waiting for Review. The app remains Free with release after approval. The [privacy policy text](copy/privacy-policy-en-US.md) and approved Data Not Collected disclosure are published. Apple approval remains pending.

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

Metadata, processed assets, and a validated build can be assigned to an editable version without submitting it to App Review. The initial preparation left the version unsubmitted for owner review. The owner subsequently approved the content and authorized publication and review. The build 11 submission was withdrawn, and build 12 was submitted with release after approval. No account agreement was accepted, private contact invented, or unperformed hardware check certified.

Use the final private submission receipts to check the current review state. Public copy files are release inputs, not proof of current remote state or Apple approval.
