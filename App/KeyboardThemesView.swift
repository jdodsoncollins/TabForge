import SwiftUI
import KeyboardCore

struct KeyboardThemesView: View {
    @Environment(PreferencesStore.self) private var preferences
    @Environment(\.colorScheme) private var systemScheme

    private var previewScheme: ColorScheme {
        if preferences.settings.theme.usesDarkPalette { return .dark }
        switch preferences.settings.appearance {
        case .system: return systemScheme
        case .light: return .light
        case .dark: return .dark
        }
    }

    var body: some View {
        @Bindable var preferences = preferences
        List {
            Section {
                preview
                    .environment(\.colorScheme, previewScheme)
                    .listRowInsets(EdgeInsets())
            }
            Section {
                themeRow(.standard)
                Picker("Standard appearance", selection: $preferences.settings.appearance) {
                    ForEach(KeyboardAppearance.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .disabled(preferences.settings.theme.usesDarkPalette)
                .accessibilityIdentifier("theme.appearance")
            } header: { Text("Standard") } footer: {
                Text("System follows iOS automatically. Light and Dark override it for the standard keyboard only.")
            }
            Section {
                ForEach(KeyboardTheme.allCases.filter { $0 != .standard }, id: \.self) { themeRow($0) }
            } header: { Text("Code themes") } footer: {
                Text("Code themes use dark palettes inspired by code editors. Themes apply to the keyboard, its previews, and gesture trail. Your app’s appearance stays under iOS control.")
            }
        }
        .navigationTitle("Keyboard themes")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func themeRow(_ theme: KeyboardTheme) -> some View {
        Button { preferences.settings.theme = theme } label: {
            HStack(spacing: 14) {
                let palette = KeyboardPalette.resolve(theme)
                Text("{ }").font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(uiColor: palette.accent))
                    .frame(width: 48, height: 38)
                    .background(Color(uiColor: palette.key), in: .rect(cornerRadius: 8))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(theme.rawValue).foregroundStyle(.primary)
                    Text(theme == .standard ? "Automatic light and dark" : "Dark code palette")
                        .font(.caption).foregroundStyle(.secondary)
                }.fixedSize(horizontal: false, vertical: true).layoutPriority(1)
                Spacer(minLength: 8)
                if preferences.settings.theme == theme { Image(systemName: "checkmark").fontWeight(.semibold) }
            }.padding(.vertical, 3).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("theme.\(theme)")
        .accessibilityLabel(theme.rawValue)
        .accessibilityValue(preferences.settings.theme == theme ? "Selected" : "")
        .accessibilityAddTraits(preferences.settings.theme == theme ? .isSelected : [])
    }

    private var preview: some View {
        let palette = KeyboardPalette.resolve(preferences.settings.theme)
        return VStack(spacing: 8) {
            HStack {
                Text("\(preferences.settings.theme.rawValue) preview").font(.caption).fontWeight(.medium)
                    .fixedSize(horizontal: false, vertical: true).layoutPriority(1)
                Spacer()
                Image(systemName: "paintpalette")
            }
            .foregroundStyle(Color(uiColor: palette.text))
            .padding(.bottom, 5)
            HStack(spacing: 6) {
                ForEach(["{", "}", "[", "]", "<", ">"], id: \.self) { key in
                    Text(key).font(.system(size: 21, design: .monospaced))
                        .foregroundStyle(Color(uiColor: palette.accent))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Color(uiColor: palette.key), in: .rect(cornerRadius: 7))
                }
            }
            HStack(spacing: 6) {
                previewKey("⇥", palette: palette, utility: true)
                previewKey("space", palette: palette).frame(maxWidth: .infinity)
                previewKey("↵", palette: palette, utility: true)
            }
        }
        .padding(14)
        .background(Color(uiColor: palette.background))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Keyboard preview, \(preferences.settings.theme.rawValue)")
    }

    private func previewKey(_ text: String, palette: KeyboardPalette, utility: Bool = false) -> some View {
        Text(text).font(.system(size: 21, design: .monospaced))
            .foregroundStyle(Color(uiColor: palette.text))
            .frame(minWidth: utility ? 44 : 0, maxWidth: .infinity, minHeight: 44)
            .background(Color(uiColor: utility ? palette.utility : palette.key), in: .rect(cornerRadius: 7))
    }
}
