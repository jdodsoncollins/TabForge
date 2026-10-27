import Foundation
import Testing
@testable import KeyboardCore

struct ThemeSettingsTests {
    @Test func autocorrectionIsOptInAndOlderRecordsKeepTheirPreferences() throws {
        var settings = KeyboardSettings()
        #expect(!settings.autocorrectProse)
        settings.language = .shell
        settings.theme = .nord
        settings.autocorrectProse = true
        let data = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(KeyboardSettings.self, from: data).autocorrectProse)
        var record = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        record.removeValue(forKey: "proseAutocorrection")
        let older = try JSONDecoder().decode(KeyboardSettings.self, from: JSONSerialization.data(withJSONObject: record))
        #expect(!older.autocorrectProse)
        #expect(older.language == .shell && older.theme == .nord)
    }

    @Test func hapticStrengthPersistsAndOlderRecordsDefaultToLight() throws {
        var settings = KeyboardSettings()
        #expect(settings.haptics && settings.hapticStrength == .light)
        settings.hapticStrength = .strong
        let data = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(KeyboardSettings.self, from: data).hapticStrength == .strong)
        var record = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        record.removeValue(forKey: "selectedHapticStrength")
        let older = try JSONDecoder().decode(KeyboardSettings.self, from: JSONSerialization.data(withJSONObject: record))
        #expect(older.hapticStrength == .light)
        #expect(older.keyClicks)
        settings.keyClicks = false
        #expect(try !JSONDecoder().decode(KeyboardSettings.self, from: JSONEncoder().encode(settings)).keyClicks)
    }

    @Test func defaultsFollowIOSAppearance() {
        let settings = KeyboardSettings()
        #expect(settings.theme == .standard)
        #expect(settings.appearance == .system)
        #expect(!settings.showNavigationRow)
    }

    @Test(arguments: KeyboardTheme.allCases)
    func themesPersistWithoutChangingEditingPreferences(_ theme: KeyboardTheme) throws {
        var settings = KeyboardSettings()
        settings.language = .python
        settings.indentation = .tabs
        settings.theme = theme
        settings.showNavigationRow = true
        let restored = try JSONDecoder().decode(KeyboardSettings.self, from: JSONEncoder().encode(settings))
        #expect(restored == settings)
        #expect(restored.theme == theme)
        #expect(restored.language == .python)
        #expect(restored.indentation == .tabs)
        #expect(restored.showNavigationRow)
        settings.theme = .standard
        #expect(settings.theme == KeyboardSettings().theme)
    }

    @Test func olderPreferencesKeepTheirValuesWhenThemeIsMissing() throws {
        var settings = KeyboardSettings()
        settings.language = .shell
        settings.swipeTyping = true
        settings.snippets = [CodeSnippet(name: "Keep me", text: "echo saved")]
        var record = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(settings)) as? [String: Any])
        record.removeValue(forKey: "selectedTheme")
        let restored = try JSONDecoder().decode(KeyboardSettings.self, from: JSONSerialization.data(withJSONObject: record))
        #expect(restored == settings)
        #expect(restored.theme == .standard)
        #expect(restored.appearance == .system)
    }
}
