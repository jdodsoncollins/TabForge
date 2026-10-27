# TabForge Privacy Policy

Last updated October 27, 2026. Questions about this policy can be sent to [jeremy@jeremycollins.net](mailto:jeremy@jeremycollins.net).

TabForge's app and keyboard contain no analytics, advertising, account system, or TabForge-operated networking service. The optional companion Tip Jar uses Apple's StoreKit service as described below. The keyboard does not send keystrokes, surrounding text, snippets, swipe gestures, or spelling requests to a TabForge server. The code is available for inspection under the repository's [MIT license](https://github.com/jdodsoncollins/TabForge/blob/main/LICENSE).

This document describes TabForge's implementation. It does not describe the data practices of the app you type into, your terminal or remote-desktop service, Apple system features, GitHub, or your device backup provider.

## What stays in memory

The extension receives text and field information that iOS and the host app expose through `UITextDocumentProxy`. It uses this context for local editing, indentation, completions, cursor movement, and optional spelling correction. The host can limit or withhold context. TabForge does not build a keystroke history or save the host document.

The optional swipe recognizer, autocorrect, and English suggestions use fixed, bundled English and programming vocabularies with word frequencies. TabForge does not download words or add typed words to them. To rank corrections, suggestions, and swipe matches, the keyboard also reads words from the text the host exposes around the cursor; that list is kept only in memory and never saved. Gesture traces, tap points, and alternatives are transient; they are not uploaded or used to train a model. Swipe is experimental and off by default.

Optional English prose correction uses Apple's `UITextChecker` on the device to decide which words are misspelled. Replacements are chosen on the device from the bundled vocabulary and nearby document words, weighing where each key was tapped. Tap points for the word being typed are held in memory until Space and then discarded. When enabled, the extension can request Apple's supplementary keyboard lexicon, which may include names and text-shortcut entries. TabForge keeps a bounded set in memory to avoid correcting those words; it does not save or log that lexicon. Spelling resources, correction state, swipe traces, repeat tasks, and held-key state are released when the keyboard is dismissed or receives a memory warning. Ordinary operating-system memory management still applies; this is not a secure-memory-erasure guarantee.

**Learn my tap positions** is a separate keyboard option, off by default and available only with autocorrect. When turned on, the keyboard keeps a running average of how far your taps land from the center of each letter key, plus a capped count of taps per key, and uses it to judge future taps. It records only from words already in its vocabulary that you typed and kept. It stores no letters in order, words, text, or timestamps. The averages are saved in the keyboard extension's local `UserDefaults` and never leave the device. Turning the option off erases them.

## What is saved on the device

| Data | Purpose | Storage |
| --- | --- | --- |
| Keyboard preferences | Restore layout, profile, theme, and editing choices | The keyboard extension's local `UserDefaults` |
| Custom snippets | Insert text the user intentionally saves | Stored with the keyboard extension's preferences |
| Learned tap offsets (optional, off by default) | Per-letter-key average tap offset and capped sample count, to improve autocorrect | The keyboard extension's local `UserDefaults`; erased when the option is turned off |
| Companion playground draft | Restore the playground between launches | The app's local `UserDefaults` |

The extension's typing context is separate from the companion playground draft. Text entered or inserted into the playground is deliberately saved, including a voice transcript after the user inserts it. Do not put secrets in drafts or snippets.

The companion's keyboard and layout previews use a separate, in-memory set of settings and snippets. Preview changes are discarded when that app process ends. They do not configure the installed keyboard and are not saved as companion keyboard preferences. The playground draft remains saved independently.

These records use the iOS application sandbox and the device's normal storage protections. TabForge adds no separate encryption or password protection to preferences, snippets, or drafts. Device backups and operating-system retention rules may apply.

Resetting keyboard preferences in the keyboard clears its current settings and custom snippets, and turns tap learning off, which erases learned offsets; it does not clear the companion playground draft. Delete or replace the playground text separately. Removing the app and keyboard removes their installed containers subject to iOS behavior; backups may retain prior data.

## No Full Access or shared container

