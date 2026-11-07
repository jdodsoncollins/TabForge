# TabForge support

For support, email [jeremy@jeremycollins.net](mailto:jeremy@jeremycollins.net). You can also [contact the TabForge maintainers through GitHub Issues](https://github.com/jdodsoncollins/TabForge/issues) for bugs or feature requests. Search existing issues first, then [open an issue](https://github.com/jdodsoncollins/TabForge/issues/new) if you cannot find an answer. GitHub requires an account to post. Reports and replies are public.

Do not post passwords, private code, transcripts, contact names, account details, or unredacted screenshots and logs. Reproduce the problem with a short, invented example.

## Set up the keyboard

1. Open iOS Settings → General → Keyboard → Keyboards → Add New Keyboard, then choose TabForge.
2. In a text field, hold the globe key and select TabForge.
3. Tap the keyboard's gear for editing tools, quick preferences, complete keyboard settings, and custom snippet management. Configure the installed keyboard there, or with the same gear on the companion Playground keyboard.

This version does not request Full Access. Its preferences and custom snippets stay in the keyboard's own container. Settings and snippets you change in the companion app are saved in a container the app shares with the keyboard; the keyboard reads them, and never writes there, the next time it opens. The playground draft is saved separately and is not shared.

## Common questions

**The keyboard does not appear in one app or field.** iOS uses its own keyboard in secure and phone fields. Apps may also decline third-party keyboards. Try a regular text field in another app to distinguish a host restriction from a keyboard problem.

**Tab, Escape, arrows, or modifiers behave differently in a terminal or remote desktop.** Check the selected input profile under the gear menu. Terminal · ANSI sends control text and escape sequences only to clients that accept them. Remote desktop keeps input literal. An iOS keyboard extension does not send arbitrary hardware-key events; the remote client may require its own accessory controls.

**Delete line or outdent is unavailable.** Some apps expose only a small amount of nearby text. TabForge declines a destructive edit when it cannot verify the range. Select the intended text in the host app and use ordinary Delete instead.

**Autocorrect does not change a word.** English prose autocorrect is off by default and only operates in eligible text fields. It skips code-like input, host opt-outs, structured fields, Terminal and Remote desktop profiles, and TabForge's code playground. Space commits a correction; immediate Delete restores the original spelling.

**Swipe produces the wrong word.** Swipe typing is experimental. Current source includes an offline English and programming vocabulary; earlier binaries have a smaller coding vocabulary. Choose an alternative in the gear menu or use tap typing for identifiers and unsupported words. Use tap typing to replace selected text. It is not Apple's QuickPath engine. [Verification](verification.md) separates source improvements from the installed build.

**Voice-to-code is unavailable.** This feature runs in the companion playground, after you start recording and allow microphone and Speech Recognition access. It requires available on-device English recognition and has no cloud fallback. System Dictation is controlled separately by iOS; switch to Apple's keyboard if necessary.

**A previous snippet or setting is missing after the update.** The update retains an existing keyboard-local record. It does not read or transfer old App Group or companion-only keyboard records. If a value was saved only in one of those old locations, recreate it from the installed keyboard's gear menu. Legacy records are not erased by this change, and their presence does not mean the new version can access them. Do not post a private snippet in a support request.

**A change in the companion app does not show in my keyboard.** The keyboard reads the app's changes when it opens, so close it and open it again. If you changed the same setting in the keyboard more recently, the keyboard keeps its own choice. Changes made in the keyboard are not sent back to the app, because a keyboard without Full Access can't write to the shared container. If Settings in the app says it couldn't save, try the change again.

**Haptic feedback is unavailable.** iOS lets a keyboard vibrate only with Full Access, which TabForge doesn't request. Key click sounds work without it and follow Sounds › Keyboard Clicks in iOS Settings.

## Include this in a bug report

- TabForge version and build number, iOS/iPadOS version, and device model.
- The host app and input profile: Code editor, Terminal · ANSI, or Remote desktop.
- Whether the issue occurs in portrait, landscape, a resized window, or a particular Duo pose.
- The shortest steps to reproduce it with synthetic text, plus what you expected and what happened.
- Relevant settings, such as autocorrect, swipe, or keyboard height, and whether the issue is in the installed keyboard or a companion preview. Do not include your actual snippets or playground draft.

Screenshots are optional. Check them for private text, names, notifications, and account details before attaching them. The maintainers may ask for a smaller reproducer rather than a complete device log.

## Report a security issue privately

For a suspected leak, unsafe edit, or other vulnerability, [open a private GitHub security advisory](https://github.com/jdodsoncollins/TabForge/security/advisories/new). Do not put exploit details or private text in a public issue. If the private-report option is unavailable, follow [SECURITY.md](../SECURITY.md) and arrange a confidential contact before sending details.

Read [Privacy](../PRIVACY.md) for storage and permission details, [Design](../DESIGN.md) for platform limits, and [Verification](verification.md) for the distinction between automated checks and physical-device validation.
