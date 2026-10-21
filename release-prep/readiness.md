# App Store readiness

Updated October 18, 2026. **Version 1.0 (12) is available to the existing internal TestFlight group and was submitted to Apple on October 18, 2026. The version and its product-page header both read back as Waiting for Review. The app is Free and will release automatically after approval.**

The earlier build 11 submission was withdrawn and replaced with build 12. Apple has not approved the new submission.

## Current state

| Item | Verified state | Still needed |
| --- | --- | --- |
| Release build | Version 1.0 (12), iOS/iPadOS 27.0+, Duo APIs guarded for 27.1; archive/export and all 19 artifact checks passed; Apple processing returned VALID | Apple review approval remains pending |
| Remote version | Build 12 attached to version 1.0 and Waiting for Review; internal all-builds group access and exact TestFlight notes verified | Release automatically after approval |
| Listing | Build 12 description and reviewer notes read back exactly; promotional text, name, subtitle and keywords retained from the earlier Humanizer pass | Preserve the verified copy |
| Price and distribution | Free; all 175 current territories selected; automatic future territories disabled | No regional legal readiness or review approval is implied |
| App information | Developer Tools / Utilities, 4+ questionnaire, copyright and content-rights declaration saved | Preserve final values; private review contact/details are already saved |
| Platform availability | Mac and Vision Pro compatibility disabled and saved in the authenticated browser | No Mac/Vision keyboard functionality is advertised |
| Screenshots | All 31 framed images COMPLETE in the expected order; remote MD5 checksums match local files recorded in the SHA manifest; Humanizer review required no copy changes | Preserve the verified media |
| Header | 3840 × 1646 image assigned to the App Store header placement and Waiting for Review with build 12; Humanizer review required no copy change | Apple review approval remains pending |
| Website policy | Current no-Full-Access revision deployed; canonical URL returns HTTP 200 and its live content matches keyboard-local storage and temporary previews | Preserve the verified URL and policy content |
| App Privacy | Data Not Collected published in the authenticated browser after explicit approval | Preserve the published declaration; this is separate from App Review submission |
| API readiness | Build 12 IPA/URL readiness: zero errors, warnings or blockers; TestFlight validation: zero errors, warnings, informational results or blockers | App Store readiness retains one informational entry because the public API cannot verify privacy publication; earlier browser evidence verifies it |

Private receipts stay in ignored artifacts. Do not put account records, signing identifiers, private telephone numbers, or upload details into public documentation.

## Current behavior

The keyboard **does not request Full Access or configure an App Group**. Its gear menu owns the installed keyboard's settings, snippets, and snippet creation/editing/deletion/reset. The extension saves these records only in its own local preferences container.

The companion app provides information, setup, licenses, credits, and the playground. Its keyboard/layout previews use a separate memory-only store; preview settings and snippets are discarded with that app process and do not configure the installed keyboard. The companion playground draft remains deliberately saved separately.

An unfinished snippet edit uses an isolated local buffer. Editing, deletion, selection, formatting, save and cancellation must not write the draft into the host document. Inserting a saved snippet is a separate user action. The update retains an existing keyboard-local record without reading, importing, or erasing older shared-container or companion preference records. Removing sharing does not promise that legacy data has been erased.

The source has no networking service, analytics, account system, remote spelling, or cloud speech fallback. Autocorrect and experimental English/code-word swipe remain opt-in. Swipe uses a bundled offline dictionary; it does not use Apple QuickPath or record gestures for learning. Voice recording belongs only to the companion app, requires on-device English recognition and user initiation, and stops on cancellation/backgrounding/interruption. Hosts and Apple system features retain their own data handling. See [PRIVACY.md](../PRIVACY.md), [DESIGN.md](../DESIGN.md), and [SECURITY.md](../SECURITY.md).

Build 12’s archived and exported privacy manifests match source: local UserDefaults reason `CA92.1`, no collected-data entries, no tracking and no tracking domains. The former shared-container reason is absent. The actual signed app and extension entitlements contain no App Group entitlement; a provisioning profile’s unused capability allowance does not grant the app that entitlement.

## Build 12 source checks

- **Core:** all 88 methods across ten suites passed.
- **Hosted UIKit:** 94 methods / 198 executions per device passed on phone, iPad and Duo before the final small review fixes.
- **Final focused swipe checks:** 19 methods / 24 executions per device passed on phone, iPad and Duo after all review fixes, with no failures or skips. Runtime sources match build 12; only the project build number changed afterward.
- **Build configuration:** five Python checks passed.
- **Regression scope:** synthetic swipe paths and word coverage, cancellation, layout changes, repeated-word menus, native-editor callbacks and stale alternatives after cursor scrubbing.

These tests use synthetic text and gestures. They do not measure real-finger recognition, cold extension latency, peak device memory or survival under memory pressure. See [verification](../docs/verification.md) for benchmark scope and remaining device checks.

Build 12 is archived and exported, and all **19 artifact checks passed**. Apple processed the uploaded build as VALID. Internal all-builds TestFlight access and exact testing notes were verified. The TestFlight validator reports zero errors, warnings, informational results or blockers. Apple review approval remains pending.

## Historical build 11 evidence

