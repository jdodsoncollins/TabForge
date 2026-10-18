# Keyboard accessibility and compact layouts

This document describes the current design and its verification requirements. It is not a claim that the keyboard has passed a complete assistive-technology or physical-device audit. Candidate 1.0 (7) retains the keyboard verified by build 6's full matrix and corrects a decorative icon in the layout guide. Completed runs, repeated checks, and their limits are recorded in the public [verification summary](verification.md).

## Height and reachability

Keyboard height is independent of key capacity. Width chooses the compact phone, wide phone, expanded, studio, or tabletop arrangement. A separate height policy chooses whether to show the extra rows.

| Height setting | Requested behavior |
| --- | --- |
| Automatic | Use compact height when the host has a compact vertical size class or its available height is at most 500 points. |
| Compact | Request four typing rows, including in a large window. |
| Full | Request the normal rows for the available width and saved row settings. |

The request uses stable host/scene geometry, not the keyboard's current height. A compact request is `4 × (44-point key + 4-point row gap) + 8-point padding = 200 points`, plus the renderer's top and bottom safe-area insets. The system can provide additional keyboard chrome outside the renderer. Opening Fn does not change this request.

The host can still constrain an input view below its requested size. An emergency display fallback pages away extra rows when the full grid would be too compressed. That fallback does not lower the stable requested height or overwrite the user's Full preference. If even four rows cannot fit, their actual height follows the host's allocated area; 44-point targets are not guaranteed under arbitrary host clipping. `UIInputView.allowsSelfSizing` lets UIKit consider an input view's fitted size; it does not give an extension unrestricted control of the host's layout. See [Apple's sizing API](https://developer.apple.com/documentation/uikit/uiinputview/allowsselfsizing).

Compact height removes the toolbar, dedicated programming-symbol row, automatic number row, and extra navigation row. Three QWERTY rows and the bottom typing row remain, with Tab directly available. Fn exchanges the three upper rows for navigation, modifiers, indentation, symbols, editing tools, and settings. Number and punctuation pages remain available through 123 / ABC. Fn is visible on both pages and reports which page is active.

Regular iPhone landscape and a closed Duo in landscape should use compact height because vertical space is short. Small phone widths and short iPad windows use the same capacity and height rules; device names do not force a dense layout. Open Duo and larger iPad windows retain the full rows when height permits. A detected horizontal Duo tabletop division takes priority over the height preference and requests the dedicated lower panel. iOS and the host determine the final area. Floating keyboards, Split View, and unusual host scene sizes still require direct validation.

## Targets, labels, and actions

Apple's current accessibility guidance lists a **44 × 44-point default** and **28 × 28-point minimum** control size for iOS and iPadOS. Dense keyboard columns can be narrower than the default. These numbers are a design reference, not proof that every key meets the minimum in every constrained or folded window. Verify the expanded hit region, visual spacing, and actual accessible frame together. See [Apple's Accessibility HIG](https://developer.apple.com/design/human-interface-guidelines/accessibility).

Keys expose keyboard-key traits, meaningful labels, and accessible frames matching their expanded touch regions. Delimiters have spoken names such as “Open brace”; arrows and icon-only actions have text labels. Letter labels track the displayed case. Voice Control input labels include visible titles or their spoken equivalents. Hidden toolbar controls are excluded from the compact accessibility order, and visible controls follow reading order.

Shift reports Off, On for next key, or Caps Lock. A named Caps Lock accessibility action provides an alternative to a timed double tap. Ctrl, Option, and Command can be tapped to latch the next key, so a chord does not require holding two fingers. Their selected state and value report when they are active. Fn also reports pending modifiers when the modifier row is hidden. Shortcut support still depends on the selected profile and host.

The grid attempts to preserve focus on the same action when rebuilding. A changed page may remove the previous action, so actual VoiceOver focus recovery and Switch Control scanning must be tested. Status messages are announced and do not consume touches. Swipe typing and cursor scrubbing are disabled while VoiceOver or Switch Control runs; all essential operations remain available as buttons or menu actions.

## Text and visual presentation

Companion information screens use native SwiftUI text styles and full Dynamic Type. Their headers change to vertical arrangements at accessibility text sizes. Installed-keyboard settings belong to its gear interface; companion previews do not configure them. The layout guide's decorative icon uses a fixed 22-point font inside its 24-point frame so it does not overlap a heading at the largest text size. The dense keyboard grid uses bounded `UIFontMetrics` scaling so labels can grow without making keys overlap; it does not promise the full accessibility text-size range inside each key. Bold Text increases label and symbol weight. The Key height setting affects full layouts; compact height keeps its fixed four-row request.

Snippet editing uses a keyboard-owned draft panel and the existing keys. Verify access to Name/Text, the draft value and cursor, Save, Cancel, and Clear without relying on a host text field. Draft entry must remain available without changing the host document. This new panel needs its own large-text, VoiceOver, keyboard-height and lifecycle checks; the earlier full-grid matrix below does not establish that coverage.

Keyboard palettes use opaque background fills, with selected state shown through borders and accessibility values as well as color. The swipe path has no implicit path or color animations. There is no animated page transition required to use Fn. Review every palette in light/dark appearance, Increased Contrast, Reduce Transparency, and Reduce Motion on a device before asserting coverage.

## System boundaries

The extension uses public [`UIInputViewController`](https://developer.apple.com/documentation/uikit/uiinputviewcontroller) and [`UITextDocumentProxy`](https://developer.apple.com/documentation/uikit/uitextdocumentproxy) APIs. A proxy exposes text editing and contextual cursor movement, not arbitrary remote hardware-key events or the system keyboard's private touch classifier. Unsupported shortcuts show a message rather than typing an unmodified character. Terminal bytes work only when the host forwards them appropriately.

## Verification and remaining device checks

Build 6's complete keyboard matrix passes 51 core tests in seven suites and 51 hosted UIKit test methods on each of iPhone 18 Pro (iOS 27.0), iPad Pro 11-inch M5 (iPadOS 27.0), and Duo (iOS 27.1). Coverage includes height policy, row geometry, labels/state, and overlapping presses. Compact companion UI checks pass on all three simulator families, and the Duo horizontal-tabletop test passes with zero skips after Device Hub sets the simulated device pose. The extension's actual height in a third-party host was not directly tested.

Candidate 7's hosted repeats pass all 51 methods on each of iPhone, iPad and Duo, with zero failures or skips. Its final largest-accessibility-text UI run passes in 120.7 seconds, covering theme selection, expanded settings rows, a persisted Compact preference, the Fn preview, and the layout guide. The final screenshot confirms that the decorative icon stays clear of the heading. The keyboard code is unchanged from the build 6 matrix; see [current verification](verification.md) for receipts and publication status.

Native Duo captures verify closed-landscape typing, Fn at the same height, full rows after opening, and tabletop placement. Programmatic control events and simulator captures do not validate a physical digitizer or an assistive technology's complete interaction model. The following coverage remains outstanding:

- Exercise actual VoiceOver typing, case announcements, Caps Lock action, Fn focus transitions, menus, and status announcements.
- Exercise Switch Control scanning and Voice Control names, including repeated letters, duplicate actions, and icon controls.
- Confirm the largest accessibility text sizes and Bold Text on physical devices, including all themes; automated largest-text layout and font/state checks already pass.
- Confirm small phones, ordinary landscape phones, closed/open/tabletop Duo and short iPad windows on hardware. Floating keyboards and Split View remain unverified; do not assume simulator geometry covers them.
- Check simultaneous physical fingers, palm/edge contacts, Touch Accommodations, hardware-keyboard coexistence, and terminal/remote-client forwarding.
