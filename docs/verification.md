# Verification and known limits

This is a public summary of local checks, not an independent security audit. Source changes do not update an installed App Store or TestFlight binary. Raw device inventories, signing/upload records, captures, and result bundles stay in ignored artifacts; published tests use synthetic text.

## Current candidate: 1.0 (11), October 18, 2026

The current revision removes the keyboard's Full Access request and App Group sharing. Installed-keyboard settings and snippets belong to the extension's local store. The companion's keyboard/layout preview settings and snippets stay only in memory; its playground draft is saved separately. Existing keyboard-local records are retained, and older shared-container or companion preference records are neither imported nor erased.

The gear owns keyboard settings and snippet creation, editing, deletion, and reset. Snippet drafts use a separate local document; editing/cancelling a draft and saving it are distinct from inserting a saved snippet into the host. Regression coverage includes host isolation, Unicode and size limits, held-key save/cancel behavior, stale cancelled controls, independent preference stores, and memory-only previews.

Current evidence:

| Check | Result | Scope |
| --- | --- | --- |
| Core package | 83 methods in nine suites pass | Current revision |
| iPad hosted suite | 77 methods pass, zero failures/skips/runtime warnings | iPad Pro 11-inch M5, iPadOS 27.0; before final weak-reference/cancelled-control and Dynamic Type snippet cleanup |
| Duo hosted suite | 77 methods pass, zero failures/skips/runtime warnings | Duo Simulator, iOS 27.1; before the same final cleanup |
| Phone hosted/UI regression | In progress | Await the UI agent's completed result |
| Final cleanup checks | Pending focused reruns | Must correspond to the final source |
| Build 11 archive/export and remote checks | Pending | Source version alone does not establish signing, upload, processing, or attachment |

Build 10 remains the last confirmed valid/attached internal beta while build 11 is prepared. The final archive must verify no Full Access request, no signed App Group entitlement, current local-only privacy manifests, correct versions/minimum OS, licenses/notices, and icon resources. App Store preparation remains unsubmitted and under manual release control. [Release readiness](../release-prep/readiness.md) tracks current media, metadata, policy publication and archive gates.

The website policy revision for the new storage behavior is prepared but not yet confirmed live. The repository [privacy policy](../PRIVACY.md) describes the new source. A prior HTTP success for the website does not prove the new text was deployed. App Privacy is saved as a draft; its Publish action was rejected by automatic approval review and awaits explicit user approval. No retry or bypass is authorized by a passing test.

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
