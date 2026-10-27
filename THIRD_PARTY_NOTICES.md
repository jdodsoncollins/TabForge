# Third-party notices and asset provenance

TabForge's original code and documentation are available under the [MIT license](LICENSE). The upstream notices below apply to the identified palette and dictionary material and must be retained when redistributing it. TabForge's license does not replace Apple's platform terms or grant rights in third-party names and trademarks.

The app currently has no third-party package dependency. Its Swift package dependency is the local `KeyboardCore` target. The app uses Apple's system frameworks rather than bundling their implementations.

## Nord palette

The Nord option in `Sources/KeyboardUI/KeyboardPalette.swift` adapts colors from [Nord](https://github.com/nordtheme/nord), with TabForge-specific assignments to keyboard surfaces and text. No Nord theme engine is included. The [upstream license](https://github.com/nordtheme/nord/blob/develop/license), verified October 17, 2026, is reproduced below.

```text
MIT License (MIT)

Copyright (c) 2016-present Sven Greb <development@svengreb.de> (https://www.svengreb.de)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Dracula palette

The Dracula option in `Sources/KeyboardUI/KeyboardPalette.swift` adapts colors from the [Dracula open-source palette](https://github.com/dracula/dracula-theme), with TabForge-specific key and secondary-text colors. No Dracula theme engine is included. The [upstream license](https://github.com/dracula/dracula-theme/blob/main/LICENSE), verified October 17, 2026, is reproduced below.

```text
The MIT License (MIT)

Copyright (c) 2023 Dracula Theme

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Darcula inspiration

The Darcula option is an independently implemented keyboard palette inspired by JetBrains' Darcula appearance. It does not include JetBrains source code, theme files, icons, or fonts. The name identifies the visual inspiration; JetBrains does not sponsor or endorse TabForge.

## Apple system symbols, fonts, and frameworks

The interface requests SF Symbols through SwiftUI and UIKit system-image APIs and uses system fonts. No SF Symbols artwork files, Apple font files, or Apple framework binaries are redistributed in this source repository. Their use in an app remains subject to Apple's applicable licenses and platform agreements; the TabForge MIT license does not relicense them. See [Apple's SF Symbols information](https://developer.apple.com/sf-symbols/).

## App icons

The Light, Dark, and Tinted PNGs in `App/Assets.xcassets/AppIcon.appiconset/` were created and revised with an AI image-generation tool for this project. They were not copied from another keyboard's icon. Their prompts, revisions, and export steps are documented in [the icon design notes](docs/icon-design.md). They are included with the project under its MIT license to the extent the project can grant rights in the generated artwork. No exclusive rights in generic keyboard shapes or platform symbols are claimed.

## Other Apps artwork

The companion app’s Other Apps page includes bundled promotional icons for Jeremy Collins’s [Codable](https://apps.apple.com/us/app/codable/id1324741659) and [Taktung](https://apps.apple.com/us/app/taktung-deployment-status/id6805738660). `CodableMark.imageset` and `TaktungMark.imageset` were supplied from the developer’s existing app resources. The icons are static resources; displaying them makes no network request and adds no third-party runtime dependency.

The product names and icons identify Jeremy Collins’s apps and remain the developer’s marks and artwork. The TabForge MIT license grants no trademark rights or permission to imply endorsement of another product. The App Store links open only when the user chooses them.

## English swipe vocabulary

`Sources/KeyboardCore/Resources/swipe-english.txt` includes 38,604 generated word forms from Kevin Atkinson's English Speller Database (ESDB), formerly SCOWL. This data has the permission notice below; TabForge's MIT license does not replace it. The pinned source, checksum, filtering, and reproducible importer are documented in [the vocabulary provenance](docs/swipe-lexicon.md). The keyboard uses this bundled resource offline; it does not download dictionaries or learn from typing.

```text
Copyright 2000-2026 by Kevin Atkinson
Permission to use, copy, modify, distribute, and sell any part of the English
Speller Database (ESDB, previously known as SCOWLv2), or word lists
created from it, is hereby granted without fee, provided that the above
copyright notice appears in all copies and that both the above copyright
notice and this notice appear in supporting documentation.  Kevin Atkinson
makes no representations about the suitability of this database for any
purpose.  It is provided "as is" without express or implied warranty.
ESDB is derived from many sources, most of which are in the Public Domain.
Data from the Corpus of Contemporary American English (COCA) was also used.

All data from COCA comes from 3-gram data that is not freely available;
however, the usage is within the rights given by the NDA that was signed when
purchasing the data.  More information on COCA is available at
https://www.english-corpora.org/coca/.
The primary source of words for ESDB comes from 12dicts and ENABLE2K.  Both
are in the Public Domain, but Alan Beale <biljir@pobox.com> deserves special
credit as he is the author of 12dicts and a major contributor to ENABLE2K.  In
addition, he gave me an incredible amount of feedback and created a number of
special lists in order to help improve the overall quality of ESDB.
```

## Researched swipe alternatives

The [swipe-engine research](docs/swipe-engine-research-2026-10-17.md) discusses Ortholinear, FUTO Swipe, KeyboardKit, and other candidates. None of those engines, dictionaries, models, or SDKs is integrated or redistributed. TabForge's decoder remains its own implementation. Their separate licenses must be reviewed before any future integration.
