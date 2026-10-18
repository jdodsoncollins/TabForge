# Optimization audit — October 17, 2026

The local working tree now reduces repeated work in keyboard input and the companion editor. These changes are included in the published TestFlight beta **1.0 (8)**. The matching measurements below were captured before build 8’s combined menu and optional autocorrect additions; they are not a new measurement of the complete release. iOS/iPadOS 27.0 remains the minimum, with guarded 27.1 Duo geometry.

## Changes and evidence

- **Bound text context before extraction.** Ordinary text bypasses delimiter pairing entirely. Pairing/deletion and plain arrows request adjacent graphemes; completions, word arrows and Home/End request the existing 4,096-character window. Native and memory adapters slice at valid character boundaries. Nil context, UTF-16 selection offsets, emoji, combining marks and CRLF remain covered. Full context remains available for quote escape parity and operations requiring verified document/line boundaries. Spy regressions verify which context is requested, rather than relying on timing assertions.
- **Reuse the editor's line index.** An array of LF line starts serves both the cursor label and visible gutter. Text-storage character edits invalidate it, including equal-length edits; selection changes and each gutter line use binary lookup. Columns count user-perceived characters only within the current line. Duplicate selection notifications skip repeated context work, and unchanged cursor labels are not published to SwiftUI.
- **Cache syntax rules.** Compiled regular expressions are cached per programming language. Match enumeration avoids building an array of every match. Recoloring preserves selection, Dynamic Type, Bold Text and appearance/contrast behavior. Changing the bound language now explicitly recolors unchanged source.
- **Skip redundant keyboard updates.** Identical settings skip repeated control styling and context scans. Ordinary key presses no longer restyle unchanged modifier controls. Preference changes, trait changes, held/latching transitions and accessibility activation retain their updates. Both extension appearance and companion focus explicitly restore context after transient cleanup; a same-selection refocus regression covers this path.

Preferences write only when settings are assigned. Swipe history/path bounds, gesture-end decoding, cancellation, weak ownership and on-demand formatting showed no comparable high-confidence hot-path issue in this review. No extra background jobs or dependencies were added.

## Matching simulator measurements

Debug configuration, Xcode 27.1, **Script Keyboard Duo / iOS 27.1**, same four-test selection and order, parallel testing disabled. Each figure is the mean of five measured iterations. Setup and cache warmup occur outside the measured blocks; workload is unchanged between runs.

| Workload | Before | After |
| --- | ---: | ---: |
| 100 cursor-label refreshes, same selection at end of 10,000-line source | 418.52 ms | 0.093 ms |
| 500 unchanged keyboard-settings applications | 15.235 ms | 0.136 ms |
| 1,000 UIKit key actions, text edits and completion refreshes | 205.84 ms | 186.41 ms |
| Five syntax highlights, 83,250 UTF-16 units each | 121.42 ms | 115.55 ms |
| Total test-host peak during key-action benchmark | 44.04 MB | 44.52 MB |

The action workload improved about **9.4%**. The cursor measurement tests repeated label refreshes with a warm index, not physical cursor motion or the first refresh after an edit. Syntax highlighting remains synchronous and scans the full document below its existing 120,000-unit cutoff; this pass does not implement incremental parsing. The line index scales with actual line count and rebuilds lazily once after character edits. Regex caching retains only small language rule sets, not document contents.

The roughly 0.48 MB increase in total host peak is a measured tradeoff, not a memory saving. Net physical-memory changes during individual action iterations were noisy and are not interpreted as leak measurements. A separate full hosted-suite run reached a higher process peak after accessibility/font tests; it is saved separately and excluded from the matching comparison.

These simulator microbenchmarks measure the shared renderer/editor in the companion process. They do not establish touch-to-display latency, extension memory usage on a device, cold-start performance under pressure, or immunity from jetsam. No new device memgraph or Instruments trace was captured in this pass. Multiple other project simulators remained booted throughout; they were left untouched.

## Verification

- **57 core tests / eight suites pass**, including six new context-request and Unicode boundary regressions.
- **59 hosted test methods pass on each family:** iPhone 18 Pro (27.0), iPad Pro 11-inch M5 (27.0), Duo (27.1). Parameterized cases also cover the width/height matrix, compact/Fn layouts, themes, overlapping presses, cancellation and deallocation. No failures or skips remain in the final applicable runs.
- Four iPhone UI flows pass: navigation/modifiers/language switching, Delete Line/Tab/outdent, compact landscape/Fn settings, and bracket pairing/opening app settings.
- The initial combined iPhone run passed 62 tests and failed one UI method because the test assumed the long system menu's offscreen app-settings action already existed. The harness now scrolls within the menu; that method passes in its focused rerun. Product menu behavior was unchanged. A Swift 6 isolation error in the new test helper was also corrected before the successful hosted runs.
- `git diff --check` passes. Simulator signing is disabled for these tests; this pass does not replace release signing/archive validation. QA iPhone/iPad simulators returned to Shutdown and Duo remained booted.

Receipts under `artifacts/qa/`: `optimization-baseline.json`, `optimization-baseline-metrics.json`, `optimization-matched-after.json`, `optimization-after-metrics.json`, `optimization-comparison.json`, `optimization-duo-tests.json`, `optimization-ipad-tests.json`, `optimization-phone-initial-tests.json`, `optimization-phone-menu-rerun.json`. Initial phone failure attachments are in `optimization-phone-menu/`; the full-suite metrics are `optimization-full-hosted-metrics.json`.

Physical extension memory pressure, system dictation, actual assistive-technology typing, edge/palm rejection and terminal/Remote Desktop forwarding retain the hardware/client limits recorded in [verification](verification.md).
