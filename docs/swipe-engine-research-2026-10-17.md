# Swipe engine research — October 17, 2026

The October 17 evaluation started with a small geometric matcher over 259 unique code-oriented words. It resampled paths to 32 points and ranked template distance. It had no broad English dictionary, word-frequency prior, elastic path alignment, or sentence-context model. The subsequent source iteration is described below; build 11 retains the earlier decoder.

None of the engines or models surveyed here is integrated. Swipe remains experimental. The source now includes separately licensed English dictionary data, with [pinned provenance and reproduction](swipe-lexicon.md).

## October 18 source iteration after build 11

A synthetic key-center path for `testing` reproduced the reported `typeof` result. `testing` was absent from the original dictionary, so the decoder could never return it. Other missing words produced similar substitutions, including `programming` → `padding` and `developer` → `docker`.

The source iteration adds 38,604 English word forms from a pinned, filtered ESDB size-35 list. The implementation remains TabForge's own geometric decoder. A reusable endpoint index avoids scanning the whole dictionary for each gesture. Geometry is normalized separately by horizontal and vertical key pitch, so a row error remains significant in compact landscape. A bounded shortlist of 48 candidates receives elastic alignment within four samples to tolerate rounded corners. Invalid, stationary, and poorly matching paths are declined. No frequency or sentence-context model, adaptive learning, network request, or user trace collection was added.

The dictionary/index is loaded on the first eligible swipe and released with transient resources on dismissal or memory pressure. It does not delay ordinary tap-key initialization. Decoding still runs synchronously at gesture completion; development-Mac timing does not establish responsiveness inside a physical keyboard extension.

`Tests/KeyboardCoreTests/SwipeDecoderTests.swift` covers the original report, 42 ordinary/code words across four rendered-style geometries and four synthetic path styles, repeated letters/uneven sampling, invalid inputs, and poor shapes with matching endpoints. A rounded `status` path initially ranked `statues` above it; elastic reranking corrected that regression without weakening the acceptance targets.

For a separate fixed comparison, [Scripts/evaluate-swipe.swift](../Scripts/evaluate-swipe.swift) evaluates 97 mixed words and ten repeated-letter words across six synthetic geometry proportions, using sparse vertices, dense straight segments, and rounded corners with deterministic jitter. These are regression fixtures, not a held-out human accuracy study. The English list covers 95 of the 97 mixed words; `username` and `localhost` remain outside it. Ambiguities such as `god`/`good`, paths passing through extra collinear keys, and heavily rounded paths remain limitations.

The [verification summary](verification.md) records this iteration's tests and measured synthetic results. The procedure below remains necessary before claiming system-keyboard quality or choosing a replacement engine.

## Candidates

