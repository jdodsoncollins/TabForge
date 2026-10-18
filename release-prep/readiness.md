# App Store readiness

Updated October 18, 2026. **Build 11 is valid, attached to the App Store draft, and available to the existing internal TestFlight group. Listing, media, and privacy preparation are complete for owner review. Do not submit the app or creative assets for review.**

## Current state

| Item | Verified state | Still needed |
| --- | --- | --- |
| Candidate | Version 1.0 (11), iOS/iPadOS 27.0+, Duo APIs guarded for 27.1; archive/export, all 13 artifact checks and Apple binary validation passed | No binary gate remains in the recorded checks |
| Remote version | Prepare for Submission, manual release; build 11 attached and VALID; internal beta access and automatic notifications verified | Do not submit or release |
| Listing | Final locale fields read back exactly match canonical metadata; reviewer notes describe keyboard-local settings, no Full Access and temporary companion previews | Preserve the current facts when editing copy |
| Price and distribution | Free; all 175 current territories selected; automatic future territories disabled | No regional legal readiness or review approval is implied |
| App information | Developer Tools / Utilities, 4+ questionnaire, copyright and content-rights declaration saved | Preserve final values; private review contact/details are already saved |
| Platform availability | Mac and Vision Pro compatibility disabled and saved in the authenticated browser | No Mac/Vision keyboard functionality is advertised |
| Screenshots | All 31 current framed images COMPLETE with matching ordered source checksums; five Settings slides updated for build 11 and 26 retained | Owner review of the final gallery |
| Header | 3840 × 1646 image processed and assigned to the real App Store header placement; draft state rechecked | Keep it in draft; do not submit creative assets |
| Website policy | Current no-Full-Access revision deployed; canonical URL returns HTTP 200 and its live content matches keyboard-local storage and temporary previews | Preserve the verified URL and policy content |
| App Privacy | Data Not Collected published in the authenticated browser after explicit approval | Preserve the published declaration; this is separate from App Review submission |
| API readiness | Build 11 IPA and URL validation: zero errors, warnings, or blockers | The two informational results are intentional manual release and privacy publication being outside the public API; browser evidence verifies the latter |

Private receipts stay in ignored artifacts. Do not put account records, signing identifiers, private telephone numbers, or upload details into public documentation.

## Build 11 behavior

The keyboard **does not request Full Access or configure an App Group**. Its gear menu owns the installed keyboard's settings, snippets, and snippet creation/editing/deletion/reset. The extension saves these records only in its own local preferences container.

The companion app provides information, setup, licenses, credits, and the playground. Its keyboard/layout previews use a separate memory-only store; preview settings and snippets are discarded with that app process and do not configure the installed keyboard. The companion playground draft remains deliberately saved separately.

An unfinished snippet edit uses an isolated local buffer. Editing, deletion, selection, formatting, save and cancellation must not write the draft into the host document. Inserting a saved snippet is a separate user action. The update retains an existing keyboard-local record without reading, importing, or erasing older shared-container or companion preference records. Removing sharing does not promise that legacy data has been erased.

The source has no networking service, analytics, account system, remote spelling, or cloud speech fallback. Autocorrect and experimental code-vocabulary swipe remain opt-in. Voice recording belongs only to the companion app, requires on-device English recognition and user initiation, and stops on cancellation/backgrounding/interruption. Hosts and Apple system features retain their own data handling. See [PRIVACY.md](../PRIVACY.md), [DESIGN.md](../DESIGN.md), and [SECURITY.md](../SECURITY.md).

Both archived and exported app/extension privacy manifests match the current source: local UserDefaults reason `CA92.1`, no collected-data entries, no tracking, and no tracking domains. The former shared-container reason is absent.

## Current automated evidence

- **Core:** all 83 methods across nine suites passed for the current revision.
- **Phone hosted:** 79 methods passed: 21 XCTest and 58 Swift Testing methods.
- **iPad and Duo hosted:** the full suites passed 77 methods each with no failures, skips, or runtime warnings. After the final weak-reference/cancelled-control and Dynamic Type snippet cleanup, nine focused methods produced 15 passing executions on each device, with no failures, skips, or runtime warnings.
- **Phone UI:** the initial combined run exercised 15 methods, with two intentional device/pose skips and three harness failures. The harness issues were fixed and the affected flows passed focused reruns. The final largest-text settings and snippet save/insert run passed both methods. The original invocation was terminated after test completion while emitting package-graph messages; it is not recorded as a successful command.
- **Media capture:** all three native capture tests passed for the current Settings images.
- **Regression scope:** keyboard-local persistence and existing-record retention, memory-only previews, independent stores, snippet-draft isolation, save/cancel while keys are held, stale cancelled controls, Unicode/limits, and settings/snippet accessibility.

