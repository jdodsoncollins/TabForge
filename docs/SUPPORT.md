# TabForge support

For support, email [jeremy@jeremycollins.net](mailto:jeremy@jeremycollins.net). You can also [contact the TabForge maintainers through GitHub Issues](https://github.com/jdodsoncollins/TabForge/issues) for bugs or feature requests. Search existing issues first, then [open an issue](https://github.com/jdodsoncollins/TabForge/issues/new) if you cannot find an answer. GitHub requires an account to post. Reports and replies are public.

Do not post passwords, private code, transcripts, contact names, account details, or unredacted screenshots and logs. Reproduce the problem with a short, invented example.

## Set up the keyboard

1. Open iOS Settings → General → Keyboard → Keyboards → Add New Keyboard, then choose TabForge.
2. In a text field, hold the globe key and select TabForge.
3. Tap the keyboard's gear for editing tools, quick preferences, complete keyboard settings, and custom snippet management. Configure the installed keyboard there.

This version does not request Full Access or use an App Group. Its preferences and custom snippets stay in the keyboard's own container. The companion app provides setup, source/privacy information, licenses, and a playground; it does not configure the installed keyboard.

The companion's keyboard and layout guide are previews. Their settings and snippets are temporary and discarded when that app process ends. The playground draft is still saved separately.

## Common questions

**The keyboard does not appear in one app or field.** iOS uses its own keyboard in secure and phone fields. Apps may also decline third-party keyboards. Try a regular text field in another app to distinguish a host restriction from a keyboard problem.

**Tab, Escape, arrows, or modifiers behave differently in a terminal or remote desktop.** Check the selected input profile under the gear menu. Terminal · ANSI sends control text and escape sequences only to clients that accept them. Remote desktop keeps input literal. An iOS keyboard extension does not send arbitrary hardware-key events; the remote client may require its own accessory controls.

**Delete line or outdent is unavailable.** Some apps expose only a small amount of nearby text. TabForge declines a destructive edit when it cannot verify the range. Select the intended text in the host app and use ordinary Delete instead.

**Autocorrect does not change a word.** English prose autocorrect is off by default and only operates in eligible text fields. It skips code-like input, host opt-outs, structured fields, Terminal and Remote desktop profiles, and TabForge's code playground. Space commits a correction; immediate Delete restores the original spelling.

**Swipe produces the wrong word.** Swipe code words is experimental and uses a small coding vocabulary. Choose an alternative in the gear menu or turn the feature off. It is not Apple's QuickPath engine.

**Voice-to-code is unavailable.** This feature runs in the companion playground, after you start recording and allow microphone and Speech Recognition access. It requires available on-device English recognition and has no cloud fallback. System Dictation is controlled separately by iOS; switch to Apple's keyboard if necessary.

**A previous snippet or setting is missing after the update.** The update retains an existing keyboard-local record. It does not read or transfer old App Group or companion-only keyboard records. If a value was saved only in one of those old locations, recreate it from the installed keyboard's gear menu. Legacy records are not erased by this change, and their presence does not mean the new version can access them. Do not post a private snippet in a support request.

**A preview change does not affect my keyboard in another app.** This is intentional. The companion preview uses independent temporary settings. Change the installed keyboard from its own gear menu.

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
