# US English listing copy

Version 1.0.1 (15) and its five consumable tips were submitted on October 21, 2026. The version, parent review and each tip read WAITING_FOR_REVIEW, with release type AFTER_APPROVAL. Build 15 remains VALID and available to the existing internal TestFlight group. All 22 focused simulator checks and 24 archive/export checks passed; testing notes match the saved copy and strict TestFlight validation has no issues. The six-item submission succeeded with zero blockers. The live version 1.0 (12) remains on the App Store. This update adds the optional Tip Jar and Paper & Grain in Other Apps.

The approved main description is retained with a short optional-support paragraph. Reviewer notes explain all five consumable tips, Apple purchase handling and the absence of feature unlocks. What's New includes the Other Apps addition. [Build 15 TestFlight guidance](testflight-build15-en-US.txt) covers scene-aware checkout and free sandbox testing; build 13/14 notes are preserved as historical guidance. The Humanizer 3.1.0 pass covered the edited copy. Name, subtitle, keywords, promotional text and the existing 31 screenshot captions/header copy are unchanged. Version 1.0.1 metadata and build 15 TestFlight notes match the local copy exactly; the description and reviewer notes are unchanged. All 31 inherited screenshots and all three 16-second App Previews are COMPLETE; preview MD5 checksums match local files. One header placement is inherited.

