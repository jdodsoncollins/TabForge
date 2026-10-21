# Companion Tip Jar

Version 1.0.1 (14) is VALID and available to the existing internal TestFlight group. Readback confirms build 14 is selected in the unsubmitted App Store draft. It adds Paper & Grain to Other Apps without changing the Tip Jar flow; its archive/export and all 24 artifact checks passed. The live version 1.0 (12) has no Tip Jar. All five consumable drafts have the exact US base prices below, en-US metadata, review screenshots and availability matching the app's territories. They are not submitted or approved. Local StoreKit purchases do not establish that the remote catalog works in the sandbox or is on sale.

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

The app loads product information through StoreKit and opens Apple's purchase confirmation only after a user selects a tip. A cancelled purchase is not an error or a completed tip. A pending purchase remains unacknowledged as success until a later verified result arrives. Failures and disabled purchases leave the app usable. These outcomes are distinct in Apple's [`Product.PurchaseResult`](https://developer.apple.com/documentation/storekit/product/purchaseresult).

An app-scoped listener processes [`Transaction.updates`](https://developer.apple.com/documentation/storekit/transaction/updates), so leaving the Tip Jar does not discard a later purchase result. Only verified transactions for configured consumable tip products are acknowledged and [finished](https://developer.apple.com/documentation/storekit/transaction/finish()). There is no app-managed receipt, purchase history, or tip total persisted to preferences or files. StoreKit's transaction records remain under Apple's control.

Apple handles account, payment, and purchase information under [App Store & Privacy](https://www.apple.com/legal/privacy/data/en/app-store/). TabForge adds no purchase backend, third-party payment SDK, analytics, account linkage, or transaction upload. The app receives transaction results locally; payment handling by Apple is not a claim that no transaction data exists.

The release review supports retaining **Data Not Collected** for this implementation. Apple's [App Privacy guidance](https://developer.apple.com/app-store/app-privacy-details/) excludes inaccessible payment details entered outside the app and on-device-only processing. It requires disclosure of data a developer collects through Apple services. This app keeps only bounded transaction identifiers in memory and has no transaction upload, server, analytics or saved purchase history. The [matching policy draft](../release-prep/copy/privacy-policy-en-US.md) must be published before the App Store update is released. See [PRIVACY.md](../PRIVACY.md) for the exact boundary; a future data-flow change needs another review.

## Reproduce local tests

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

### Candidate evidence and remaining checks

On October 21, all 88 core tests across ten suites and all five build-configuration checks passed; the later companion changes do not change their source. Phone and iPad passed the 15 mock-store methods and native StoreKit lifecycle checks. Their complete Tip Jar UI runs passed, including full-screen navigation and landscape checks with the corrected orientation wait. Final normal/largest-text Other Apps phone checks passed after the canonical URL change, with all three cards reachable and at least 44 points in each dimension; their captures were reviewed.

Duo's standard Tip Jar retest passed all five displayed prices, two repeated local tips and Back navigation. Its largest-text case passed earlier. The native checkout still stalled in Apple's local test sheet, so the full Duo suite is not counted as passing. Actual Duo landscape/pose verification remained unavailable because Device Hub was locked. Real TestFlight sandbox/device purchases and physical VoiceOver interaction remain unverified.

An artificial cancellation-error injection produced an unmappable Apple test-server error and was replaced by the actual checkout-close test. Native lifecycle scenarios share one local test session to avoid resetting synthetic transaction IDs while the app-scoped listener is active. The initial fresh iPad run revealed inactive local StoreKit configuration in the normal scheme; purchase integration suites now require the separate Tips scheme.

The final signed version 1.0.1 (14) archive/export passed all 24 artifact checks, including compiled canonical URLs, absence of the old privacy route and companion-only Paper & Grain artwork. Apple processed build 14 as VALID and reports internal beta testing. The existing automatic all-builds internal TestFlight group has access, build 14 testing notes are saved and strict TestFlight validation reports no errors, warnings, informational results or blockers. Independent source review found no material production defect. The App Store draft and five first consumables are assembled as six review items, but have not been submitted. The successful staging result confirms build 14 attached to version 1.0.1. These facts do not establish approval or production product availability. See [release readiness](../release-prep/readiness.md) for the remaining website, agreement and sandbox checks.

## Configure a distribution's App Store catalog

1. Use your own app record and signing configuration as described in the [build instructions](../README.md#build-and-enable). Keep private identifiers and credentials in ignored local files.
2. Have the Account Holder complete the applicable Paid Apps Agreement, banking, and tax setup. Apple's [configuration overview](https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/overview-for-configuring-in-app-purchases/) explains the requirements for sandbox testing and distribution.
3. Under the app's In-App Purchases, [create five consumable products](https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/create-consumable-or-non-consumable-in-app-purchases/) with the exact IDs above. Set names, localization, review screenshot and notes, intended US base prices, availability, and the applicable tax category. Check the resulting prices and storefront availability rather than assuming a price tier maps to every currency.
4. Test a signed build against the real sandbox catalog with the local StoreKit configuration disabled. Confirm all five products load, transaction handling works, and purchase restrictions, cancellation, pending approval, and retry behave correctly. TestFlight uses a test purchase environment; verify the system sheet rather than making a production payment during development.
5. Review the live privacy policy, App Privacy answers, release notes, and reviewer instructions. Apple's [submission guide](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase/) requires the first consumable purchases to accompany a new app version in the same review submission. Do not modify an already distributed build or claim that this source candidate is approved.

Remote drafts are prepared for the maintainer’s app, while a fork needs its own catalog. Version 1.0.1 is staged as an App Store draft, but neither that version nor the purchase products have been submitted for review. Confirm each remaining release step separately.