This version does not request keyboard Full Access and does not configure an App Group. Keyboard settings and custom snippets are managed from the keyboard's gear menu and saved in its own container. The companion app does not read, write, or synchronize those records.

Snippet names and text are edited in the keyboard's own settings interface. An unfinished snippet edit stays in memory until saved or cancelled; editing a snippet does not type its draft into the host app. The keyboard inserts a saved snippet into the host only when the user selects it for insertion.

The update retains an existing keyboard-local settings record when one is present. It does not read, import, or erase an older App Group record or the companion app's old keyboard preferences. Settings or snippets that existed only in those old locations are not automatically transferred. Those legacy records may remain under iOS storage and backup rules; removing the sharing capability is not a guarantee of erasure.

## Voice, dictation, and Writing Tools

The keyboard extension does not record microphone audio. It leaves the system dictation affordance available where iOS provides it; users can also switch to the Apple keyboard.

The companion playground's **Voice to code** feature starts only after a user action and requests microphone and Speech Recognition permissions. Its Speech request requires on-device English recognition. If that capability or language support is unavailable, TabForge does not fall back to cloud recognition. Audio buffers are passed to Apple's on-device Speech service; the app does not write recordings to a file. The transcript remains in the voice view until the user dismisses it or inserts it into the saved playground draft. Recording is cancelled on dismissal, backgrounding, or relevant audio interruption.

System Dictation and Writing Tools are controlled by Apple and the user's system settings. Their data handling is outside TabForge's on-device voice implementation. Review Apple's disclosures before invoking those features with sensitive material.

## Optional tips through Apple

The companion app's Tip Jar uses Apple's StoreKit service to load products and process optional, one-time tips. Tips do not unlock features or start a subscription. All app and keyboard features remain free to use. The keyboard extension has no purchase flow and shares no settings, snippets, or typing context with the companion app.

Apple presents the purchase confirmation and handles payment information through its own network, account, and payment infrastructure. TabForge receives product and transaction results locally to display prices, handle cancellation or pending approval, verify completed tips, and finish transactions. It holds a bounded set of recent transaction identifiers in memory to avoid duplicate acknowledgements. It does not keep receipts, a tip total, or a purchase history in app preferences or files.

TabForge does not send typing, snippets, playground text, or speech to StoreKit. It has no purchase backend, transaction upload, analytics service, or TabForge account. Apple maintains its own transaction records; not keeping app records does not remove Apple's records. Apple's handling of account, payment, and purchase information is described in [App Store & Privacy](https://www.apple.com/legal/privacy/data/en/app-store/).

## Text sent to other apps and external links

When used as an extension, TabForge inserts text into the selected host app. That app may store or transmit it, including to a remote terminal or desktop. TabForge cannot control the recipient's processing. iOS substitutes the system keyboard in secure/password and phone fields, and apps may reject third-party keyboards.

The playground's **Share code** action sends the current draft to the system share sheet only when the user chooses it. The selected destination then receives that text and handles it under its own policies. Review the draft and recipient before sharing.

Opening a repository or other external link is a user-initiated action handled by the system/browser. The destination receives an ordinary web request under its own privacy policy. TabForge does not attach typing context to these links.

The keyboard extension does not launch the companion app. Configure the installed keyboard from its gear menu. The companion app contains setup and compatibility information, source/privacy links, credits, and licenses; it does not contain controls for the installed keyboard. Licenses & notices reads bundled documents locally.

## Diagnostics and reports

TabForge contains no typed-text logging or automatic diagnostic uploader. Apple may provide crash reports, TestFlight feedback, and device diagnostics according to the user's system and testing choices. The project does not intentionally add document text to those reports.

Use synthetic examples when filing bugs and check screenshots and logs before sharing. For a suspected leak or vulnerability, follow [security policy](https://github.com/jdodsoncollins/TabForge/blob/main/SECURITY.md) and avoid a public issue containing private text.

The public [source repository](https://github.com/jdodsoncollins/TabForge) includes implementation details, license notices, and [repository privacy documentation](https://github.com/jdodsoncollins/TabForge/blob/main/PRIVACY.md). This policy must be updated when the app changes its permissions, storage, dependencies, or data flow.
