# App Store readiness

Updated October 21, 2026. Version 1.0 (12) is live on the App Store. Version 1.0.1 (14), with the optional companion Tip Jar, is available to the existing internal TestFlight group. Its App Store version is an unsubmitted draft. Build 14 adds Paper & Grain to Other Apps. Its final archive/export and all 24 artifact checks passed, and its upload is committed. Apple processed build 14 as VALID, internal TestFlight access is verified and successful staging attached it to version 1.0.1.

## Candidate state

| Item | Evidence | Remaining release work |
| --- | --- | --- |
| Build 14 candidate | Final signed archive/export and all 24 artifact checks passed; Apple processing is VALID; existing automatic all-builds internal TestFlight access and notes are verified; staging attached build 14 to version 1.0.1 | Complete real sandbox/device checks and remaining release gaps |
| Historical build 13 | Signed archive/export and all 21 artifact checks passed; Apple processing and internal TestFlight access were verified | Superseded in the App Store draft by build 14 |
| Review draft | Six unsubmitted items contain the app and all five consumables; US base prices are $0.99 through $4.99 with English metadata, review screenshots and matching territory availability | Check real sandbox catalog and remaining release gaps before submission |
| Copy and URLs | Version 1.0.1 draft metadata/reviewer notes and canonical Marketing/Privacy Policy URLs read back exactly; build 14 staging applied updated metadata; testing notes are saved; local field-limit audit passes | Preserve the prepared copy and verified URLs |
| Media | All 31 screenshots and all three 16-second App Previews are COMPLETE; preview MD5 checksums match; one header placement is inherited | Preserve the verified media |
| Website | Canonical product and privacy pages return HTTP 200; the live policy still describes build 12 and the product page says there are no in-app purchases | Publish the matching policy and update the product-page statement before the Tip Jar release, then verify live content |
| App Privacy | Data Not Collected is published; current source review supports retaining it | Recheck if the final binary changes data flow |
| Price and access | App stays Free; all keyboard and companion features work without a purchase or TabForge account | Preserve those values; updated agreement acceptance remains unconfirmed |

Private receipts remain in ignored artifacts. Do not put account records, signing identifiers, private telephone numbers or upload details into public documentation. These entries describe release preparation, not Apple approval.

## Candidate checks

On October 21, `swift test` passed all 88 tests in ten suites and the build-configuration suite passed all five Python tests. Their source is unchanged by the later companion edits. Neither suite runs a purchase or accesses a developer account.

Phone and iPad passed 15 mock-store methods and the native StoreKit lifecycle checks for prices, repeat purchases and deferred approval. Their complete Tip Jar UI runs passed, including strict landscape orientation and corrected full-screen navigation. The final two Other Apps phone cases passed at normal and largest accessibility text after the canonical URL change. All three app links were reachable with targets at least 44 points in both dimensions, and captures were reviewed. Native purchase/UI suites use the opt-in **ScriptKeyboard-Tips** scheme and serial test plan; the normal scheme excludes them and has no StoreKit configuration in its Run action.

The final focused Duo standard Tip Jar run passed all five displayed prices, two repeated local tips and Back navigation; its largest-text case passed earlier. Apple's local native checkout stalled, so the full Duo suite is not counted as passing. Actual Duo landscape/pose verification remained unavailable because Device Hub was locked. These limits are separate from the passed UI paths.

The final signed build 14 archive/export passed all 24 artifact checks, including the compiled canonical URLs, absence of the old privacy route and companion-only Paper & Grain artwork. Apple processed build 14 as VALID and reports internal beta testing. Existing automatic all-builds internal TestFlight access and build 14 notes are verified. The strict TestFlight validator reports zero errors, warnings, informational results or blockers. Independent source review found no material production defect. Version 1.0.1 has an unsubmitted six-item review draft for the app and five tips, with build 14 attached by the successful staging operation.

Local StoreKit tests use synthetic purchases and do not validate the remote catalog or real sandbox payments. Real TestFlight sandbox/device purchases remain unverified. Physical VoiceOver interaction, real-finger typing and swipe accuracy, terminal forwarding and sustained memory-pressure recovery remain separate device checks.

## Current behavior

The keyboard **does not request Full Access or configure an App Group**. Its gear menu owns the installed keyboard's settings, snippets, and snippet creation/editing/deletion/reset. The extension saves these records only in its own local preferences container.

The companion app provides information, setup, licenses, credits, and the playground. Its keyboard/layout previews use a separate memory-only store; preview settings and snippets are discarded with that app process and do not configure the installed keyboard. The companion playground draft remains deliberately saved separately.

An unfinished snippet edit uses an isolated local buffer. Editing, deletion, selection, formatting, save and cancellation must not write the draft into the host document. Inserting a saved snippet is a separate user action. The update retains an existing keyboard-local record without reading, importing, or erasing older shared-container or companion preference records. Removing sharing does not promise that legacy data has been erased.

The source has no TabForge-operated network service, analytics, account system, remote spelling or cloud speech fallback. The optional Tip Jar uses Apple's StoreKit service in the companion app only. Autocorrect and experimental English/code-word swipe remain opt-in. Swipe uses a bundled offline dictionary; it does not use Apple QuickPath or record gestures for learning. Voice recording belongs only to the companion app, requires on-device English recognition and user initiation, and stops on cancellation/backgrounding/interruption. Hosts and Apple system features retain their own data handling. See [PRIVACY.md](../PRIVACY.md), [DESIGN.md](../DESIGN.md), and [SECURITY.md](../SECURITY.md).