Build 11 is archived and exported. All **13 artifact checks passed**: versions/minimum OS/device families, signatures and identifier consistency, absence of signed App Group entitlements, absence of a Full Access request, current privacy manifests and API reasons, exact bundled MIT/notices, light/dark/tinted icon renditions, Apple-only direct runtime dependencies, and no shipped tests or embedded third-party frameworks. Apple server binary validation also passed. Separate remote readbacks confirm successful processing, draft attachment, internal beta testing, and access for the existing all-builds internal group. They do not establish App Review approval.

The no-sharing source is [published under the MIT license](https://github.com/jdodsoncollins/TabForge/commit/9c8dc83e10af08a591ce35b4d3b536645a8af6d7). Its [public CI run passed](https://github.com/jdodsoncollins/TabForge/actions/runs/39140923632). The generated public project keeps symbolic signing configuration; private signing overrides and release receipts remain ignored.

The historical build 9 baseline passed 83 core methods plus 68 hosted and two phone UI methods. Build 10 passed its 12 archive/export checks and focused companion-attribution UI checks. Those dated results supplement build 11's current evidence. See [verification](../docs/verification.md).

## Listing, media and policy consistency

The listing must describe the keyboard's gear as the place to configure the installed keyboard and manage snippets. Do not reuse claims about optional Full Access, App Group synchronization, or companion controls configuring the extension. The canonical [description](copy/description-en-US.txt) and [review notes](copy/review-notes-en-US.txt) are the copy sources; private contact fields remain outside this directory.

Screenshots use genuine Simulator frames and synthetic text. The final set covers two phone export sizes, two iPad export sizes, and closed/open/tabletop Duo layouts. Five Settings slides were replaced for build 11 after their replacements finished processing; 26 original images were retained. All 31 images are COMPLETE, and remote order and source checksums match the local set. The assigned product-page header remains a draft. The local review gallery and download package were rebuilt with these current images. Use [Apple's screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) and [creative-asset specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications). A device-frame composition does not prove physical-device behavior.

The App Store policy URL is [jeremycollins.net/tabforge-privacy-policy](https://www.jeremycollins.net/tabforge-privacy-policy). The no-Full-Access, keyboard-local-storage, memory-only-preview revision is deployed to production. A fresh HTTP 200 response and live content check verified the current revision. README, repository privacy documentation, and support guidance describe the same data flow.

The published [support page](https://github.com/jdodsoncollins/TabForge/blob/main/docs/SUPPORT.md) provides the explicitly approved public support contact and private security-reporting route. Recheck public README/support/privacy links after the source documentation update. Do not expose the separately approved private App Review contact values.

**Data Not Collected is published.** The owner explicitly approved both the App Store privacy declaration and the website policy publication. The authenticated browser then confirmed the published declaration. The [Apple privacy guidance](https://developer.apple.com/app-store/app-privacy-details/) distinguishes on-device processing from collection; browser evidence establishes questionnaire publication separately from the archive manifest or public-API validator.

## Owner review

The completed listing, 31 screenshots, header, and local review package are prepared for owner review. Preserve manual release and Prepare for Submission. No app or creative-asset review submission has been made.

The final read-only build 11 IPA/URL validator reports **zero errors, zero warnings, and zero blockers**. Its two informational entries identify intentional manual release and the privacy publication state that the public API cannot verify. The authenticated browser independently confirms the published privacy declaration. These checks do not attest to contracts, trader declarations, or other regional/account obligations beyond the fields inspected here.

Physical multitouch and edge/palm behavior, assistive-technology typing, microphone/system Dictation, real terminal/Remote Desktop forwarding, full Duo posture coverage, and sustained extension memory-pressure recovery remain separate device checks. No test can promise immunity from iOS terminating a keyboard extension.
