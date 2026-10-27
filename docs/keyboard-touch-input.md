# Touch handling and modifier behavior

TabForge uses public UIKit controls for touch delivery and tracking. Apple documents independent multi-touch delivery, exclusive-touch settings, and system-cancelled touches; it does not publish the system keyboard's touch-classification model for reuse by a keyboard extension. We preserve UIKit cancellation and system gestures rather than intercepting the screen globally.

The compact-height and accessibility changes described below pass build 6's automated keyboard matrix. Candidate 7 corrects a decorative layout-guide icon and repeats targeted checks; its keyboard code is unchanged. Current results and remaining device coverage are recorded in [verification](verification.md) and the dated QA report. See also [Keyboard accessibility and compact layouts](keyboard-accessibility.md).

## Implementation

- Key caps retain their visual spacing. Their touch regions meet halfway across each gap, use deterministic boundaries, and stay inside keyboard safe areas. Expanded regions are checked against active fold/camera regions. No hit target extends outside the keyboard.
- The full-layout toolbar follows a desktop arrangement by default: Escape at the leading edge, then Control, Option, Command, Delete line, the four arrows, and the tools/settings gear at the trailing edge. Gear → Layout & keys → Toolbar keys can add Tab, |, ~, `, \ or $ and remove keys, up to ten plus the gear, always in that fixed order.
- On the Compact layout (most iPhones in portrait), the **=;** key switches the symbol row between brackets and = " ' ; : / - _.
- The return key shows the host's title (Go, Search, Send, Next, Done and similar) when the field provides one.
- In full layouts, toolbar controls are 44 points tall and have adjacent, non-overlapping hit targets. The 320-point viewport gives each toolbar control approximately 30 points of width before unusual safe-area or reserved-region constraints. Wider devices get larger targets. The toolbar is hidden in compact height.
- Keys use `UIButton` tracking and commit on release inside their hit region. Outside/cancelled releases do not type. Controls do not use exclusive touch. A single control accepts one finger to avoid duplicate activations from two fingers on one key; separate controls remain independent.
- Ctrl, Option and Command support tapping to latch the next key or holding for multiple keys. Each letter/arrow captures its modifiers at finger-down, so an early modifier release cannot alter the pending chord. Letters commit in finger-release order.
- Held Shift affects overlapping letters. Shift/page/layout changes, including Fn, defer grid replacement until pressed keys finish, preventing UIKit from cancelling another finger's held key. Releasing a letter does not stop another finger's Delete-repeat timer.
- Swipe and cursor-scrub recognizers accept one finger and do not delay touch delivery. A second finger makes those gestures fail, leaving independent key tracking intact. Pending modifier chords disable swipe interpretation.
- Dismissal and memory warnings clear held/latched state, active press snapshots, previews and timers. No touch objects or typed-history log are retained.

## Compact height

Automatic height uses the host's stable available height or compact vertical size class. Compact explicitly requests the short layout; Full requests the width-appropriate extra rows. A dedicated Duo tabletop panel keeps the full layout. These preferences determine the requested height, independent of any temporary compression of the keyboard's own frame.

The compact request is four rows with 44-point keys, 4-point gaps, and 8-point outer padding: **200 points plus top/bottom safe-area insets**. It removes the toolbar, programming-symbol row, automatic number row, and extra editing row. Tab remains in the bottom row. Fn replaces the upper typing rows with arrows, Ctrl/Option/Command, indentation, delimiters, Escape, and the combined tools/settings gear at the same requested height. 123 / ABC provides the numeric and punctuation pages.

A host can allocate less than the requested height. The emergency fallback displays four rows before allowing a full grid to become excessively compressed; it does not change the stored preference or reduce the stable request. Actual keys can still be smaller when the host allocates less than four rows need. UIKit self-sizing is enabled on the input-view shell; [Apple documents](https://developer.apple.com/documentation/uikit/uiinputview/allowsselfsizing) that self-sizing honors the input view's fitted size, not that an extension can force any screen area it chooses.

This is intended for regular iPhone landscape, closed Duo landscape, and short app windows. Open Duo and roomy iPad windows retain their extra rows. Small-phone, floating-keyboard, Split View, and physical fold transitions need validation against their actual host geometry, safe areas, and reserved regions.

## Accessible interaction

Keys have descriptive labels and keyboard-key traits. Shift exposes its case state and a named Caps Lock action. Modifiers expose a selected state and can latch with a tap, and Fn reports its active page and pending modifiers. This allows sequential activation without requiring a physical chord. The grid follows Bold Text and bounded text scaling; settings retain full Dynamic Type. Opaque fills and disabled implicit swipe-path animations avoid depending on blur or motion for essential feedback. See [the accessibility design](keyboard-accessibility.md) for details and limitations.

Apple lists a 44 × 44-point default and 28 × 28-point minimum control size for iOS/iPadOS in its [Accessibility HIG](https://developer.apple.com/design/human-interface-guidelines/accessibility). The design aims for usable expanded targets, but dense columns and externally compressed frames must be measured; this is not a blanket target-size compliance claim.

## Supported shortcuts

Editor: Option–Left/Right moves by identifier/word; Command–Left/Right moves to the exposed logical line boundary. Command–Up/Down requires complete document context. Native playground Up/Down follows wrapped visual lines; text proxies use exposed logical lines when enough context exists.

Terminal: Ctrl sends ASCII control bytes, Option sends Escape-prefixed Meta text, and modified arrows use xterm modifier parameters. Actual behavior depends on terminal-client forwarding and shell bindings. Command and arbitrary remote hardware events cannot be synthesized through `UITextDocumentProxy`. Unsupported chords display a message and do not insert the unmodified key.

## Verification scope

The existing 1.0 (5) automated checks exercised interleaved down/up/cancel control events for two modifiers plus two letters, four letters, early modifier release before an arrow, held Shift, page changes, and cancelled Delete. Geometry/hit-testing covered widths 320–1366 points, and UI automation exercised a key-gap tap and cancelled drag. These checked the press state machine and simulator geometry, not physical digitizer contacts.

Build 6 passes 51 core tests in seven suites and 51 hosted UIKit test methods on each of iPhone, iPad and Duo, including compact-height policy, four-row geometry, Fn reachability, modifier latching across pages and overlapping presses during Fn changes. Companion UI checks verify compact height and Fn behavior, and the horizontal-tabletop simulator check passes with zero skips. These results do not directly measure the extension's actual height in a third-party host.

Candidate 7 changes only a decorative icon in the companion layout guide. Its largest-accessibility-text UI rerun and all 51 hosted methods on each of iPhone, iPad and Duo pass, with zero failures or skips in the hosted repeats. See [current verification](verification.md) for receipts and publication status.

Physical two-/three-/four-finger typing, edge grips/palms, screen protectors, Touch Accommodations, actual VoiceOver/Switch Control/Voice Control interaction, hardware-keyboard coexistence, terminal forwarding, floating keyboards, Split View, and physical Duo tabletop behavior remain device checks. Prior simulator tabletop results do not establish physical coverage or validate this change. We cannot claim the same accidental-touch accuracy as Apple's keyboard or guarantee iOS will never cancel a touch or evict the extension.

## Primary references

- [UIKit: UITouch](https://developer.apple.com/documentation/uikit/uitouch)
- [UIKit: isMultipleTouchEnabled](https://developer.apple.com/documentation/uikit/uiview/ismultipletouchenabled)
- [UIKit: isExclusiveTouch](https://developer.apple.com/documentation/uikit/uiview/isexclusivetouch)
- [Creating a custom keyboard](https://developer.apple.com/documentation/uikit/creating-a-custom-keyboard)
- [UIInputViewController](https://developer.apple.com/documentation/uikit/uiinputviewcontroller)
- [UITextDocumentProxy](https://developer.apple.com/documentation/uikit/uitextdocumentproxy)
- [UIInputView.allowsSelfSizing](https://developer.apple.com/documentation/uikit/uiinputview/allowsselfsizing)
- [Accessibility HIG](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [Xterm control sequences](https://invisible-island.net/xterm/ctlseqs/ctlseqs.html)
