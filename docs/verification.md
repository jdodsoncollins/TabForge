# Verification and known limits

This is a public summary of local checks, not an independent security audit. Source changes do not update an installed App Store or TestFlight binary. Raw device inventories, signing/upload records, captures, and result bundles stay in ignored artifacts; published tests use synthetic text.

## Build 12 swipe and release evidence, October 18, 2026

Build 12 adds a bundled offline English dictionary, endpoint indexing, key-pitch normalization, bounded elastic reranking, and gesture/replacement invalidation. Swipe remains opt-in and experimental. [Research and remaining evaluation](swipe-engine-research-2026-10-17.md) and [dictionary provenance](swipe-lexicon.md) explain the scope and data license.

The original `testing` → `typeof` report reproduced with a synthetic path through key centers. The old dictionary did not contain `testing`. The regression now returns `testing`, and a rounded `status` path that initially returned `statues` now returns `status`.

- Full core package: **88 methods in ten suites pass**, including the four-geometry/four-path-style swipe matrix and rejection of poor paths with matching endpoints.
- Shared UIKit suites passed on phone, iPad and Duo: **94 methods / 198 executions per device**, with no failures or skips, before the last small review changes.
- Final focused swipe checks after all review fixes: **19 methods / 24 executions per device**, with no failures or skips. These cover repeated-word menus, native-editor replacement callbacks and stale alternatives after cursor scrubbing. They invoke the shared renderer with synthetic gestures; they do not exercise physical touches. Tested runtime sources match build 12; the build number changed from 11 to 12 afterward.
- Both the companion app and embedded keyboard contain the exact generated English resource.
- Build-configuration Python suite: **five tests pass**.
- Dictionary: 38,604 English forms, 343,537 bytes; its SHA-256 matches the documented generated resource.

The signed build 12 archive and exported IPA pass all 19 artifact checks, including exact dictionary copies and notices in the app and extension, signatures, privacy manifests, light/dark/tinted icons and packaging. Signed bundles have no App Group entitlement and do not request Full Access. An unused provisioning-profile allowance is not a signed app entitlement.

Apple processed build 12 as VALID. Its internal TestFlight group has access, and the What to Test notes read back exactly. App Store version 1.0 now has build 12 attached and is Waiting for Review, along with its linked header. This replaces the earlier build 11 submission at the owner's request. The updated description and reviewer notes match the final local copy; all 31 retained screenshots are COMPLETE with matching ordered source checksums. Humanizer 3.1.0 was applied to the listing and image copy; no image wording required a change.

Build 12 IPA and public-URL readiness checks report zero errors, warnings or blockers, plus one informational result because the public API cannot verify privacy publication. Earlier authenticated-browser evidence verifies the published Data Not Collected disclosure. The TestFlight validator reports no issues. The app remains Free with release after approval configured; Waiting for Review does not mean approved.

The fixed public benchmark uses 97 mixed words, of which 95 occur in the new vocabulary. It also checks ten repeated-letter fixtures separately. The table shows the rounded-corner/jitter subset, with identical synthetic traces before and after; it does not measure accuracy on real fingers.

| Synthetic proportions | Original top one / top three | Revised top one / top three |
| --- | --- | --- |
| Original regression geometry | 36 / 36 of 97 | 90 / 93 of 97 |
| Phone portrait | 36 / 36 of 97 | 92 / 94 of 97 |
| Phone landscape | 35 / 36 of 97 | 88 / 89 of 97 |
| iPad full width | 36 / 36 of 97 | 92 / 93 of 97 |
| Duo open | 36 / 36 of 97 | 92 / 94 of 97 |
| Duo tabletop | 36 / 36 of 97 | 92 / 94 of 97 |

The revised dense-center traces return the intended first candidate for 93–94 of 97 words and include it in the first three for all 95 covered words. `username` and `localhost` are outside the bundled vocabulary. Repeated-letter and collinear-path ambiguities remain; alternatives can help, and tap typing remains necessary for some identifiers.

An optimized development-Mac run sampled 101 warm decodes per geometry. Medians were 1.03–1.42 ms and p95 values 4.01–5.29 ms. One decoder construction took 24.8 ms after the benchmark had already read the dictionary for coverage; this is not a cold extension measurement. Decoding is synchronous at gesture completion. These results establish neither physical-device latency nor the extension's resident/peak memory cost. No eviction guarantee is made.

Run [Scripts/evaluate-swipe.swift](../Scripts/evaluate-swipe.swift) with the commands in its header to reproduce the fixture comparison. Raw logs and JSON stay in ignored `artifacts/swipe-evaluation/`; every evaluated word/path is synthetic.

## Build 11 release evidence, October 18, 2026

This is historical evidence. Its review submission was withdrawn and replaced by build 12 after the swipe work passed its checks.

Build 11 removes the keyboard's Full Access request and App Group sharing. Installed-keyboard settings and snippets belong to the extension's local store. The companion's keyboard/layout preview settings and snippets stay only in memory; its playground draft is saved separately. Existing keyboard-local records are retained, and older shared-container or companion preference records are neither imported nor erased.

The gear owns keyboard settings and snippet creation, editing, deletion, and reset. Snippet drafts use a separate local document; editing/cancelling a draft and saving it are distinct from inserting a saved snippet into the host. Regression coverage includes host isolation, Unicode and size limits, held-key save/cancel behavior, stale cancelled controls, independent preference stores, and memory-only previews.

Current evidence:

