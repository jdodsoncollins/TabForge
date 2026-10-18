# Working on TabForge

TabForge is a native iOS/iPadOS programming keyboard. A keyboard handles sensitive input, so small, reviewable changes and accurate privacy documentation matter as much as new features. Read [DESIGN.md](DESIGN.md), [PRIVACY.md](PRIVACY.md), and [SECURITY.md](SECURITY.md) before changing input or storage behavior.

## Project map

- `Sources/KeyboardCore`: platform-independent editing, shortcuts, formatting, preferences models, autocorrection policy, and experimental swipe decoding. This is the local Swift package.
- `Sources/KeyboardUI`: shared UIKit keyboard, document adapters, palettes, geometry, spelling service, and preference persistence. Compiled into both the app and extension.
- `KeyboardExtension`: `UIInputViewController` lifecycle and the host application's `UITextDocumentProxy` bridge.
- `App`: companion information and playground, memory-only keyboard/layout previews, native UIKit editor, and on-device voice input.
- `Tests/KeyboardCoreTests`: Swift package tests. `UnitTests`: hosted UIKit tests. `UITests`: app UI flows.
- `project.yml`: XcodeGen source of truth. Regenerate `ScriptKeyboard.xcodeproj` after changing targets, files, or build settings.

Use Xcode 27.1 or later with Swift 6. The deployment minimum is iOS/iPadOS 27.0; Duo-specific APIs must remain guarded by availability checks for 27.1. Use your own signing team, bundle identifiers and provisioning for device builds. Copy `.env.example` to ignored `.env`, then run `python3 Scripts/configure-build.py` to generate the ignored local Xcode configuration. The keyboard does not request Full Access or use an App Group. Keep signing credentials and local signing overrides out of version control.

## Build and verification

Run platform-independent tests with:

```sh
swift test
```

For UIKit and UI tests, choose an available simulator from `xcrun simctl list devices available` and run:

```sh
xcodebuild -project ScriptKeyboard.xcodeproj -scheme ScriptKeyboard \
  -destination 'platform=iOS Simulator,id=<SIMULATOR_UDID>' \
  CODE_SIGNING_ALLOWED=NO test
```

When changing `project.yml`, run `xcodegen generate` and include the generated project changes. Run focused tests during development, then the suites relevant to the final change. Add regression coverage for input correctness, lifecycle, or layout failures; avoid tests that merely repeat implementation details.

The checked-in project references public `Configuration/Build.xcconfig`, which optionally includes ignored `Configuration/Signing.local.xcconfig`. Normal regeneration from `project.yml` preserves symbolic identifiers and does not copy local values into the project. Ignored legacy `project.local.yml` and private release records may also exist on a maintainer's machine. Do not publish them. If a private spec was used to regenerate the project, regenerate from public `project.yml` before committing so personal team/profile configuration stays out of the public project. Treat env files as data; do not source or evaluate them.

Input and layout changes need coverage across a narrow phone, landscape phone, iPad, and the relevant Duo poses. Include short windows, safe areas, compact height, and accessibility settings when affected. Simulator coverage does not prove physical multitouch, palm rejection, microphone availability, memory-pressure survival, or compatibility with every terminal client. Record those limits honestly.

## Input correctness

- Keep UIKit work on the main actor and preserve Swift 6 concurrency checks.
- Keep `KeyboardCore` free of UIKit. Extend `TextDocument` or its adapters when a platform capability is needed.
- Treat proxy context as partial and nullable. Never interpret missing text as proof of a document boundary. Decline destructive edits when the required range or cursor movement cannot be verified.
- Respect UTF-16 offsets for UIKit selection and movement, and composed-character boundaries for user-facing character operations. Test emoji and combining marks when touching these paths.
- Preserve release-inside/cancellation behavior, overlapping presses, modifier snapshots, and deferred grid rebuilds while keys are held. Do not turn typing into an exclusive-touch interaction.
- Keep Code editor, Terminal, and Remote desktop behavior explicit. Text insertion is not hardware-key injection. Do not silently send unsupported shortcuts as ordinary characters.
- Leave autocorrection and swipe opt-in. Respect host field traits and profile restrictions. Keep immediate correction rejection safe across cursor changes and host callbacks.

## Privacy and dependencies

- Never log, transmit, analyze, or persist host typing, surrounding text, selected text, swipe traces, speech audio, transcripts, or supplementary lexicon entries for diagnostics or model training.
- Existing deliberate storage is limited to the keyboard extension's local preferences/snippets and the companion playground draft. The companion's keyboard/layout preview settings and snippets stay only in memory; do not persist them or synchronize them with the extension. Document any intentional change to storage, permissions, or data flow in the same change.
- Do not request Full Access, add App Group access, or share keyboard records with the companion app. Preserve the existing keyboard-local record without importing or erasing older App Group or companion preference records.
- Keep snippet drafts in a separate local buffer. Editing or cancelling a snippet must not modify the host document; inserting a saved snippet is a separate user action.
- Do not add analytics, advertising, remote configuration, cloud spelling, or a cloud speech fallback. User-initiated external links and Apple system features must remain clearly identified.
- Keep speech recording in the companion app, explicitly initiated by the user, with on-device recognition required and cleanup on cancellation, interruption, backgrounding, and dismissal.
- Review both code and bundled data licenses before adding a dependency. Preserve notices and verify compatibility with the repository's MIT license. A research candidate is not a shipped dependency.
- Use synthetic text in tests, screenshots, benchmarks, issue reports, and logs. Do not commit private account records, signing material, device inventories, personal documents, or build/upload artifacts.

## Performance and accessibility

Keep ordinary key presses cheap. Bound context reads, avoid copying a whole document per character, reuse the key grid, and release gesture traces, spelling resources, modifier state, timers, and tasks when no longer needed. Measure a suspected regression with the same workload and configuration before claiming an improvement. iOS may terminate a keyboard extension at any time; no change can promise immunity from eviction.

Preserve VoiceOver names and keyboard traits, selected modifier state, Caps Lock actions, usable hit targets, Bold Text, Dynamic Type in settings, contrast, and predictable focus order. Use public UIKit behavior; do not claim access to Apple's private keyboard touch classifier, QuickPath decoder, or prediction engine.

Keep documentation aligned with what ships. Describe limitations directly, and separate automated evidence from physical-device or third-party-host validation still required.
