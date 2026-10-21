# Keyboard responsiveness and memory

Research and implementation audit: October 17, 2026.

## What iOS guarantees

Apple runs a custom keyboard in a separate process with a device-dependent memory limit. Exceeding it can terminate the extension. Dismissing the keyboard does not guarantee that its memory is released. Test the extension itself on multiple device models and respond to memory warnings by dropping expendable state. There is no supported way to keep a keyboard permanently resident, and no universal memory budget that can be promised.

Source: [Creating a custom keyboard](https://developer.apple.com/documentation/uikit/creating-a-custom-keyboard).

Apple recommends launching extensions well under one second, keeping their interface focused, and avoiding blocking their main run loop. Extensions have substantially less memory available than foreground apps.

Source: [App Extension Programming Guide: Creating an App Extension](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/ExtensionCreation.html).

Memory warnings are best effort. A fast rise in system pressure can cause termination before a warning arrives. A warning handler should release known disposable objects quickly instead of traversing the entire object graph looking for savings. Device jetsam reports distinguish memory termination from an ordinary application crash.

Sources: [Responding to low-memory warnings](https://developer.apple.com/documentation/xcode/responding-to-low-memory-warnings), [Identifying high-memory use with jetsam event reports](https://developer.apple.com/documentation/xcode/identifying-high-memory-use-with-jetsam-event-reports).

## Applied to TabForge

- The extension uses a reusable UIKit key grid and opens its settings interface only when requested. Speech capture belongs to the companion app. There are no network services, model downloads, document-wide formatters, or continuously running background jobs in the typing path.
- Suggestions live in the combined gear menu. The menu is refreshed when candidates change or a verified swipe replacement changes its action generation. Theme colors and haptic feedback generators are reused instead of recreated for each key.
- Keyword lists are prepared once. Local completion scans inspect at most the last 4,096 characters and stop after three results. Identifiers longer than 128 characters receive no completion, avoiding replacement of a truncated prefix.
- The current local optimization pass requests that bounded context before extracting it from a native editor. Ordinary letters bypass delimiter checks; arrows and paired deletion request only adjacent characters. Complete context is retained for quote escape parity and edits that need verified line/document boundaries.
- Unchanged settings updates skip control styling and completion scans. Unchanged modifier state also skips redundant control updates. Extension appearance and companion editor focus explicitly refresh context after transient cleanup.
- The companion editor caches compiled syntax rules and a line-start index shared by the cursor label and gutter. Character edits invalidate the index; cursor movement and each visible gutter line use binary lookup. Duplicate cursor/selection notifications no longer repeat context work or publish unchanged labels.
- A swipe gesture retains at most 256 sampled points before compacting its history. Its drawn path is also compacted; completed or cancelled paths are released.
- Swipe builds its offline English/programming endpoint index on first use and reuses it until settings change, dismissal, or memory pressure. Recognition filters endpoint buckets, normalizes key pitches, and elastically reranks at most 48 candidates. It runs synchronously on lift; [synthetic timing](verification.md) is development evidence, not a physical extension latency or memory guarantee. Ordinary tap-key initialization does not load the dictionary.
- Dismissal and memory warnings cancel repeat-delete and status tasks, clear gesture/candidate state, and remove previews. The extension's own preferences remain in local UserDefaults so a new keyboard process can restore them. Full Access and App Groups are not requested. Companion keyboard/layout previews use an independent memory-only preferences store.
- The reusable key grid is a UIView rather than a UIInputView subclass. A captured ownership path showed UIKit's `_UIInputViewContent` retaining an unused grid created outside a text-input host. After removing that extra input-service wrapper, the weak-reference deallocation test passes, including cancellation of a pending status task. The extension controller and actual text-input host still own their system input-view containers.
- No private APIs, background-audio keep-alive, or requests to inflate an extension's memory limit are used.

## Adaptive geometry

Width tiers use the actual usable keyboard width: Compact below 460 pt, Wide phone from 460 pt, Expanded from 650 pt, and Studio from 768 pt. This gives wider closed phones more keys and gives open Duo and full-width iPad the same Studio layout. Narrow iPad windows and floating keyboards fall back naturally.

On iOS 27.1, active fold and camera regions exclude keys and suggestions. A wide horizontal division identifies tabletop geometry; TabForge requests the area below that division and adds Escape, Home, End, and extra terminal arrows. A vertical book fold keeps the keyboard split around its gutter. Placement and final height remain under iOS and host-app control, so a keyboard extension cannot take over an arbitrary portion of another app's display.

The optional **Extra editing row on wide layouts** setting exposes the seven-row layout on any keyboard at least 650 pt wide, even if the host doesn't supply horizontal fold geometry. It adds a dedicated editing/navigation row while retaining the full symbol and number rows. Terminal mode also exposes Up, Down, Page Up, and Page Down.

Sources: [Configuring a custom keyboard interface](https://developer.apple.com/documentation/uikit/configuring-a-custom-keyboard-interface), [Designing for iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo).

## Verification scope

Core and hosted tests cover long documents, layout geometry, preference restoration, transient cleanup, and keyboard view deallocation. The performance test drives 1,000 UIKit key actions per iteration through text edits and suggestion updates. Simulator figures describe the shared renderer in the companion host; they are not an extension memory-limit measurement or a guarantee against device jetsam.

An earlier Duo Simulator 27.1 run averaged **0.075 seconds for 1,000 actions** (0.65% relative standard deviation), with a **58.8 MB total host-process peak**. These historical figures must not be used as a baseline for later runs with a different simulator/process state. The local optimization audit records its own matching workload comparison. Action handling and text work are measured, not touch-to-display latency. Test ordering, simulator frameworks, and the companion app affect the total footprint; it is not comparable to an extension's device budget.

The captured host memgraph reported 20 unidentified 32-byte blocks (640 bytes total). No app-owned type was identified in that leak list. The retained keyboard was rooted through UIKit's content association, not reported as an unreachable leak. The source change and deallocation test address that ownership path; no claim of zero framework leaks is made. Evidence lives under `artifacts/qa/memory/before/`.

Device Hub subsequently established an actual horizontal tabletop pose, and the build 6 lower-panel UI check passed without skips. XCTest orientation metadata alone does not establish hinge geometry. The full key row is also covered at six widths in all three input profiles; see the [verification report](verification.md).

Real-device extension memory, cold launch under system pressure, system dictation, and terminal/Remote Desktop forwarding still require hardware and client-specific checks. Record TestFlight failures with the device model, OS, host app, input profile, and any jetsam report. Avoid including typed source or secrets in diagnostic logs.