- **Core:** all 83 methods across nine suites passed for build 11.
- **Phone hosted:** 79 methods passed: 21 XCTest and 58 Swift Testing methods.
- **iPad and Duo hosted:** the full suites passed 77 methods each with no failures, skips, or runtime warnings. After the final weak-reference/cancelled-control and Dynamic Type snippet cleanup, nine focused methods produced 15 passing executions on each device, with no failures, skips, or runtime warnings.
- **Phone UI:** the initial combined run exercised 15 methods, with two intentional device/pose skips and three harness failures. The harness issues were fixed and the affected flows passed focused reruns. The final largest-text settings and snippet save/insert run passed both methods. The original invocation was terminated after test completion while emitting package-graph messages; it is not recorded as a successful command.
- **Media capture:** all three native capture tests passed for the current Settings images.
- **Regression scope:** keyboard-local persistence and existing-record retention, memory-only previews, independent stores, snippet-draft isolation, save/cancel while keys are held, stale cancelled controls, Unicode/limits, and settings/snippet accessibility.

Build 11 was archived and exported. All **13 artifact checks passed**: versions/minimum OS/device families, signatures and identifier consistency, absence of signed App Group entitlements, absence of a Full Access request, current privacy manifests and API reasons, exact bundled MIT/notices, light/dark/tinted icon renditions, Apple-only direct runtime dependencies, and no shipped tests or embedded third-party frameworks. Apple server binary validation also passed. Separate remote readbacks confirm successful processing, draft attachment, internal beta testing, and access for the existing all-builds internal group. They do not establish App Review approval.

The no-sharing source is [published under the MIT license](https://github.com/jdodsoncollins/TabForge/commit/9c8dc83e10af08a591ce35b4d3b536645a8af6d7). Its [public CI run passed](https://github.com/jdodsoncollins/TabForge/actions/runs/39140923632). The generated public project keeps symbolic signing configuration; private signing overrides and release receipts remain ignored.

The historical build 9 baseline passed 83 core methods plus 68 hosted and two phone UI methods. Build 10 passed its 12 archive/export checks and focused companion-attribution UI checks. Those dated results supplement build 11’s historical evidence. See [verification](../docs/verification.md).

## Listing, media and policy consistency

The listing must describe the keyboard's gear as the place to configure the installed keyboard and manage snippets. Do not reuse claims about optional Full Access, App Group synchronization, or companion controls configuring the extension. The canonical [description](copy/description-en-US.txt) and [review notes](copy/review-notes-en-US.txt) are the copy sources; private contact fields remain outside this directory.

Screenshots use genuine Simulator frames and synthetic text. The final set covers two phone export sizes, two iPad export sizes, and closed/open/tabletop Duo layouts. Five Settings slides were replaced for build 11 after their replacements finished processing; 26 original images were retained. For the build 12 submission, all 31 images were verified COMPLETE in the expected order. Their remote MD5 checksums match the local files recorded in the SHA manifest. The assigned product-page header read back as Waiting for Review with the updated version. The local review gallery and download package use these images; image copy needed no change in the Humanizer pass. Use [Apple's screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) and [creative-asset specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications). A device-frame composition does not prove physical-device behavior.

The App Store policy URL is [jeremycollins.net/tabforge-privacy-policy](https://www.jeremycollins.net/tabforge-privacy-policy). The no-Full-Access, keyboard-local-storage, memory-only-preview revision is deployed to production. A fresh HTTP 200 response and live content check verified the current revision. README, repository privacy documentation, and support guidance describe the same data flow.

The published [support page](https://github.com/jdodsoncollins/TabForge/blob/main/docs/SUPPORT.md) provides the explicitly approved public support contact and private security-reporting route. Recheck public README/support/privacy links after the source documentation update. Do not expose the separately approved private App Review contact values.

**Data Not Collected is published.** The owner explicitly approved both the App Store privacy declaration and the website policy publication. The authenticated browser then confirmed the published declaration. The [Apple privacy guidance](https://developer.apple.com/app-store/app-privacy-details/) distinguishes on-device processing from collection; browser evidence establishes questionnaire publication separately from the archive manifest or public-API validator.

## Submission

The owner approved the listing and artwork, requested a final Humanizer pass, and authorized publication and review. Humanizer 3.1.0 was installed globally from [blader/humanizer](https://github.com/blader/humanizer/commit/8c307f367c91bd974002f10f2be2965d642c13df). Build 11’s description, promotional text and reviewer guidance were previously saved and read back exactly.

The build 12 copy describes the bundled English dictionary and programming words while keeping swipe optional and experimental. The updated description and reviewer notes were saved and read back exactly. Promotional text, name, subtitle and keywords remain unchanged from the earlier Humanizer pass. All 31 screenshot captions plus the header also received the requested pass; the image copy required no changes.

The build 11 submission was withdrawn, and its submission record reached COMPLETE. Build 12 was then attached to version 1.0 and submitted on October 18, 2026. Both the updated version and linked header read back as Waiting for Review. The app remains Free, with release type AFTER_APPROVAL. Apple must approve the submission before it can become available.

The build 12 IPA/URL readiness validator reports **zero errors, zero warnings and zero blockers**, with one informational entry: the public API cannot verify App Privacy publication. Earlier authenticated-browser evidence confirms the published Data Not Collected declaration. These checks do not attest to contracts, trader declarations or other regional/account obligations beyond the fields inspected here.

Physical multitouch and edge/palm behavior, assistive-technology typing, microphone/system Dictation, real terminal/Remote Desktop forwarding, full Duo posture coverage, and sustained extension memory-pressure recovery remain separate device checks. No test can promise immunity from iOS terminating a keyboard extension.
