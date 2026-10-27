# Testing tips without payment

TabForge has three separate purchase test levels. Each answers a different question; a passing mock or local transaction does not establish that the App Store catalog works in TestFlight.

## App-state tests

[`TipStoreTests`](../UnitTests/TipStoreTests.swift) supplies a mock storefront to check success, cancellation, pending approval, errors, duplicate delivery, and repeated taps. These tests need no Apple account or payment. They verify TabForge's handling of results, without opening Apple's checkout or validating products in App Store Connect.

Mock results belong in the test target. The distributed app must acknowledge success only after StoreKit returns a verified transaction for a configured consumable tip.

## Local Apple transactions

The development-only **ScriptKeyboard-Tips** scheme selects [`TipJar.storekit`](../Configuration/TipJar.storekit). [`TipStoreKitTests`](../UnitTests/TipStoreKitTests.swift) and [`TipJarUITests`](../UITests/TipJarUITests.swift) use `SKTestSession` to control Apple's local test environment. With `disableDialogs = true`, purchases complete without an interactive confirmation, letting tests assert verified transactions, repeated tips, and the app's thank-you state. This exercises StoreKit itself rather than returning a mock success.

An active local StoreKit environment needs no Apple Account, payment method, or connection to App Store servers. Its configured prices and transactions are test data. Apple documents [local testing setup](https://developer.apple.com/documentation/xcode/setting-up-storekit-testing-in-xcode) and [suppressing interactive dialogs](https://developer.apple.com/documentation/storekittest/sktestsession/disabledialogs).

For a checkout presentation or cancellation test, set `disableDialogs = false` and interact with Apple's local confirmation. An Apple Account sign-in prompt does not prove that the intended local checkout is active; do not enter credentials just to make that local test pass. Capture the actual surface and investigate the configuration or runtime separately.

Give every local StoreKit run exclusive ownership of its simulator and wait for the previous `xcodebuild` process to finish before starting another. Use separate derived-data and result directories for isolated investigations. Apple states that [all `SKTestSession` instances control one test environment](https://developer.apple.com/documentation/storekittest/sktestsession), so changing settings concurrently can overwrite another test's configuration. A serial test plan cannot coordinate separate `xcodebuild` processes.

## TestFlight sandbox purchases

Apps downloaded from TestFlight always use Apple's sandbox for In-App Purchases. Apple simulates successful transactions without processing actual payments. Test the real configured product identifiers, localized prices, Apple confirmation, verified completion, cancellation, and repeated consumable purchases. A placeholder product slug or a hardcoded success bypass would leave that integration untested. See [Apple's sandbox testing guide](https://developer.apple.com/documentation/storekit/testing-in-app-purchases-with-sandbox).

The local `.storekit` file is not the TestFlight catalog and is not bundled in the distributed app. Configure products in App Store Connect and meet Apple's agreement and account requirements. A separate Sandbox Apple Account provides sandbox controls; it is not a mechanism for making a TestFlight purchase free, because those transactions already use the sandbox. Follow Apple's account instructions when those controls are needed.

## October 21 investigation

Earlier Duo runs overlapped on one simulator; one UI launch terminated another run's hosted test app. A fresh, exclusive simulator still reproduced the native cancellation failure in 31.391 seconds and displayed an Apple Account sign-in alert. The sign-in alert was not counted as a successful local checkout.

A source trial using SwiftUI's scene-aware [`PurchaseAction`](https://developer.apple.com/documentation/storekit/purchaseaction) then passed the unchanged native cancellation test in 28.265 seconds, and the focused `xcodebuild` run exited successfully. A broader isolated Duo run also exited successfully in 92.28 seconds with all 18 local checks passing: 15 mock methods, one native lifecycle test, and two UI tests. The lifecycle test verified all five prices, two Kind Tip purchases, and Ask to Buy approval. The UI tests covered native cancellation (26.492 seconds) and repeated tips with Back navigation (32.610 seconds). The exported screenshot and accessibility hierarchy show the native Xcode Kind Tip confirmation with an explicit no-charge test message. These results supersede the earlier local Duo checkout failure; they do not establish reliability across every device or runtime.

Phone and iPad each passed the native cancellation and repeat-tip UI tests, adding four passing runs with zero failures. The serial two-device command exited successfully in 163.31 seconds. Together with Duo, these are 22 focused checks.

The scene-aware change is in version 1.0.1 (15), whose signed archive/export passed all 24 artifact checks. Apple processed it as VALID and it remains available to the existing internal TestFlight group. Testing notes match the saved copy and strict TestFlight validation has no issues. The version and all five tips were submitted on October 21, 2026 and are WAITING_FOR_REVIEW, with release after approval configured. Build 14 is superseded and does not contain the change. No completed physical TestFlight sandbox purchase has been verified by this investigation. Record that separate result before claiming the distributed purchase integration is tested.
