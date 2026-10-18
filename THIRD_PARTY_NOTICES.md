# Third-party notices and asset provenance

TabForge's original code and documentation are available under the [MIT license](LICENSE). The upstream notices below apply to the identified palette material and must be retained when redistributing it. TabForge's license does not replace Apple's platform terms or grant rights in third-party names and trademarks.

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

## Swipe vocabulary and researched alternatives

`Sources/KeyboardCore/SwipeDecoder.swift` contains TabForge's small, deterministic swipe recognizer and an embedded list of ordinary programming and English words. It does not bundle a third-party dictionary, training corpus, neural model, or SDK.

The [swipe-engine research](docs/swipe-engine-research-2026-10-17.md) discusses Ortholinear, FUTO Swipe, KeyboardKit, and other candidates. None is integrated or redistributed by this version. Their licenses are separate from TabForge's MIT license and must be reviewed, with notices and any distribution obligations addressed, before importing code, dictionaries, or model weights.
