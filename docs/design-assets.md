# Screenshot and design assets

The images in [images](images) show TabForge running in Apple's iOS Simulator, displayed by Device Hub. The Swift example is synthetic. The device chassis, camera cutouts and Duo hinge positions come from actual Simulator views. The Duo tabletop image was captured with the device partially opened; its lower display contains the keyboard. These images do not claim physical-device testing.

The published README figures are whole-device crops with proportional resizing and WebP encoding. An exterior-only connected white mask removes plain Simulator window background outside the hardware and preserves the opaque display and chassis pixels. No keys, text, controls, fold geometry or app screens were generated or painted into those figures. Capture window chrome, pointers and Simulator controls were excluded from the crops. `release-prep/design/export-readme-images.mjs` reproduces the exports from private local capture files.

| Asset | What it shows |
| --- | --- |
| `keyboard-iphone.webp` | Regular iPhone portrait keyboard |
| `keyboard-ipad.webp` | iPad keyboard with numbers and symbols |
| `keyboard-duo-closed.webp` | Duo closed with the wider phone layout |
| `keyboard-duo-open.webp` | Duo open with the expanded layout |
| `keyboard-duo-tabletop.webp` | Duo partially opened, with the keyboard on the lower display |

The App Store screenshot renderer also uses unchanged native app captures inside Apple's installed Simulator corner and edge artwork. Straight bezel sections are extended to the captured display size, while corner geometry is preserved. Additional Duo theme and Settings UI captures are composed proportionally inside the same real flat-open chassis, using an outline measured from the native display; they do not invent fold geometry. It uses Apple's framebuffer masks and retains the real camera-island pixels from a native capture when the legacy sensor PDF is empty. Theme comparisons, keyboard detail insets and compact landscape screens remain genuine captured UI. Private render receipts record the source hashes, crop bounds and composition steps. Phone and tablet export slots can share the same captured device within a larger marketing canvas; the frame continues to represent that captured device.

Apple's device artwork and trademarks belong to Apple and are not offered under this repository's MIT license. The repository includes finished TabForge screenshots, not Apple's original Simulator resource files. The images do not imply endorsement by Apple.

The separate product-page header is brand artwork. It is not evidence of keyboard behavior or a device capture. It should remain separate from the native screenshot provenance.

Source/settings slides are refreshed separately when the companion information changes. Their recorded native UI capture can change while the real Simulator chassis and other keyboard/pose figures remain the same. Keyboard appearance examples show actual keyboard states rather than a companion theme-picker page.

The companion's Other Apps cards use the published icons for Codable, Taktung, and Paper & Grain. The Paper & Grain image is the unchanged 512-pixel JPEG from its [App Store listing](https://apps.apple.com/us/app/paper-grain/id6821361967), bundled locally so opening Settings does not fetch an icon over the network.
