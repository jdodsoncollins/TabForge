# Companion Tip Jar

Version 1.0.1 (15) and all five consumable tips were submitted on October 21, 2026. The version, parent review and each tip are WAITING_FOR_REVIEW; release after approval is configured. Build 15 uses SwiftUI's scene-aware purchase action, is VALID and remains available to the existing internal TestFlight group. It passed 22 focused checks across Duo, phone and iPad, plus all 24 archive/export checks. The live version 1.0 (12) has no Tip Jar. The submitted tips have the exact US base prices below, en-US metadata, review screenshots and matching territory availability. Submission and local tests do not establish approval or a completed physical TestFlight sandbox purchase.

## Products and presentation

Tips are optional, repeatable **consumable** In-App Purchases. They unlock no features, grant no credit balance, and start no subscription. The app and keyboard remain free to use. There is no durable entitlement for a Restore Purchases button to restore.

| Name | Product ID | Intended US base price |
| --- | --- | --- |
| Kind Tip | `tip.kind` | $0.99 |
| Thoughtful Tip | `tip.thoughtful` | $1.99 |
| Wonderful Tip | `tip.wonderful` | $2.99 |
| Incredible Tip | `tip.incredible` | $3.99 |
| Extraordinary Tip | `tip.extraordinary` | $4.99 |

These public identifiers are app-scoped catalog keys, not a maintainer's bundle ID or account credentials. A fork can create the same IDs under its own app or change both the source catalog and its local StoreKit configuration together. No signing team, private bundle ID, profile, or App Store Connect key belongs in this document or the test configuration.

The UI uses StoreKit's [`Product.displayPrice`](https://developer.apple.com/documentation/storekit/product/displayprice) after the product loads. US amounts in this table are setup targets, not fallback purchase labels. Other storefronts use the localized price returned by Apple. An unavailable product must stay disabled; it must not show an invented price or initiate a substitute purchase.

## Purchase and privacy boundaries

The Tip Jar belongs only to the companion app. It does not add StoreKit to `KeyboardCore`, shared keyboard UI, or the extension, and does not request Full Access, App Groups, tracking permission, or a TabForge account. It receives no host document, snippets, swipe traces, playground draft, or speech.

The app loads product information through StoreKit and opens Apple's purchase confirmation only after a user selects a tip. Build 15 supplies the initiating view's scene-aware purchase action; transaction verification remains in the store adapter. A cancelled purchase is not an error or a completed tip. A pending purchase remains unacknowledged as success until a later verified result arrives. Failures and disabled purchases leave the app usable. These outcomes are distinct in Apple's [`Product.PurchaseResult`](https://developer.apple.com/documentation/storekit/product/purchaseresult).

