# Design and architecture

TabForge makes programming punctuation and editing actions accessible on iPhone and iPad while working within Apple's public custom-keyboard APIs. It favors literal, predictable text in terminals and remote sessions, conservative smart editing in text fields, and local processing. The current deployment minimum is iOS/iPadOS 27.0; Duo-specific adaptation is available on 27.1.

## Components and trust boundaries

| Component | Responsibility |
| --- | --- |
| `KeyboardCore` Swift package | Text-document abstraction, editing policy, shortcuts, indentation, formatting, settings models, and the small swipe decoder |
| `CodingKeyboardView` | UIKit key grid, toolbar/menu, touch tracking, modifiers, gestures, accessibility, and layout |
| `TextViewDocument` | Full native playground document, UIKit selections, and undoable edits |
| `ProxyDocument` | Limited host context and text insertion through `UITextDocumentProxy` |
| `KeyboardViewController` | Extension lifecycle, height requests, keyboard switching, preferences access, and supplementary lexicon preparation |
| SwiftUI companion app | Setup, information, licenses, layout previews, and playground navigation |
| `EditorHostView` | UIKit/TextKit playground, syntax highlighting, line numbers, and cursor state |
| `SpeechRecorder` | Explicit companion-app audio lifecycle and required on-device recognition |

`Sources/KeyboardUI` is compiled into both the companion app and the keyboard extension. It depends on the local `KeyboardCore` package. The shipping project has no third-party runtime package dependency. Research notes describe possible future engines, not bundled software.

The companion app and extension are separate processes with separate storage. The keyboard does not request Full Access or configure an App Group. It owns its settings and snippets; the companion does not synchronize them. Neither process needs a TabForge network service. The host application owns its document and determines which text, traits, selections, and movement operations the extension can use. A remote client additionally controls how inserted text reaches the remote system. The playground deliberately persists its draft locally and exposes a user-triggered system share sheet. See [PRIVACY.md](PRIVACY.md) for stored data and [SECURITY.md](SECURITY.md) for reporting.

The companion keyboard and layout guide are explicitly previews. Their independent settings and snippets live only in memory for the current app process, so preview changes cannot configure the installed extension or persist as companion keyboard preferences. The playground draft is separate and remains saved locally.

Version 1.0.1 (15) presents the optional Tip Jar through the initiating SwiftUI view's scene-aware Apple purchase action. The version and five tips were submitted on October 21, 2026; the version and review submission are WAITING_FOR_REVIEW, with release after approval configured. Build 15 remains VALID and available to the existing internal TestFlight group. The live version 1.0 (12) has no tips. StoreKit remains in the companion app, with no TabForge backend, access to extension records or new keyboard permissions. See [Tip Jar implementation and release checks](docs/tip-jar.md).

## Text editing

`TextDocument` is main-actor isolated. UIKit selection and movement offsets use UTF-16; bounded nearby-context methods count Swift extended grapheme clusters. Preserve that distinction when handling emoji or combining marks.

The native playground adapter can inspect the complete text buffer and group edits through UIKit Undo. A proxy cannot assume complete context: `nil` means unavailable, and a returned string may be only a window around the cursor. Line deletion and replacement operations verify the required surrounding text and cursor state. They decline when the available evidence is insufficient rather than guessing a boundary.

The input profiles define behavior explicitly:

- **Code editor:** pairing, indentation, contextual editing, and local navigation when supported by the document adapter.
- **Terminal · ANSI:** literal Tab, configured return/delete characters, ASCII Control codes, Escape-prefixed Meta input, and ANSI navigation sequences. The client must forward and interpret these sequences.
- **Remote desktop:** literal text and tabs with smart transformations disabled. The client remains responsible for remote keyboard behavior.

A text proxy does not synthesize hardware key events. A visible Control, Option, Command, Tab, or Escape key therefore cannot promise the same result in every host. Unsupported shortcuts show a status message instead of inserting an unrelated character. Formatting is a limited brace-language reindent or JSON pretty-print; semantically risky indentation cases are declined.

## Key and gesture lifecycle