| Check | Result | Scope |
| --- | --- | --- |
| Core package | 83 methods in nine suites pass | Build 11 source |
| iPad hosted suite | 77 methods pass, zero failures/skips/runtime warnings | iPad Pro 11-inch M5, iPadOS 27.0; followed by the final focused checks below |
| Duo hosted suite | 77 methods pass, zero failures/skips/runtime warnings | Duo Simulator, iOS 27.1; followed by the final focused checks below |
| Phone hosted suite | 79 methods pass | 21 XCTest and 58 Swift Testing methods |
| Final iPad/Duo cleanup | Nine methods; 15 passing executions per device, zero failures/skips/runtime warnings | Final cancelled-control/weak-reference and Dynamic Type snippet cleanup |
| Phone UI flows | All eligible flows passed across the initial run and focused reruns | Initial 15-method run had two device/pose skips and three harness failures; see qualification below |
| Build 11 archive/export | All 13 artifact checks pass; Apple server binary validation passes | Versions, signed entitlements, privacy, signatures, resources and dependencies |
| Build 11 processing/attachment | VALID, attached to submitted version 1.0, internal beta testing active | Existing all-builds internal group and automatic notifications verified |
| App Store API readiness | Zero errors, warnings, or blockers | Build 11 IPA and URL checks; final validation retains only non-API privacy publication as informational |
| Current media | Three native capture tests pass; all 31 screenshots COMPLETE | Five Settings slides updated, 26 retained; final remote order/checksums match; linked header Waiting for Review |

The phone hosted result is in `build11-final-checks.xcresult`. Its command exited unsuccessfully because the largest-text menu-scroll harness still needed correction; the hosted suite, snippet flow, and pairing-toggle flow passed. The corrected largest-text settings flow and snippet flow then passed in `build11-a11y-final.xcresult`, whose command completed successfully. The initial combined UI invocation was terminated after tests completed while it emitted package-graph messages. These are separate receipts, not one clean full UI invocation.

The actual archived and exported app/extension bundles have no Full Access request or signed App Group entitlement. Both local-only manifests match source and declare only UserDefaults reason `CA92.1`. Signatures, versions/minimum OS, device families, exact MIT/notices, and light/dark/tinted icons passed inspection; no test bundles or third-party frameworks ship. Remote readbacks confirm that build 11 processed successfully and is attached to version 1.0. Internal testing access is verified. After the owner approved the listing and artwork, the description and promotional text received a final Humanizer 3.1.0 pass. Version 1.0 (11) and its linked header were submitted on October 18, 2026; both read back as Waiting for Review. The app is Free, with release after approval configured. [Release readiness](../release-prep/readiness.md) records the listing, media, privacy and submission evidence.

The current [website privacy policy](https://www.jeremycollins.net/tabforge-privacy-policy) is deployed to production and verified by a fresh HTTP 200 response plus live content inspection. It matches the repository [privacy policy](../PRIVACY.md). The owner explicitly approved both privacy publications; the authenticated App Store Connect browser confirmed **Data Not Collected** as published. Those privacy publications preceded the separately authorized App Review submission.

The no-sharing source is [public under MIT](https://github.com/jdodsoncollins/TabForge/commit/9c8dc83e10af08a591ce35b4d3b536645a8af6d7), and its [public CI run passed](https://github.com/jdodsoncollins/TabForge/actions/runs/39140923632). Signing/account details and raw receipts remain private.

## Earlier evidence, kept as history

- **October 18, build 9:** 83 core methods passed. A phone run passed 68 hosted methods plus two UI methods. Tests covered editing policy, proxy failure handling, correction rejection, themes, controls, speech lifecycle, and companion navigation.
- **October 18, build 10:** all 12 archive/export structure, signature, resource and privacy checks passed. Focused companion-attribution checks passed at normal/largest phone text sizes and, after a color correction, normal phone/iPad navigation passed. These supplement the earlier baseline; they did not validate build 11's different storage and snippet routes.
- **October 17–18, earlier revisions:** simulator checks covered compact landscape/Fn, phone/iPad/Duo geometry, expanded touch regions, overlapping control events, light/dark/code palettes, accessibility metadata, and bounded editing/formatting behavior. An earlier iOS 27.0 spelling-service integration assertion needed a bounded warmup allowance; final suites for that revision passed without making typing wait for the service.

Earlier sharing/signing behavior belongs to those historical versions. It is not the design of the current no-Full-Access source and must not be copied into current listing or privacy claims.

## Device validation still required

- Real extension cold launch, sustained memory pressure, and recovery after system termination. Companion-process measurements do not establish an extension's device memory budget.
- Physical two-, three-, and four-finger typing, screen-edge/palm contact, screen protectors, and Touch Accommodations. Injected UIKit events test the app state machine, not Apple's digitizer classifier.
- Complete VoiceOver, Switch Control, and Voice Control typing and settings sessions on devices. Labels and screenshots establish only part of usability.
- Microphone availability, system Dictation, actual terminal/Remote Desktop control forwarding, floating/Split View keyboards, hardware-keyboard coexistence, and app-specific keyboard constraints.
- The complete physical Duo posture/rotation matrix, including snippet settings in a constrained keyboard and host callbacks while a draft is open.

Use [accessibility](keyboard-accessibility.md), [touch input](keyboard-touch-input.md), [performance](keyboard-performance.md), [design](../DESIGN.md), and [AGENTS.md](../AGENTS.md) when reproducing checks. Share only synthetic examples. Report sensitive issues through [SECURITY.md](../SECURITY.md).
