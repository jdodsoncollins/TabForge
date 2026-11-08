# App Store preview videos

The 1.1.1 previews: two per device (iPhone 6.9", iPad 13", iPhone Duo), 15–17 seconds each.

- **Editing:** real key presses in the playground: Tab, ⌘ →, Return with auto-indent, Outdent and bracket pairing on iPhone; Outdent, Tab, Delete line, ⌘ → and Return on iPad; bracket pairing and ⌘ ← / ⌘ → on the closed Duo.
- **Themes:** the iOS Standard glass in light mode, a live switch to dark mode, Darcula from the gear menu, then the Terminal · ANSI input profile.

Every frame of app UI comes from a native Simulator screen recording, at normal speed with straight cuts. Each cut opens about half a second before the key's visible effect. The composition adds the listing's plain background, a headline and a caption naming the key being pressed. The iPad themes preview ends on a 2.3-second still of the recording's last frame, because the test quits the app right after.

## Reproduce

Work in an ignored folder such as `artifacts/previews-<version>/`, because the takes and renders are large media files:

```sh
mkdir -p artifacts/previews-1.1.1 && cp -R release-prep/previews/* artifacts/previews-1.1.1/
cd artifacts/previews-1.1.1
```

1. Build the app and UI tests for the simulator into `artifacts/screens-1.1.1/derived`, as in the screenshot workflow.
2. Record each take. `record.py` creates a fresh simulator, seeds the playground draft, records the screen with `simctl io recordVideo` while `AppStoreCaptureTests.testRecordAppPreview` presses the keys, and saves the `PREVIEW-MARK` timings. The themes take switches the simulator to dark appearance when the test reaches its `appearance-dark` mark. A closed Duo records its outer display, `primary`.

   ```sh
   python3 record.py phone "iPhone 18 Pro" com.apple.CoreSimulator.SimRuntime.iOS-27-2
   python3 record.py themes-phone "iPhone 18 Pro" com.apple.CoreSimulator.SimRuntime.iOS-27-2
   python3 record.py duo "iPhone Duo" com.apple.CoreSimulator.SimRuntime.iOS-27-2-iPhone19-4 primary
   ```

3. Find when each edit becomes visible with `python3 changes.py <take> <x> <y> <w> <h> <from> <to> [threshold]`. Simulator keyboard input shows up 1.2–1.5 seconds after the test's mark. Put the cut points and caption beats in `remotion/src/previews.ts`.
4. Copy the takes into `remotion/public/`, then `npm ci` and `npx remotion render <id> out/<id>.mp4 --codec=h264 --crf=14 --pixel-format=yuv420p` in `remotion/`.
5. `python3 encode.py` re-encodes each render with the October settings: H.264 High 4.0, 30 fps CFR, 10 Mbps CBR, BT.709, silent stereo AAC 48 kHz and fast start. It fully decodes each file and checks the 15–30 second limit and canvas size.
6. Upload with `asc video-previews upload --replace`, then set poster frames with `asc video-previews set-poster-frame`.

Remotion 4.0.537 is a media-tooling dependency only and is not part of the app. Its [license](https://github.com/remotion-dev/remotion/blob/main/LICENSE.md) applies.