Keys use UIKit button tracking and commit on release inside the hit area. Cancellation and release outside cancel the press. Holding a key that has alternates (the hinted digit on q–p, or related operators on symbol keys) for about 0.4 seconds opens a callout; sliding picks an entry and release commits it, including a release outside the key. VoiceOver exposes the same alternates as custom actions. Hit regions fill part of the inter-key gaps while remaining within usable screen regions. UIKit's public control and gesture behavior supplies the platform integration; TabForge does not have Apple's private keyboard touch classifier or promise system-level edge/palm rejection.

Keys permit overlapping touches. A press captures modifier state at finger-down so a held modifier can be released before its character key without losing the intended chord. Tapping a modifier arms the next key. Grid replacement waits until active presses finish, preventing orientation or state changes from destroying a held key. Single-finger swipe and cursor-scrub gestures reject multi-finger gestures.

Dismissal, removal from a window, and memory warnings clear transient presses, modifiers, previews, repeat-delete tasks, gesture traces, alternatives, correction state, and spelling resources. Extension callbacks invalidate correction state for external text or selection changes, so a stale correction cannot follow the user into a different cursor position.

## Adaptive geometry and height

Layout capacity comes from usable width rather than a device-name check. Compact, wide-phone, expanded, and Studio layouts also accommodate floating keyboards and resized app windows. Larger layouts can expose more punctuation, numbers, and editing controls.

Automatic height uses four compact rows in landscape/short host windows, requesting approximately 200 points plus safe areas. The toolbar and dedicated extra rows give way to an **Fn** layer containing editing controls without increasing height. Users can explicitly select Automatic, Compact, or Full height. A host may impose a smaller size, so keys must still fit constrained bounds.

On supported Duo configurations, active division and occlusion regions exclude keys. A sufficiently wide horizontal division can request the lower panel for a fuller tabletop layout; a vertical book fold keeps the ordinary adaptive layout. Safe areas and reserved regions constrain hit targets as well as visible key frames. iOS and the host retain control of final keyboard placement and height.

Test phone portrait/landscape, iPad full/floating/split windows, and relevant Duo closed/open/book/tabletop configurations. Do not use the keyboard's own requested height as the host's available-height input; that would create a sizing feedback loop.

## Smart input boundaries

**Prose autocorrection** is off by default. Enabling it still requires the Code editor profile and known, eligible host traits. Structured fields, explicit host opt-outs, secure fields, Terminal/Remote profiles, the playground's code editor, and code-like lines remain literal. English ASCII candidates are bounded and restricted to a single spelling edit, including an adjacent transposition. Apple `UITextChecker` supplies guesses; this is not Apple's private system keyboard prediction engine.

**Sentence capitals and the double-space period** apply only in the Code editor profile when the host field asks for sentence capitalization in a plain, non-secure field. Auto-capitalization only turns on Shift. A second Space within 1.5 seconds after a letter or digit replaces the verified space with ". "; missing context leaves the space literal. Both have their own switch under Editing preferences.

Correction commits on Space. Immediately pressing Delete restores the original spelling and rejects that guess once. Document identity and text anchors are checked before replacement and undo. Missing or changing proxy evidence prevents an unverified edit. An asynchronously obtained, bounded supplementary lexicon protects names and shortcut inputs in memory; it is never persisted.

**Swipe typing** is an opt-in experimental geometric decoder over bundled English and programming vocabularies. It provides alternatives through the gear menu and does not provide a general language model. The English data comes from a pinned ESDB small dictionary with separate notices. A per-keyboard decoder indexes candidates by endpoints and normalizes horizontal/vertical key pitches. It reranks at most 48 candidates with bounded elastic alignment and is released on dismissal or memory pressure. Gesture sessions are cancelled on layout, input, or mode changes; alternatives require a matching document anchor, menu generation, and verified replacement. Swipe declines an active text selection rather than retaining or repeatedly comparing its potentially large contents; tap typing can replace that selection. Apple QuickPath has no public decoder API for this implementation. Any replacement must earn its place through held-out real gestures, latency, memory, lifecycle, licensing, and data-provenance checks.

**Voice to code** lives in the companion app because the extension cannot record microphone audio. The user starts recording, grants permissions, reviews the transcript and punctuation conversion, then inserts it. Recognition requires on-device English support and has no cloud fallback. System Dictation remains under iOS control. The native playground allows system Writing Tools where supported; generated changes still require user review.