Build 12’s archived and exported privacy manifests match source: local UserDefaults reason `CA92.1`, no collected-data entries, no tracking and no tracking domains. The former shared-container reason is absent. The actual signed app and extension entitlements contain no App Group entitlement; a provisioning profile’s unused capability allowance does not grant the app that entitlement.

## Live build 12 evidence

- **Core:** all 88 methods across ten suites passed.
- **Hosted UIKit:** 94 methods / 198 executions per device passed on phone, iPad and Duo before the final small review fixes.
- **Final focused swipe checks:** 19 methods / 24 executions per device passed on phone, iPad and Duo after all review fixes, with no failures or skips. These checks describe the build 12 source.
- **Build configuration:** five Python checks passed.
- **Regression scope:** synthetic swipe paths and word coverage, cancellation, layout changes, repeated-word menus, native-editor callbacks and stale alternatives after cursor scrubbing.

These tests use synthetic text and gestures. They do not measure real-finger recognition, cold extension latency, peak device memory or survival under memory pressure. See [verification](../docs/verification.md) for benchmark scope and remaining device checks.

Build 12 is archived and exported, and all **19 artifact checks passed**. Apple processed the uploaded build as VALID. Internal all-builds TestFlight access and exact testing notes were verified. The TestFlight validator reports zero errors, warnings, informational results or blockers. Version 1.0 (12) is now live on the App Store.

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

The keyboard gear menu owns settings and snippets for the installed keyboard. Companion previews stay in memory. The [description](copy/description-en-US.txt) preserves the approved feature facts and adds optional Apple-operated tips. The [reviewer notes](copy/review-notes-en-US.txt) explain the five first consumables and state that no purchase or TabForge account is required. [What's New](copy/whats-new-en-US.txt) and [TestFlight guidance](copy/testflight-build13-en-US.txt) describe version 1.0.1. The Humanizer 3.1.0 pass removed unnecessary framing without changing feature claims. Name, subtitle, keywords, promotional text and existing image copy remain unchanged. Local validation is separate from saving and reading back remote metadata.

Screenshots use genuine Simulator frames and synthetic text. The established set covers two phone export sizes, two iPad sizes and closed/open/tabletop Duo layouts. Build 12 receipts verified all 31 images COMPLETE in order with matching remote MD5 checksums. Version 1.0.1 now inherits all 31 screenshots in COMPLETE state and one header placement. All three 16-second App Previews are COMPLETE, and their remote MD5 checksums match local files. Use [Apple's screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) and [creative-asset specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications). A frame composition does not prove device behavior.

The canonical [privacy policy](https://www.jeremycollins.net/tabforge/privacy) and [product page](https://www.jeremycollins.net/tabforge) return HTTP 200. The product page still says there are no in-app purchases, which matches live build 12 but must change before the Tip Jar release. The privacy page’s October 18 text still describes build 12, says swipe uses an included coding vocabulary and has no Tip Jar section. The [prepared policy](copy/privacy-policy-en-US.md) corrects that vocabulary statement and explains Apple's network/payment infrastructure, local transaction handling, bounded in-memory deduplication and the absence of a TabForge purchase backend or saved receipt/history. Publish the matching revision before the App Store release and check the live result. These canonical pages are a separate website surface; this local draft does not change their published content. The Marketing URL now uses the product page; GitHub remains the source and Support URL.

The published [support page](https://github.com/jdodsoncollins/TabForge/blob/main/docs/SUPPORT.md) contains the approved public support contact and private security-reporting route. Recheck README, support and privacy links when the source documentation is published. Keep separately saved App Review contact values private.

### App Privacy assessment

**Data Not Collected remains appropriate for the reviewed implementation.** Apple's [App Privacy guidance](https://developer.apple.com/app-store/app-privacy-details/) defines collection as off-device transmission that gives the developer or third-party partners access beyond servicing a request. It excludes on-device processing and inaccessible payment details entered outside the app, and says developers are not responsible for disclosing data collected by Apple. StoreKit returns product and transaction results locally; this app sends no transaction data to a backend or analytics service and saves no receipt, purchase history or tip total. The bounded transaction-ID set stays in memory. Apple's own transaction records and account/payment processing are described in [App Store & Privacy](https://www.apple.com/legal/privacy/data/en/app-store/).

The declaration was previously published with explicit owner approval. The review above supports retaining it; it is not an exemption for future server validation, transaction analytics or other customer-data collection. Source privacy manifests and public API validators do not themselves prove that a questionnaire is published.

## Submission boundaries

The owner previously authorized publication and review of the initial release. Build 11 was withdrawn and build 12 replaced it, was approved and is now live. The current request is to prepare the Tip Jar update for submission and verify the new App Preview. Build 13 is uploaded and internally testable. Build 14 has a validated archive/export, VALID processing, verified internal TestFlight access and a successful stage result attaching it to version 1.0.1. The App Store review draft contains six unsubmitted items for the app and five tips. No App Review submission or new policy publication has occurred for this update; updated account-agreement acceptance is unconfirmed.

Before submitting, verify real sandbox catalog behavior, matching live website content, updated agreement status, privacy answers, private reviewer contact and release behavior. Preserve the verified artifact, media and saved draft metadata. Full Duo native checkout and landscape/pose checks remain incomplete. The first consumable purchases must accompany the new app version in one submission, as described in [Apple's submission guide](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase/). Account agreements and other regional obligations require their own current checks.

Physical multitouch and edge/palm behavior, assistive-technology typing, microphone/system Dictation, real terminal/Remote Desktop forwarding, full Duo posture coverage and sustained extension memory-pressure recovery remain separate device checks. No test can promise immunity from iOS terminating a keyboard extension.
