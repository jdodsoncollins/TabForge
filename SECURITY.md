# Security policy

TabForge is a keyboard, so host text, saved snippets, playground drafts, speech, and contact-derived spelling hints can be sensitive. The source is public to make its behavior inspectable. That does not guarantee the absence of vulnerabilities. See [PRIVACY.md](PRIVACY.md) for current data handling and [DESIGN.md](DESIGN.md) for trust boundaries.

## Report a vulnerability privately

If this repository's **Security → Report a vulnerability** option is available, [open a private GitHub security advisory](https://github.com/jdodsoncollins/TabForge/security/advisories/new). If private reporting is unavailable, use a private contact method published by the repository owner and initially describe only the need for a confidential security report. Do not put exploit details or sensitive input into a public issue while arranging contact.

Include the affected version or commit, iOS version, input profile, relevant host application, reproducible steps using synthetic text, the expected behavior, and the observed impact. A minimal reproducer is more useful than a full device log. Redact account details, credentials, document contents, device identifiers, and personal information. Never upload actual keystroke histories, private snippets, contact lexicons, speech recordings, or unredacted terminal sessions.

Please allow time for investigation and a fix before publishing an exploit. The project does not promise a response deadline or a bug bounty. Maintainers should acknowledge private reports, reproduce with synthetic data, coordinate a fix and disclosure with the reporter, and credit the reporter only with their consent.

## Supported versions

Security fixes focus on the latest source revision and the latest distributed build. There is no separate long-term support branch or guaranteed backport schedule. Include the exact version in a report so maintainers can determine whether it is still affected.

## Areas that need particular care

- **Host text:** the extension must not log or transmit input. A text proxy may withhold, shorten, transform, or change context. Editing must not assume access to the whole document.
- **Destructive actions:** line deletion, outdent, correction replacement, and cursor movement need verified boundaries and selection state. Unsupported actions should decline safely.
- **Permissions and storage:** the keyboard must not request Full Access or use an App Group. Keep its settings and snippets in the extension's own local preferences; the companion stores its playground draft separately and keeps preview settings only in memory. These are not dedicated encrypted secret stores. Do not store credentials in snippets or drafts. Removing shared-container access does not erase older shared or app-local records, and this version does not import them.
- **Snippet editing:** route the editor to an isolated local draft, never to the host document proxy. Save updates local snippets; insertion into the host must remain a separate explicit action. Cancellation must discard the draft without changing host text.
- **Speech and system services:** companion voice input requires user permission and on-device recognition. The extension cannot record microphone audio. System Dictation and Writing Tools are Apple-controlled features with their own availability and data handling.
- **Optional tips (version 1.0.1 candidate):** keep StoreKit in the companion target. Accept success only for verified transactions for the configured consumable tip products; do not finish unrelated or unverified transactions. Do not attach host text, playground drafts, snippets, speech, or a TabForge account identifier to purchases. Keep purchase payloads and receipts out of logs and app preferences. Apple's transaction records are separate from app storage. See [the implementation and release checks](docs/tip-jar.md); the live version 1.0 (12) does not contain this feature.
- **Terminal and remote input:** ANSI and control text can trigger actions in a shell or remote application. The host/client decides how to interpret it; TabForge cannot validate the remote result.
- **Lifecycle:** stale cursor state, held keys, repeated-delete tasks, and delayed spelling results must not survive into an unrelated field or a reopened keyboard.
- **Supply chain:** dependency code, model weights, dictionaries, generated assets, build tooling, and release credentials have separate provenance and licensing concerns. Review all of them before distribution.

## Public repository hygiene

Use synthetic fixtures and redacted evidence. Keep signing certificates, private keys, provisioning files, access tokens, local account records, and release/upload artifacts out of the repository. Do not paste secrets into issue trackers or commit messages.

If a secret is exposed, revoke or rotate it first. Removing a file or rewriting Git history does not revoke credentials or erase copies in clones, caches, logs, or releases. Coordinate any history rewrite with collaborators, and document the incident without repeating the secret.