## Settings and appearance

The keyboard's short-press gear menu combines editing actions, snippets, suggestions/alternatives, quick preferences, and the complete keyboard settings interface. All installed-keyboard controls and snippet creation, editing, deletion, and reset belong to the extension. The companion contains setup and compatibility help, source/privacy links, credits, and licenses. It does not configure the installed keyboard. The extension does not launch the companion app; the app's existing settings URL remains a narrow navigation route for its own information screen.

The snippet editor uses an isolated local draft rather than the host's `UITextDocumentProxy`. Draft keystrokes must remain in that local buffer, including deletion and selection edits. Save changes the keyboard's local snippets; cancellation discards the draft. Selecting a saved snippet for insertion is the separate action that writes it to the host.

The companion app bundles the repository's `LICENSE` and `THIRD_PARTY_NOTICES.md` directly as resources. Settings → Licenses & notices displays those documents without a network request; maintain the original files rather than a separate copy of their text.

`PreferencesStore` reads and writes a versioned record only in the current process's local preferences. The keyboard retains an existing local record and preserves decoding defaults for older records. There is no App Group lookup, cross-process reconciliation, or automatic import from earlier shared settings. A preference change in the companion cannot configure the extension. Legacy records in the old shared container or app container are not read or erased by this change.

The companion initializes its preview store without a persistent defaults backend. Do not replace that memory-only store with app `UserDefaults`, a named suite, or a shared container. Its draft persistence is the existing separate `playground.draft` entry.

iOS Standard follows system light/dark by default. Code palettes are explicit alternatives. Keep palette definitions centralized in `KeyboardPalette`, use semantic colors where appropriate, and preserve legibility across appearance, Bold Text, and increased-contrast settings.

## Optional tips (version 1.0.1)

The companion's Tip Jar offers five repeatable consumable purchases. Tips unlock no features, add no subscription, and do not affect keyboard behavior. Show a purchasable price only after StoreKit returns the matching product, using `Product.displayPrice` for its storefront and currency. Loading, missing products, disabled purchases, cancellation, pending approval, verification failure, and purchase failure must leave the rest of the app usable.

An app-scoped transaction listener handles verified matching tip transactions, including completions delivered after the purchase screen closes. Finish a verified tip after the app completes its acknowledgement; do not treat an unverified transaction as success or finish unrelated products. The app keeps no separate receipt, purchase history, or tip total in its preferences. StoreKit and the App Store maintain their own transaction records. There is no durable entitlement to restore for these consumable tips.

## Accessibility

Keys expose keyboard traits, spoken delimiter names, usable accessibility frames, and a predictable navigation order. Modifiers expose selected state and a Caps Lock action. Key-label scaling is bounded to fit the keyboard; settings support full Dynamic Type and adapt their arrangement at accessibility sizes. Respect system appearance and reduce-motion behavior where relevant. A screenshot or unit test does not establish usability with VoiceOver, Switch Control, Voice Control, or physical touch; verify those interactions on devices when changing them.

## Performance and verification

An extension can be terminated by iOS, including under memory pressure. No fixed memory budget or eviction exemption is assumed. Keep key insertion synchronous and inexpensive, defer optional work, and avoid introducing startup services or large models without measurements.

Bound context reads on ordinary editing paths. The playground caches syntax rules and line starts and avoids repeated cursor/selection work when nothing changed. Reuse the key grid and skip unchanged UI updates. Optional spelling preparation must not block typing; speech resources belong only to the active companion voice session.

Core tests cover editing policy, Unicode boundaries, proxy failure cases, formatting, and layout selection. Hosted tests cover adapters, UIKit controls, preferences, speech lifecycle, geometry, accessibility metadata, and performance workloads. UI tests cover real menus and playground flows. Run comparable before/after workloads for performance claims and record runtime, build configuration, device, and test limits. Hardware multitouch, memory pressure, microphone behavior, and individual terminal/remote clients remain separate validation work.

For contributor workflow and concrete commands, see [AGENTS.md](AGENTS.md).