| Candidate | Verified capability and licensing | Assessment |
| --- | --- | --- |
| [FUTO Swipe](https://swipe.futo.tech/) | Published on-device neural models plus dictionary-constrained beam decoding. The official project identifies the C++ inference library as GPL; model weights have a separate license. | Strong candidate for an accuracy evaluation. It is not an iOS keyboard SDK; integration, runtime size, and extension memory remain unverified. |
| [Ortholinear](https://github.com/IgorVaryvoda/Ortholinear) | Native Swift 6 iOS keyboard. Its geometric decoder adds elastic alignment, word frequency, and context scoring. Source is MIT, while bundled generated language data is CC BY-SA 4.0. | Best lightweight native source candidate to evaluate. Adapting internal types and respecting data licenses are required. |
| [KeyboardKit 11](https://keyboardkit.com/blog/2026/10/01/keyboardkit-11-is-out) | The vendor explicitly says it does not include a swipe typing engine. Version 11 supplies a drag overlay and layout information for an engine supplied by the app. | Adding KeyboardKit or purchasing Pro would not replace TabForge's decoder. |
| [GlideTypeAI](https://github.com/daniel-silva-perez/glide-type-ios) | MIT pure-Swift offline path decoder. The project describes itself as an MVP; three commits were visible at review. | Useful reference, without evidence of a mature replacement. |
| [AnySoftKeyboard](https://github.com/AnySoftKeyboard/AnySoftKeyboard) / [FlorisBoard](https://github.com/florisboard/florisboard) | Apache 2.0 Android projects. AnySoftKeyboard lists gesture typing; FlorisBoard is a Kotlin Android keyboard in beta. | Source references or porting projects, not drop-in iOS dependencies. |
| [WM Keyboard](https://github.com/wasi-master/wmkeyboard) | MIT Android/Kotlin project documenting trie/beam decoding, n-gram ranking, and glide typing. | Another algorithm reference; no iOS integration verified. |
| [HeliBoard](https://github.com/HeliBorg/HeliBoard) | GPLv3 Android keyboard; its README says glide requires a separately supplied closed-source library. | Does not provide an open iOS decoder shortcut. |

### FUTO: separate model and implementation terms

The [current model card](https://huggingface.co/futo-org/futo-swipe/blob/main/README.md) lists an approximately 2.65 MB universal encoder, an optional 1.25 MB English/QWERTY decoder, and a 6.25 MB English context model. These are file sizes, not runtime RAM measurements. The universal encoder accepts layout geometry; the specialized decoder and context model are English-specific.

The [FUTO Model Weights License 1.0](https://huggingface.co/futo-org/futo-swipe/blob/main/LICENSE.md) permits commercial use subject to visible attribution and its other terms. It expressly separates weights from inference code and datasets. The [C++ swipe library](https://gitlab.futo.org/keyboard/swipe-library) has separate GPL terms; the Android keyboard application's Source First license must not be substituted for either license. Any implementation choice needs its own license compatibility check. The published benchmark is encouraging, but does not establish accuracy or RAM use inside TabForge's extension.

### Ortholinear: source and data terms

Reviewed source revision: `e81e82a9dafaf7d6db1bb2f7a70087e81209917a`. The [MIT source license](https://github.com/IgorVaryvoda/Ortholinear/blob/main/LICENSE) covers the implementation. [DictionaryCredits.txt](https://github.com/IgorVaryvoda/Ortholinear/blob/main/Core/SuggestionData/DictionaryCredits.txt) separately identifies generated lexicon data as CC BY-SA 4.0, with upstream notices and provenance. MIT does not cover all bundled assets.

The [decoder](https://github.com/IgorVaryvoda/Ortholinear/blob/main/Core/GlideDecoder.swift) is an internal Swift type using key-space geometry, banded dynamic time warping, frequency/context priors, prefix filtering, and cancellation checks. The [package](https://github.com/IgorVaryvoda/Ortholinear/blob/main/Package.swift) processes both English and Ukrainian data; English lexicon/context files are about 5.4 MB/420 KB, Ukrainian about 5.9 MB/984 KB. Loading only required assets would need explicit integration work. The [glide tests](https://github.com/IgorVaryvoda/Ortholinear/blob/main/Tests/GlideTests.swift) cover jittered and corner-cut synthetic traces, taught words, cancellation, and timing. They do not establish independent real-user accuracy. Forty-three commits were visible; this is promising source, not a verified production SDK for TabForge.

### Other constraints

KeyboardKit is actively maintained, but its [current repository](https://github.com/KeyboardKit/KeyboardKit) identifies the SDK as a closed-source binary. Its advertised swipe support must be distinguished from recognition. A subscription budget has not been established, and no paid license, trial subscription, or purchase was authorized or initiated.

Historical [Fleksy documentation](https://docs.fleksy.com/keyboard-sdk/guides/getting-started-with-flutter) describes an iOS SDK requiring license credentials and Full Access for network validation/downloads. Current official site and repository endpoints could not be verified as available during this review. Cached documentation is insufficient evidence to recommend a supported new integration.

Apple's [custom keyboard guide](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/CustomKeyboard.html) documents custom input, supplementary lexicons, and extension restrictions. There is no documented public QuickPath recognition engine in that API surface. Public spelling/text-input APIs are useful for autocorrection, but do not decode a continuous finger path into words for a custom keyboard.

## Recommended evaluation after this beta

Compare the existing decoder, an adapted Ortholinear approach, and FUTO models behind the same internal interface. Keep the current UIKit renderer and device geometry. A candidate should earn adoption from measured accuracy and extension cost; no rewrite of the entire keyboard is justified by this research alone.

Use a consented, held-out set of real finger traces. Partition by person and session before tuning; never tune thresholds on the final test set. Synthetic traces remain regression tests, not the main quality evidence. Do not log surrounding user documents or upload typing by default. Include ordinary English, code words, identifiers outside the dictionary, punctuation, repeated letters, short ambiguous words, and deliberately cancelled gestures.

| Dimension | Required cases and measurements |
| --- | --- |
| Devices/layouts | Regular iPhone portrait and compact landscape; Duo closed portrait/landscape, open, and tabletop; iPad full width and narrow/floating widths where supported. Include normal and larger key settings. |
| Recognition | Top-one and top-three accuracy, out-of-vocabulary rate, word error rate for sentences, false swipe activation during fast taps, and cancelled-gesture insertion rate. Report common words and code identifiers separately. |
| Touch variation | Left/right hand, different users, fast/slow paths, off-center endpoints, corner cutting, uneven sampling, repeated letters, overlapping taps, and a second finger cancelling/interfering with a glide. |
| Responsiveness | End-of-gesture to candidate display/commit at p50/p95/p99; UI main-thread stalls; typing responsiveness while decoding; cancellation and stale-result behavior after mode, field, or geometry changes. |
| Cold extension | Fresh process, first keyboard appearance, first model/dictionary load, and first decoded word. Record time to usable keys and memory before/after loading. Repeat cold samples on physical devices. |
| Warm extension | Repeated sentences after warm-up; peak and steady resident/physical memory, retained caches after dismissal, allocations per decode, and CPU/energy use over a sustained session. |
| Lifecycle | Repeated appearance/dismissal, rotation/folding during pending work, rapid app/field switching, language/profile changes, cancellation, memory warning, and recovery after system termination. |
| Offline/privacy | No Full Access and network disabled; required dictionaries/models available locally; attribution and data notices included; no unexpected network or learning behavior. |

Before comparing accuracy, require zero stale commits after cancellation or field changes, zero text insertion from a cancelled gesture, and no new failures in tap/chord/Unicode/accessibility tests. Use identical trace sets, geometry, build configuration, and hardware for before/after results. Report confidence intervals or sample counts rather than a single favorable percentage.

As initial engineering targets, keep warmed decode work off the main thread where possible, aim for p95 candidate presentation within 50 ms after lift, and require no measurable tap latency regression. These are proposed acceptance targets, not current measurements or Apple guarantees. Establish a measured extension memory budget on supported physical devices before loading models; include runtime and dictionary overhead, not just model file size. A candidate must stay within that budget in both cold and sustained runs, release recreatable state under pressure, and restart cleanly after termination. No implementation can guarantee that iOS will never purge a keyboard extension.
