import SwiftUI
import KeyboardCore

private enum PlaygroundSheet: String, Identifiable {
    case setup, voice
    var id: String { rawValue }
}

struct PlaygroundView: View {
    @Environment(PreferencesStore.self) private var preferences
    @AppStorage("playground.draft") private var text = CodeLanguage.swift.sample
    @State private var session = EditorSession()
    @State private var sheet: PlaygroundSheet?
    @State private var error: String?
    @State private var replaceDraft = false
    let openSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if !session.isFocused { HStack(spacing: 12) {
                Image(systemName: "curlybraces").font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color(uiColor: ScriptTheme.accent))
                    .frame(width: 48, height: 48)
                    .background(Color(uiColor: ScriptTheme.accent).opacity(0.1), in: .rect(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Try the keyboard in the playground").font(.headline)
                    Text("Preview changes last for this app session. Use the keyboard’s gear in other apps for its saved settings.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20).padding(.vertical, 16) }

            HStack(spacing: 8) {
                Circle().fill(Color(uiColor: ScriptTheme.accent)).frame(width: 6, height: 6)
                Text("playground.\(preferences.settings.language.fileExtension)")
                    .font(.system(.caption, design: .monospaced)).fontWeight(.medium)
                Spacer()
                Menu {
                    ForEach(CodeLanguage.allCases, id: \.self) { language in
                        Button(language.rawValue, systemImage: preferences.settings.language == language ? "checkmark" : "chevron.left.forwardslash.chevron.right") {
                            preferences.settings.language = language
                            session.host?.language = language
                            session.host?.highlight()
                        }
                    }
                } label: {
                    Text(preferences.settings.language.rawValue).font(.caption).fontWeight(.semibold)
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
                }
                .accessibilityLabel("Programming language")
            }
            .padding(.horizontal, 18).frame(minHeight: 44)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            Divider()
            CodeEditor(text: $text, preferences: preferences, session: session, openSettings: openSettings)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
            Divider()
            HStack {
                Text(session.cursorLabel)
                Spacer()
                Text(preferences.settings.indentation.shortLabel)
                Text("·").foregroundStyle(.quaternary)
                Text(preferences.settings.compatibility.shortLabel)
                Image(systemName: "lock.shield").accessibilityLabel("On device")
            }
            .font(.system(.caption2, design: .monospaced)).foregroundStyle(.secondary)
            .padding(.horizontal, 18).frame(minHeight: 34)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Playground")
        .navigationBarTitleDisplayMode(session.isFocused ? .inline : .large)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Set up", systemImage: "keyboard.badge.ellipsis") { session.dismiss(); sheet = .setup }
                    .font(.subheadline)
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Voice to code", systemImage: "mic") { session.dismiss(); sheet = .voice }
                Menu {
                    Button("Show keyboard preview", systemImage: "keyboard") { session.useCustomKeyboard(true); session.focus() }
                    Button("Use system keyboard", systemImage: "globe") { session.useCustomKeyboard(false); session.focus() }
                    Button("Reindent code", systemImage: "text.alignleft") {
                        do { try session.format(language: preferences.settings.language, indentation: preferences.settings.indentation) }
                        catch { self.error = preferences.settings.language == .json ? "The JSON could not be formatted. Check its syntax and try again." : error.localizedDescription }
                    }
                    ShareLink(item: text) { Label("Share code", systemImage: "square.and.arrow.up") }
                    Button("Load language example", systemImage: "doc.text", role: .destructive) { replaceDraft = true }
                    Button("Dismiss keyboard", systemImage: "keyboard.chevron.compact.down") { session.dismiss() }
                } label: { Label("Playground actions", systemImage: "ellipsis.circle") }
            }
        }
        .sheet(item: $sheet) { destination in
            switch destination {
            case .setup: SetupView()
            case .voice: VoiceCodeView { code in session.insert(code) }
            }
        }
        .alert("Couldn’t reindent code", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
        .confirmationDialog("Replace the current draft with an example?", isPresented: $replaceDraft, titleVisibility: .visible) {
            Button("Load example", role: .destructive) { text = preferences.settings.language.sample }
        }
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("--show-keyboard") {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(400)); session.focus()
                }
            }
        }
    }
}

struct SetupView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Your coding keyboard, in other apps.", systemImage: "keyboard")
                        .font(.headline).padding(.vertical, 8)
                    Text("The playground includes a keyboard preview. Its changes and snippets last for this app session. Enable the extension to use TabForge in editors, terminals, and remote sessions.")
                        .foregroundStyle(.secondary)
                }
                Section("Enable TabForge") {
                    step("1", "Open Settings", "General → Keyboard → Keyboards")
                    step("2", "Add New Keyboard", "Choose TabForge under Third-Party Keyboards.")
                    step("3", "Switch with the globe", "In a text field, hold the globe key and choose TabForge.")
                    Link(destination: URL(string: UIApplication.openSettingsURLString)!) { Label("Open Settings", systemImage: "arrow.up.forward.app") }
                }
                Section("Keyboard settings") {
                    Text("Select TabForge in a text field, then tap its gear to change preferences and edit snippets. Settings are saved in the keyboard. Full Access is not requested.")
                    Text("The companion preview does not change your installed keyboard’s settings.")
                        .foregroundStyle(.secondary)
                }
                Section("App compatibility") {
                    Text("Code editor mode suits normal text fields. Choose Terminal · ANSI only when your terminal accepts raw control sequences. Remote desktop mode sends literal text and tabs. Remote clients determine how those inputs reach the remote computer.")
                    Text("iOS uses the system keyboard for password and phone fields. Apps can also decline custom keyboards. Dictation appears where iOS provides its microphone key; use the globe to switch to the system keyboard when needed.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Set up your keyboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
    private func step(_ number: String, _ title: String, _ subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number).font(.system(.headline, design: .monospaced)).foregroundStyle(Color(uiColor: ScriptTheme.accent)).frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 6)
    }
}
