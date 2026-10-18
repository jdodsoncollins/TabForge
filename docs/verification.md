# Verification and known limits

This is a public summary of local checks, not an independent security audit. Source changes do not update an installed App Store or TestFlight binary. Raw device inventories, signing/upload records, captures, and result bundles stay in ignored artifacts; published tests use synthetic text.

## Current candidate: 1.0 (11), October 18, 2026

The current revision removes the keyboard's Full Access request and App Group sharing. Installed-keyboard settings and snippets belong to the extension's local store. The companion's keyboard/layout preview settings and snippets stay only in memory; its playground draft is saved separately. Existing keyboard-local records are retained, and older shared-container or companion preference records are neither imported nor erased.

The gear owns keyboard settings and snippet creation, editing, deletion, and reset. Snippet drafts use a separate local document; editing/cancelling a draft and saving it are distinct from inserting a saved snippet into the host. Regression coverage includes host isolation, Unicode and size limits, held-key save/cancel behavior, stale cancelled controls, independent preference stores, and memory-only previews.

Current evidence:

| Check | Result | Scope |
| --- | --- | --- |
| Core package | 83 methods in nine suites pass | Current revision |
| iPad hosted suite | 77 methods pass, zero failures/skips/runtime warnings | iPad Pro 11-inch M5, iPadOS 27.0; followed by the final focused checks below |
| Duo hosted suite | 77 methods pass, zero failures/skips/runtime warnings | Duo Simulator, iOS 27.1; followed by the final focused checks below |
| Phone hosted suite | 79 methods pass | 21 XCTest and 58 Swift Testing methods |
| Final iPad/Duo cleanup | Nine methods; 15 passing executions per device, zero failures/skips/runtime warnings | Final cancelled-control/weak-reference and Dynamic Type snippet cleanup |
| Phone UI flows | All eligible flows passed across the initial run and focused reruns | Initial 15-method run had two device/pose skips and three harness failures; see qualification below |
| Build 11 archive/export | All 13 artifact checks pass; Apple server binary validation passes | Versions, signed entitlements, privacy, signatures, resources and dependencies |
| Build 11 processing/attachment | VALID, attached to the draft, internal beta testing active | Existing all-builds internal group and automatic notifications verified |
| App Store API readiness | Zero errors, warnings, or blockers | Build 11 IPA and URL checks; manual release and non-API privacy publication are informational |
| Current media | Three native capture tests pass; all 31 screenshots COMPLETE | Five Settings slides updated, 26 retained; final remote order/checksums match; header assigned in draft |

The phone hosted result is in `build11-final-checks.xcresult`. Its command exited unsuccessfully because the largest-text menu-scroll harness still needed correction; the hosted suite, snippet flow, and pairing-toggle flow passed. The corrected largest-text settings flow and snippet flow then passed in `build11-a11y-final.xcresult`, whose command completed successfully. The initial combined UI invocation was terminated after tests completed while it emitted package-graph messages. These are separate receipts, not one clean full UI invocation.

The actual archived and exported app/extension bundles have no Full Access request or signed App Group entitlement. Both local-only manifests match source and declare only UserDefaults reason `CA92.1`. Signatures, versions/minimum OS, device families, exact MIT/notices, and light/dark/tinted icons passed inspection; no test bundles or third-party frameworks ship. Remote readbacks confirm that build 11 processed successfully and is attached to version 1.0 in Prepare for Submission. Internal testing access is verified. App Store preparation remains unsubmitted and under manual release control. [Release readiness](../release-prep/readiness.md) records the completed listing, media, privacy, and owner-review state.

The current [website privacy policy](https://www.jeremycollins.net/tabforge-privacy-policy) is deployed to production and verified by a fresh HTTP 200 response plus live content inspection. It matches the repository [privacy policy](../PRIVACY.md). The owner explicitly approved both privacy publications; the authenticated App Store Connect browser confirmed **Data Not Collected** as published. This does not submit the app for review.

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
