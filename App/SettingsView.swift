import SwiftUI
import KeyboardCore

struct SettingsView: View {
    private static let repositoryURL = URL(string: "https://github.com/jdodsoncollins/TabForge")!
    private static let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showSetup = false

    var body: some View {
        Form {
            Section {
                let headerLayout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                    : AnyLayout(HStackLayout(spacing: 14))
                headerLayout {
                    Image(systemName: "curlybraces").font(.title2).foregroundStyle(Color(uiColor: ScriptTheme.accent))
                        .frame(width: 48, height: 48).background(Color(uiColor: ScriptTheme.accent).opacity(0.1), in: .rect(cornerRadius: 12))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Configure TabForge from the keyboard.").font(.headline)
                        Text("The gear keeps preferences, snippets, and editing tools close to your keys.").font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(.vertical, 6)
            }
            Section {
                Button("Set up in other apps", systemImage: "keyboard.badge.ellipsis") { showSetup = true }
                Text("TabForge does not request Full Access. Open the keyboard’s gear to change its settings and manage snippets. Those choices stay in the keyboard’s own local storage.")
                    .font(.footnote).foregroundStyle(.secondary)
            } header: { Text("Keyboard setup") }
            Section("Help") {
                NavigationLink { SmartInputInfoView() } label: { Label("Voice, swipe & Apple Intelligence", systemImage: "waveform") }
                NavigationLink { CompatibilityInfoView() } label: { Label("Terminal & remote compatibility", systemImage: "terminal") }
                Text("The Playground and Layouts are previews. Their settings and snippets are temporary and separate from the keyboard you enable in other apps.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section {
                NavigationLink { OpenSourceLicensesView() } label: {
                    Label("Licenses & notices", systemImage: "doc.text")
                }
                .accessibilityIdentifier("settings.licenses")
                Link(destination: Self.repositoryURL) {
                    Label("View source on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                .accessibilityIdentifier("settings.sourceCode")
                .accessibilityHint("Opens TabForge’s public source repository.")
                Link(destination: URL(string: "https://www.jeremycollins.net/tabforge/privacy")!) {
                    Label("Privacy details", systemImage: "hand.raised")
                }
                .accessibilityIdentifier("settings.privacyPolicy")
                Link(destination: Self.repositoryURL.appending(path: "blob/main/SECURITY.md")) {
                    Label("Security policy", systemImage: "lock.shield")
                }
                .accessibilityIdentifier("settings.securityPolicy")
            } header: { Text("Open source") } footer: {
                Text("TabForge is open source under the MIT License. Inspect how the keyboard handles your text, review its privacy protections, and contribute improvements.")
            }
            Section {
                LabeledContent("Version", value: Self.appVersion)
                LabeledContent("Requires", value: "iOS / iPadOS 27.0")
                Text("The keyboard extension does not log or transmit keystrokes. TabForge saves your playground draft, preferences, and snippets locally. Apps you type into and Apple’s system services follow their own privacy policies.")
                    .font(.footnote).foregroundStyle(.secondary)
            } header: { Text("About TabForge") }
            Section {
                NavigationLink { TipJarView() } label: {
                    DescribedSettingsRow(
                        title: "Tip Jar", detail: "Support TabForge’s development.", symbol: "gift"
                    )
                }
                .accessibilityIdentifier("settings.tipJar")
            }
            Section("Built with") {
                AttributionLink(
                    title: "SwiftUI", detail: "The native interface for TabForge’s companion app.",
                    symbol: "swift", destination: URL(string: "https://developer.apple.com/swiftui/")!
                )
                .accessibilityIdentifier("settings.attribution.swiftui")
                AttributionLink(
                    title: "UIKit", detail: "The keyboard, text editor, and on-device spelling support.",
                    symbol: "keyboard", destination: URL(string: "https://developer.apple.com/documentation/uikit")!
                )
                .accessibilityIdentifier("settings.attribution.uikit")
                AttributionLink(
                    title: "Apple Speech", detail: "On-device voice recognition in the companion playground.",
                    symbol: "waveform", destination: URL(string: "https://developer.apple.com/documentation/speech")!
                )
                .accessibilityIdentifier("settings.attribution.speech")
                AttributionLink(
                    title: "Nord", detail: "Colors adapted for the Nord keyboard theme.",
                    symbol: "paintpalette", destination: URL(string: "https://www.nordtheme.com")!
                )
                AttributionLink(
                    title: "Dracula", detail: "Colors adapted for the Dracula keyboard theme.",
                    symbol: "paintpalette", destination: URL(string: "https://draculatheme.com")!
                )
            }
            Section {
                AttributionLink(
                    title: "Created by Jeremy Collins", detail: "jeremycollins.net/tabforge",
                    symbol: "person.crop.circle", destination: URL(string: "https://www.jeremycollins.net/tabforge")!
                )
                .accessibilityIdentifier("settings.creator")
                NavigationLink { OtherAppsView() } label: {
                    DescribedSettingsRow(
                        title: "Other Apps", detail: "More apps from the same developer.", symbol: "square.grid.2x2"
                    )
                }
                .accessibilityIdentifier("settings.otherApps")
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showSetup) { SetupView() }
    }
}

private struct DescribedSettingsRow: View {
    let title: String
    let detail: String
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Color(uiColor: ScriptTheme.accent))
                .frame(width: 26)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline).foregroundStyle(Color.primary)
                Text(detail).foregroundStyle(Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}

private struct AttributionLink: View {
    let title: String
    let detail: String
    let symbol: String
    let destination: URL

    var body: some View {
        Link(destination: destination) {
            HStack(alignment: .top, spacing: 12) {
                DescribedSettingsRow(title: title, detail: detail, symbol: symbol)
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
                    .padding(.top, 11)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityHint("Opens an external website.")
    }
}

private struct OtherAppsView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        List {
            Section {
                appLink(
                    name: "Codable", icon: "CodableMark",
                    detail: "Inspect web pages in Safari, test responsive layouts, and run JavaScript in a scratchpad.",
                    destination: URL(string: "https://apps.apple.com/us/app/codable/id1324741659")!
                )
                .accessibilityIdentifier("otherApps.codable")
                appLink(
                    name: "Taktung", icon: "TaktungMark",
                    detail: "Check Vercel deployments, read build logs, and compare changes from your iPhone or iPad.",
                    destination: URL(string: "https://apps.apple.com/us/app/taktung-deployment-status/id6805738660")!
                )
                .accessibilityIdentifier("otherApps.taktung")
                appLink(
                    name: "Paper & Grain", icon: "PaperGrainMark",
                    detail: "Fold paper, follow origami lessons, and experiment with shapes in Free Fold.",
                    destination: URL(string: "https://apps.apple.com/us/app/paper-grain/id6821361967")!
                )
                .accessibilityIdentifier("otherApps.paperGrain")
            } footer: {
                Text("These links open the App Store.")
            }
        }
        .navigationTitle("Other Apps")
        .navigationBarTitleDisplayMode(.large)
    }

    private func appLink(name: String, icon: String, detail: String, destination: URL) -> some View {
        Link(destination: destination) {
            HStack(alignment: .top, spacing: 12) {
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                    : AnyLayout(HStackLayout(alignment: .top, spacing: 16))
                layout {
                    Image(icon).resizable().scaledToFit()
                        .frame(width: 60, height: 60)
                        .clipShape(.rect(cornerRadius: 14))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(name).font(.headline).foregroundStyle(Color.primary)
                        Text(detail).foregroundStyle(Color.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
                    .padding(.top, 3)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 10)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens \(name) in the App Store.")
    }
}

private struct OpenSourceLicensesView: View {
    var body: some View {
        List {
            NavigationLink("TabForge · MIT License") {
                BundledLicenseView(title: "MIT License", resource: "LICENSE", fileExtension: nil)
            }
            .accessibilityIdentifier("licenses.mit")
            NavigationLink("Third-party notices") {
                BundledLicenseView(title: "Third-party notices", resource: "THIRD_PARTY_NOTICES", fileExtension: "md")
            }
            .accessibilityIdentifier("licenses.thirdParty")
        }
        .navigationTitle("Licenses & notices")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct BundledLicenseView: View {
    let title: String
    private let contents: String?

    init(title: String, resource: String, fileExtension: String?) {
        self.title = title
        self.contents = Bundle.main.url(forResource: resource, withExtension: fileExtension)
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) }
    }

    var body: some View {
        ScrollView {
            if let contents {
                Text(contents)
                    .font(.footnote)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .accessibilityIdentifier("licenses.document")
            } else {
                ContentUnavailableView("License unavailable", systemImage: "doc.text",
                    description: Text("The bundled document could not be loaded. You can also find the licenses in TabForge’s source repository."))
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SmartInputInfoView: View {
    var body: some View {
        List {
            Section("Autocorrect prose") {
                Text("Autocorrect is off by default. Enable it to check plain English words on device when you press Space. Press Delete immediately after a correction to restore what you typed.")
                Text("Autocorrect follows the app’s text-field settings. It stays inactive when the app disables correction, in URL, email, and numeric fields, in Terminal and Remote desktop profiles, and in TabForge’s code playground.").foregroundStyle(.secondary)
            }
            Section("Voice to code") {
                Text("Use the microphone in the playground to dictate on device, review the result, and insert it at the cursor. Spoken punctuation such as ‘open brace’, ‘new line’, and ‘tab’ can be converted into code symbols.")
                Text("The keyboard extension leaves iOS’s system dictation key enabled. If the host doesn’t show it, switch to the Apple keyboard with the globe. Extensions cannot record microphone audio directly.").foregroundStyle(.secondary)
            }
            Section("Swipe typing · beta") {
                Text("Slide across letter keys to write English words and programming terms. Open the gear menu → Swipe alternatives to choose another match. The dictionary is bundled offline. Recognition remains experimental; names, arbitrary identifiers and other languages may need tap typing.")
            }
            Section("Apple Intelligence") {
                Text("The playground’s native text editor allows system Writing Tools through the text selection menu on supported devices. Availability depends on your device, language, and Apple Intelligence settings. Review generated changes carefully when working with source code.")
                Text("Apple doesn’t expose its QuickPath swipe decoder to third-party keyboards. TabForge uses its own geometric decoder and an included English dictionary. It does not download a model or learn from your typing.").foregroundStyle(.secondary)
            }
        }.navigationTitle("Smart input").navigationBarTitleDisplayMode(.inline)
    }
}

struct CompatibilityInfoView: View {
    var body: some View {
        List {
            ForEach(CompatibilityMode.allCases, id: \.self) { mode in
                Section(mode.rawValue) { Text(mode.detail) }
            }
            Section("What iOS makes possible") {
                Text("A keyboard extension inserts Unicode text through UITextDocumentProxy. It can move a text cursor when the host exposes one, but cannot send HID events, Command-key combinations, or arbitrary key-down and key-up events to a remote computer.")
                Text("Some terminal apps accept literal tabs, ASCII controls, and ANSI sequences. Other apps discard or reinterpret them. Remote clients may require their own accessory keys for Tab, Escape, Control, and function keys. Test a harmless command in your chosen client before relying on terminal mode.")
            }
            Section("Broad compatibility") {
                Text("The keyboard stays functional when an app omits surrounding text: pairing, context edits, and autocorrect are bypassed, and regular character input continues. Autocorrect is off by default and only runs in eligible prose fields when enabled. Smart quotes, automatic capitalization, and double-space periods are never added.")
                Text("iOS replaces custom keyboards in secure and phone fields. Apps can opt out of keyboard extensions. The system owns text selection and may expose only a limited context around the cursor.")
                Text("Delete line requires visible line boundaries, or the full document in the playground. If a host hides a boundary, select the line and use ordinary Delete. Terminal mode exposes Ctrl-U and Ctrl-K instead; shell key mappings determine what they clear. Remote desktop mode leaves line editing to the client.")
            }
            Section("Keyboard settings") {
                Text("Open the gear on TabForge to change keyboard preferences and manage snippets. The keyboard saves those choices locally without Full Access. The companion app’s Playground and Layouts use separate, temporary preview settings.")
            }
        }.navigationTitle("Compatibility").navigationBarTitleDisplayMode(.inline)
    }
}
