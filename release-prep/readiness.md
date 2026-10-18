# App Store readiness

Updated October 18, 2026. **Build 11 is the current source candidate; preparation is still in progress. Do not submit the app or creative assets for review.** Build 10 remains the last confirmed valid, attached internal beta. Earlier build 9/10 checks do not establish that the new storage/settings revision is release-ready.

## Current state

| Item | Verified state | Still needed |
| --- | --- | --- |
| Candidate | Source/project version 1.0 (11), iOS/iPadOS 27.0+, Duo APIs guarded for 27.1 | Final regressions, archive/export, artifact audit, Apple validation, upload/processing and attachment |
| Remote version | Prepare for Submission, manual release; build 10 attached and VALID | Replace with the verified build 11; repeat final read-only validation |
| Listing | Draft description and reviewer notes updated for keyboard-local settings, no Full Access and temporary companion previews | Pull back final metadata after all changes and check against build 11 |
| Price and distribution | Free; all 175 current territories selected; automatic future territories disabled | No regional legal readiness or review approval is implied |
| App information | Developer Tools / Utilities, 4+ questionnaire, copyright and content-rights declaration saved | Preserve final values; private review contact/details are already saved |
| Platform availability | Mac and Vision Pro compatibility disabled and saved in the authenticated browser | No Mac/Vision keyboard functionality is advertised |
| Screenshots | Original 31 framed images were COMPLETE with matching ordered source checksums | Replace the five Settings slides with current build 11 UI, then verify final processing/order/checksums |
| Header | Processed and assigned to the real App Store header placement | Keep it in draft; do not submit creative assets |
| Website policy | The policy URL is saved and publicly reachable | Deploy and verify the prepared no-Full-Access revision; the live page may still describe old sharing |
| App Privacy | Data Not Collected saved as a browser draft | Publication remains blocked pending explicit user approval |

Private receipts stay in ignored artifacts. Do not put account records, signing identifiers, private telephone numbers, or upload details into public documentation.

## Build 11 behavior to verify

The keyboard **does not request Full Access or configure an App Group**. Its gear menu owns the installed keyboard's settings, snippets, and snippet creation/editing/deletion/reset. The extension saves these records only in its own local preferences container.

The companion app provides information, setup, licenses, credits, and the playground. Its keyboard/layout previews use a separate memory-only store; preview settings and snippets are discarded with that app process and do not configure the installed keyboard. The companion playground draft remains deliberately saved separately.

An unfinished snippet edit uses an isolated local buffer. Editing, deletion, selection, formatting, save and cancellation must not write the draft into the host document. Inserting a saved snippet is a separate user action. The update retains an existing keyboard-local record without reading, importing, or erasing older shared-container or companion preference records. Removing sharing does not promise that legacy data has been erased.

The source has no networking service, analytics, account system, remote spelling, or cloud speech fallback. Autocorrect and experimental code-vocabulary swipe remain opt-in. Voice recording belongs only to the companion app, requires on-device English recognition and user initiation, and stops on cancellation/backgrounding/interruption. Hosts and Apple system features retain their own data handling. See [PRIVACY.md](../PRIVACY.md), [DESIGN.md](../DESIGN.md), and [SECURITY.md](../SECURITY.md).

The source privacy manifest now declares local UserDefaults reason `CA92.1`, with no collected-data entries, tracking, or tracking domains. The former shared-container reason is removed. The final archive must be checked against this source rather than the old build 9/10 manifest.

## Current automated evidence

- **Core:** all 83 methods across nine suites passed for the current revision.
- **Hosted:** 77 methods passed on iPad Pro 11-inch M5 / iPadOS 27.0 and 77 on Duo / iOS 27.1, with no failures, skips, or runtime warnings. These full runs preceded the final weak-reference/cancelled-control and Dynamic Type snippet cleanup. Focused reruns of that cleanup are pending.
- **Phone:** the combined hosted/UI regression run is still in progress under the UI agent's ownership. Do not report it as complete until its final result bundle is recorded.
- **New regression coverage:** keyboard-local persistence and existing-record retention, memory-only previews, independent stores, snippet-draft isolation, save/cancel while keys are held, stale cancelled controls, Unicode/limits, and settings/snippet accessibility. Final runtime results must match the final source.