The October 21 [website policy](https://www.jeremycollins.net/tabforge/privacy) is published and freshly verified live. Its reviewed [source copy](privacy-policy-en-US.md) explains Apple's payment handling, fixed English/programming vocabularies, bounded in-memory deduplication and no TabForge backend, upload or purchase history. The public Data Not Collected label was freshly verified. Preserve private account records and reviewer contact fields outside public copy.

## Prepared presentation

- **Name:** TabForge: Code Keyboard
- **Subtitle:** Programming and terminal keys
- **Opening image heading:** A keyboard for writing code
- **Categories:** Developer Tools primary and Utilities secondary are saved. The keyboard's programming workflow is its central purpose; categories reflect that use rather than a chart target.
- **Promotional text:** see `promotional-text-en-US.txt`.
- **Description:** see `description-en-US.txt`.

`app-info-en-US.json` and `version-en-US.json` use App Store Connect's canonical field names. The Support URL points to the repository's `docs/SUPPORT.md`, which includes the owner's approved public support email, GitHub Issues and private security reporting. The canonical Marketing URL is `https://www.jeremycollins.net/tabforge` and the Privacy Policy URL is `https://www.jeremycollins.net/tabforge/privacy`. Both were freshly verified HTTP 200. The Support URL stays on GitHub because it provides contact and reporting guidance. The saved Marketing and Privacy Policy URLs read back exactly. The live product page describes optional Apple-operated tips while all features remain free; the published October 21 policy matches the submitted implementation. Preserve private App Review contact information separately. This update includes `whatsNew` from [whats-new-en-US.txt](whats-new-en-US.txt).

The local audit and exact Unicode/UTF-8 field lengths are in `validation.json`. Keywords are all ASCII, so the recommended field fits both Apple's 100-byte platform reference and the product-page guidance's 100-character wording. `validate.py` recomputes the audit after edits. File terminators are excluded from listing text. Passing `--staging-dir artifacts/submission-2026-10-21/metadata` also writes the app-info and version localization files. The ignored release-artifact directory holds ASC identifiers and validation receipts separately from this public copy directory.

## Search choices

The name supplies “code keyboard”; the subtitle adds “programming” and “terminal.” The keyword field adds closely related tasks and controls without repeating the title, subtitle or category. No competing app names, paid claims, rankings, unrelated languages, or speculative Apple Intelligence/swipe/dictation terms are used as acquisition keywords. “Remote” and “desktop” refer to the literal input profile, with the host's limits stated in the description.

Astro MCP was not available in this session. There is no measured keyword volume, difficulty, rank or conversion evidence behind these choices. This is a relevance-based launch draft, not a proven ranking forecast. Use post-release App Analytics and properly authorized keyword tools to test it. Descriptions are written for understanding and external web discovery, not stuffed with repetitions for App Store ranking. No claim is made that screenshot text is indexed; that is not established in the Apple primary sources checked.

## Voice and tone

Use ordinary prose, concrete actions and real app UI. Describe a small, inspectable tool with useful programming controls. Avoid emphatic fragments, decorative punctuation, em dashes, generic superlatives, invented productivity statistics and desktop-equivalence claims. Do not copy existing keyboard taglines.

The six screenshots follow [the current storyboard](../design/storyboard.md):

| Image | Heading | Supporting copy |
| --- | --- | --- |
| 1 | A keyboard for writing code | Keep braces, brackets and Tab within reach. |
| 2 | Indent without leaving the keys | Indent or outdent a line and keep your place. |
| 3 | Keep terminal controls close | Use Escape, arrows and modifiers from the keyboard. |
| 4 | Choose your keyboard theme | Follow the iOS appearance or choose a code palette. |
| 5 on phones | Make room for your work | A compact landscape layout leaves more space for your app. |
| 5 on larger layouts | Use the space you have | A larger layout makes room for numbers, symbols and editing keys. |
| 6 | See how your keyboard works | Read the MIT licensed source, privacy policy and security guidance. |

The fifth image adapts to the actual device capture; it is one image per device set. Do not put all controls into every phone image: compact height and width determine which keys are visible. Image 3 also states that terminal shortcuts depend on the client forwarding them. Show at least one dark appearance. Voice and experimental swipe are not opening-image claims. A header uses the same ordinary language and stays separate from the six screenshots.

## Release readiness checks

The [release-readiness review](../readiness.md) separates the 1.0.1 candidate checks from the live build 12 and older evidence. For future App Review submissions:

1. Verify a matching new binary has no Full Access request, App Group entitlement or sharing code, and that keyboard settings/snippet management works in the extension without altering host text during snippet editing.
2. Verify the companion has no persistent keyboard controls: previews use only memory while the playground draft remains saved independently.
3. Publish the matching website policy, repository support/privacy documents, and listing/reviewer copy through the authorized release process, then read them back. Changing these local files does not change any remote destination.
4. Keep App Privacy publication separate from the source privacy manifest. Local-only processing supports the prepared Data Not Collected recommendation; do not claim the questionnaire is published without checking its actual state.
5. Refresh screenshots whose settings or preview UI changed, and record processing, order, crop safety and source checksums. Earlier complete media receipts describe the older UI.
6. Verify the saved price, private review contact and intended release setting. Re-run applicable readiness checks against the new binary; older zero-warning results are historical evidence.
7. Expose only accessibility claims whose complete criteria have been verified. Simulator labels and layout checks do not establish physical assistive-technology flows, palm rejection or immunity to extension termination.

## Sources checked

Apple primary documentation:

- [Product-page composition](https://developer.apple.com/app-store/product-page/): distinct name, subtitle, short feature-led description, genuine UI screenshots, dark appearance, metadata limits and forbidden keyword classes.
- [App Store search](https://developer.apple.com/app-store/search/): relevance of title, subtitle, keywords and categories, avoid duplicates and unrelated/competitor terms, measure performance after release.
- [Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information): field limits, 100-byte keyword field, plain-text description, contact-bearing Support URL, initial-version What's New behavior.
- [Review guideline 4.4.1](https://developer.apple.com/app-store/review/guidelines/#keyboard-extensions): keyboard switching, operation without Full Access and extension launch restrictions.
- [App privacy details](https://developer.apple.com/app-store/app-privacy-details/): local-only processing versus collection and required public policy URL.
- [Creative-asset specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications): product-page header placement, resolution and opacity requirements.

Comparable public listings (positioning evidence, not verified efficacy or keyword-rank data):

- [Shell Keyboard](https://apps.apple.com/us/app/shell-keyboard/id6811290737): terminal controls and configurable ANSI behavior; Developer Tools positioning.
- [TypeTab: Coding Keyboard](https://apps.apple.com/us/app/typetab-coding-keyboard/id6800613590): programming symbols, snippets, indentation and layout controls; Developer Tools positioning.
- [Code keyboard](https://apps.apple.com/us/app/code-keyboard/id1097372399): language keywords, operator access and themes.
- [Cboard - Code Keyboard](https://apps.apple.com/us/app/cboard-code-keyboard/id1479683196): paired delimiters and iPad orientation.

Their claims are not copied or treated as compatibility guarantees. TabForge's source remains the authority for this draft's feature promises.
