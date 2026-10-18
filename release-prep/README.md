# App Store release preparation

The initial English listing is prepared under `copy/`. The artwork source and reproducible composition tools are under `design/`. `readiness.md` records the scope of the release checks and the remaining human and physical-device checks.

The current local copy describes the no-Full-Access revision: keyboard-local settings/snippets, no App Group, and memory-only companion previews. The changed description, reviewer notes, support/privacy documents and affected captures must be synchronized with a verified matching binary before distribution. [Website-ready policy text](copy/privacy-policy-en-US.md) is prepared for the existing public policy address; preparing it does not publish or deploy the website.

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

Metadata, processed assets, and a validated build can be assigned to an editable version without submitting it to App Review. The initial preparation deliberately leaves the version unsubmitted and configures manual release. It does not accept account agreements, invent contact details, choose a price without the owner's answer, or certify hardware testing that has not occurred.

Use the final private readiness receipt to check the live draft before a future submission. Public copy files are release inputs, not proof of current remote state or Apple approval.