The current candidate has **not yet been archived or uploaded**. Before treating build 11 as ready, verify app and extension versions/minimum OS/device families, signatures and profiles, absence of signed App Group entitlements, absence of a Full Access request, both privacy manifests, current bundled licenses/notices and icon variants, and absence of shipped tests or unexpected runtime dependencies. Regenerate from public `project.yml`; keep private signing overrides out of the generated project.

The historical build 9 baseline passed 83 core methods plus 68 hosted and two phone UI methods. Build 10 passed its 12 archive/export checks and focused companion-attribution UI checks. Those dated results remain useful baseline evidence but are not a substitute for build 11's new storage and snippet-routing checks. See [verification](../docs/verification.md).

## Listing, media and policy consistency

The listing must describe the keyboard's gear as the place to configure the installed keyboard and manage snippets. Do not reuse claims about optional Full Access, App Group synchronization, or companion controls configuring the extension. The canonical [description](copy/description-en-US.txt) and [review notes](copy/review-notes-en-US.txt) are the copy sources; private contact fields remain outside this directory.

Screenshots use genuine Simulator frames and synthetic text. The existing set covers two phone export sizes, two iPad export sizes, and closed/open/tabletop Duo layouts. Five Settings slides are being replaced for build 11; the remaining original media and assigned header are preserved. Size acceptance and completed upload are distinct from current-UI accuracy and final ordering. Use [Apple's screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) and [creative-asset specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications). A device-frame composition does not prove physical-device behavior.

The App Store policy URL is [jeremycollins.net/tabforge-privacy-policy](https://www.jeremycollins.net/tabforge-privacy-policy). The no-Full-Access, keyboard-local-storage, memory-only-preview revision is prepared locally but **not yet verified as deployed**. An earlier HTTP 200 does not prove that its content reflects build 11. Keep this pending flag until an actual deployment receipt and live semantic check confirm the update. The repository privacy policy already documents the new behavior.

The published [support page](https://github.com/jdodsoncollins/TabForge/blob/main/docs/SUPPORT.md) provides the explicitly approved public support contact and private security-reporting route. Recheck public README/support/privacy links after the source documentation update. Do not expose the separately approved private App Review contact values.

**Data Not Collected remains saved, not published.** Earlier automatic approval review rejected the Publish action. Explicit user approval is still pending; do not retry, bypass, or treat the saved draft as publication. The [Apple privacy guidance](https://developer.apple.com/app-store/app-privacy-details/) distinguishes on-device processing from collection, but a local manifest or successful public-API validator does not publish the questionnaire.

## Completion gates

1. Record the final phone regression and focused cleanup reruns; resolve any failures before archiving.
2. Archive/export build 11, audit the actual no-sharing entitlements and resources, pass Apple binary validation, upload/process, attach the validated build, and verify internal testing access. Keep manual release and Prepare for Submission.
3. Finish the five Settings-image replacements and verify all final media's processing, order, source checksums, accepted sizes, and crop safety.
4. Deploy and verify the prepared website policy, publish/synchronize source documentation, and pull back the final listing/review notes.
5. Only after explicit approval, publish App Privacy and verify the published state. Do not submit the app or assets for App Review.
6. Repeat read-only `asc validate` with the final build 11 IPA and URL checks. Report public-API results separately from browser-only privacy publication and any account/regional obligations not verified here.

Physical multitouch and edge/palm behavior, assistive-technology typing, microphone/system Dictation, real terminal/Remote Desktop forwarding, full Duo posture coverage, and sustained extension memory-pressure recovery remain separate device checks. No test can promise immunity from iOS terminating a keyboard extension.
