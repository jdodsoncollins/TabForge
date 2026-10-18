# Contributing

TabForge is an MIT-licensed iOS keyboard. Small, reviewable changes and reproducible bug reports are welcome.

Read [DESIGN.md](DESIGN.md), [PRIVACY.md](PRIVACY.md) and [AGENTS.md](AGENTS.md) before changing keyboard behavior. Report vulnerabilities privately using [SECURITY.md](SECURITY.md).

## Development

Use Swift 6 and Xcode 27.1 or later for the app. The standalone `KeyboardCore` package can be tested on macOS with `swift test`. Open `ScriptKeyboard.xcodeproj` to build the app and extension. If changing `project.yml`, regenerate the checked-in project with `xcodegen generate`.

Choose your own signing team and identifiers for physical devices. Copy `.env.example` to `.env`, edit the two values, and run `python3 Scripts/configure-build.py`; see the README for the full setup. The generated local override is ignored, and public XcodeGen regeneration keeps it outside the checked-in project. No App Group setup is needed. Never commit signing credentials, provisioning profiles, local build overrides, TestFlight administration or captures containing personal text.

## Changes and evidence

- Explain the user-visible behavior and its compatibility limits.
- Add meaningful regressions for edits that can delete or replace text, gesture cancellation, modifiers, context boundaries and privacy-sensitive behavior.
- Run `swift test`; run the hosted UIKit tests for renderer/adaptor changes. Exercise affected UI on applicable phone, tablet and foldable layouts.
- Preserve Unicode boundaries, accessibility labels, overlapping key presses and operation without Full Access.
- Include third-party licenses and data/model provenance before adding a dependency. A research link is not an integrated dependency.
- Distinguish simulator/companion tests from real extension, hardware, terminal and accessibility verification.

Use synthetic examples in issues and screenshots. Do not attach real source code, passwords, terminal sessions, contact names, audio or document context unless you have deliberately removed sensitive information.

By contributing, you agree to license your contributions under this project's MIT license. Third-party material must retain its own applicable notices.