An app-scoped listener processes [`Transaction.updates`](https://developer.apple.com/documentation/storekit/transaction/updates), so leaving the Tip Jar does not discard a later purchase result. Only verified transactions for configured consumable tip products are acknowledged and [finished](https://developer.apple.com/documentation/storekit/transaction/finish()). There is no app-managed receipt, purchase history, or tip total persisted to preferences or files. StoreKit's transaction records remain under Apple's control.

Apple handles account, payment, and purchase information under [App Store & Privacy](https://www.apple.com/legal/privacy/data/en/app-store/). TabForge adds no purchase backend, third-party payment SDK, analytics, account linkage, or transaction upload. The app receives transaction results locally; payment handling by Apple is not a claim that no transaction data exists.

The release review supports retaining **Data Not Collected**, and the public label was freshly verified. Apple's [App Privacy guidance](https://developer.apple.com/app-store/app-privacy-details/) excludes inaccessible payment details entered outside the app and on-device-only processing. It requires disclosure of data a developer collects through Apple services. This app keeps only bounded transaction identifiers in memory and has no transaction upload, server, analytics or saved purchase history. The matching October 21 [website policy](https://www.jeremycollins.net/tabforge/privacy) is published and freshly verified live; its reviewed text is retained in [release copy](../release-prep/copy/privacy-policy-en-US.md). See [PRIVACY.md](../PRIVACY.md) for the exact boundary; a future data-flow change needs another review.

## Reproduce local tests

For the difference between mock checks, local Apple transactions, and free TestFlight sandbox purchases, see [Testing tips without payment](storekit-testing.md).

Use Xcode 27.1 or later and an installed iOS 27 simulator. The development-only **ScriptKeyboard-Tips** scheme selects [`Configuration/TipJar.storekit`](../Configuration/TipJar.storekit) and the serial [`TipJar.xctestplan`](../TipJar.xctestplan). Use that scheme for the native StoreKit and Tip Jar screen tests. The normal **ScriptKeyboard** scheme runs the mock-store purchase tests, excludes those StoreKit-dependent suites, and has no StoreKit configuration in its Run action. App and extension resources do not include the configuration. Local StoreKit purchases use test data and do not charge a customer; they do not validate the remote catalog. See Apple's [StoreKit testing setup](https://developer.apple.com/documentation/xcode/setting-up-storekit-testing-in-xcode).

Regenerate from the public spec and run the model, native StoreKit and screen tests:

```sh
xcodegen generate
xcodebuild -project ScriptKeyboard.xcodeproj -scheme ScriptKeyboard-Tips \
  -destination 'platform=iOS Simulator,id=<SIMULATOR_UDID>' \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:ScriptKeyboardTests/TipStoreTests \
  -only-testing:ScriptKeyboardTests/TipStoreKitTests \
  -only-testing:ScriptKeyboardUITests/TipJarUITests test
```

In Xcode, run **ScriptKeyboard-Tips**, open Settings → Tip Jar, and use the StoreKit transaction manager to exercise:

- All five correct localized products and prices, plus missing products, an empty catalog, a failed load, and Retry.
- A successful tip followed by the same tip again, ensuring verified transactions finish and no feature changes.
- Cancellation, purchase failure, failed verification, and disabled purchases without a success message.
- Pending approval resolved after leaving and reopening the screen, and an unfinished transaction received after relaunch.
- Repeated taps while a purchase is in progress, and dismissal during purchase without starting duplicate payments.
- Light/dark appearance, large Dynamic Type, VoiceOver labels and focus, reduced motion, narrow phone, landscape phone, iPad, and Duo layouts.

Automated model tests and local StoreKit scenarios are separate from sandbox and physical-device checks. Record the exact tests run and failures observed; this guide is not evidence that these checks passed.

### Submission evidence and remaining checks

On October 21, all 88 core tests across ten suites and all five build-configuration checks passed; the later companion changes do not change their source. Before the build 15 purchase change, phone and iPad passed the 15 mock-store methods, native StoreKit lifecycle checks and complete Tip Jar UI runs, including full-screen navigation and landscape checks. Build 14's final normal/largest-text Other Apps phone checks passed after the canonical URL change, with all three cards reachable and at least 44 points in each dimension; their captures were reviewed.

Duo's build 15 source checks supersede the earlier local checkout failure: the isolated scene-aware cancellation test passed, followed by an 18-check run covering the 15 mock methods, native lifecycle, cancellation and repeated tips with Back navigation. Phone and iPad each passed the cancellation and repeat-tip UI tests, for 22 focused checks across three simulators. The actual Xcode Kind Tip confirmation and its no-charge test message were visually checked. Duo's earlier largest-text case passed. See [StoreKit testing](storekit-testing.md) for exact timings and scope. Actual Duo landscape/pose checks, real TestFlight sandbox/device purchases and physical VoiceOver remain unverified.

An artificial cancellation-error injection produced an unmappable Apple test-server error and was replaced by the actual checkout-close test. Native lifecycle scenarios share one local test session to avoid resetting synthetic transaction IDs while the app-scoped listener is active. The initial fresh iPad run revealed inactive local StoreKit configuration in the normal scheme; purchase integration suites now require the separate Tips scheme.

Build 15's signed archive/export passed all 24 artifact checks, preserving canonical URLs, companion-only Paper & Grain artwork and the absence of Full Access, signed App Group entitlements, test configuration and private files. Its VALID processing, existing internal TestFlight access, exact testing notes and clean strict TestFlight validation are verified. The six-item submission succeeded with zero blockers; version 1.0.1, its parent review and all five tips read WAITING_FOR_REVIEW. Post-submission purchase validation has no errors, warnings, informational results or blockers. The canonical product/privacy pages and Data Not Collected label are published and verified. Build 14's receipts are historical. See [release readiness](../release-prep/readiness.md) for the remaining physical-device checks.

## Configure a distribution's App Store catalog

1. Use your own app record and signing configuration as described in the [build instructions](../README.md#build-and-enable). Keep private identifiers and credentials in ignored local files.
2. Have the Account Holder complete the applicable Paid Apps Agreement, banking, and tax setup. Apple's [configuration overview](https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/overview-for-configuring-in-app-purchases/) explains the requirements for sandbox testing and distribution.
3. Under the app's In-App Purchases, [create five consumable products](https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/create-consumable-or-non-consumable-in-app-purchases/) with the exact IDs above. Set names, localization, review screenshot and notes, intended US base prices, availability, and the applicable tax category. Check the resulting prices and storefront availability rather than assuming a price tier maps to every currency.
4. Test a signed build against the real sandbox catalog with the local StoreKit configuration disabled. Confirm all five products load, transaction handling works, and purchase restrictions, cancellation, pending approval, and retry behave correctly. TestFlight uses a test purchase environment; verify the system sheet rather than making a production payment during development.
5. Review the live privacy policy, App Privacy answers, release notes, and reviewer instructions. Apple's [submission guide](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase/) requires the first consumable purchases to accompany a new app version in the same review submission. Do not modify an already distributed build or claim that this source candidate is approved.

The maintainer's version 1.0.1 and five tips are submitted and awaiting review. A fork needs its own catalog and submission; this result does not confer approval on either distribution.
