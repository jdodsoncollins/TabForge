import Foundation
import Testing
import KeyboardCore
@testable import ScriptKeyboard

@Suite @MainActor
struct PreferencesStoreTests {
    private static let key = "keyboardPreferences.v1"

    private struct StoredRecord: Codable, Equatable {
        var settings: KeyboardSettings
        var modified: Date
    }

    private struct IsolatedDefaults {
        let name: String
        let defaults: UserDefaults

        init() throws {
            let name = "TabForge.Tests.\(UUID().uuidString)"
            self.name = name
            defaults = try #require(UserDefaults(suiteName: name))
        }

        func remove() { defaults.removePersistentDomain(forName: name) }
    }

    private func record(in defaults: UserDefaults) throws -> StoredRecord {
        let data = try #require(defaults.data(forKey: Self.key))
        return try JSONDecoder().decode(StoredRecord.self, from: data)
    }

    private func write(_ settings: KeyboardSettings, at date: Date, to defaults: UserDefaults) throws {
        let data = try JSONEncoder().encode(StoredRecord(settings: settings, modified: date))
        defaults.set(data, forKey: Self.key)
    }

    @Test func previewSettingsRemainInMemoryAndAreNotRestoredIntoANewPreview() {
        let previousPersistentData = UserDefaults.standard.data(forKey: Self.key)
        let preview = PreferencesStore(local: nil)
        preview.settings.language = .shell
        preview.settings.snippets = [CodeSnippet(name: "Preview", text: "echo example")]
        preview.refresh()

        #expect(preview.settings.language == .shell)
        #expect(preview.settings.snippets.count == 1)
        #expect(UserDefaults.standard.data(forKey: Self.key) == previousPersistentData)
        #expect(PreferencesStore(local: nil).settings == KeyboardSettings())

        preview.reset()
        #expect(preview.settings == KeyboardSettings())
        #expect(UserDefaults.standard.data(forKey: Self.key) == previousPersistentData)
    }

    @Test func settingsAndSnippetsPersistInTheLocalStore() throws {
        let local = try IsolatedDefaults()
        defer { local.remove() }
        let date = Date(timeIntervalSince1970: 100)
        let store = PreferencesStore(local: local.defaults, now: { date })
        store.settings.language = .python
        store.settings.indentation = .twoSpaces
        store.settings.snippets = [CodeSnippet(name: "Lambda", text: " => ")]

        #expect(try record(in: local.defaults) == StoredRecord(settings: store.settings, modified: date))
        let restored = PreferencesStore(local: local.defaults)
        #expect(restored.settings == store.settings)
    }

    @Test func existingLocalRecordIsRetainedWithoutRewritingOrMigration() throws {
        let local = try IsolatedDefaults()
        defer { local.remove() }
        var expected = KeyboardSettings()
        expected.language = .shell
        expected.snippets = [CodeSnippet(name: "Existing", text: "printf example")]
        let date = Date(timeIntervalSince1970: 100)
        try write(expected, at: date, to: local.defaults)
        let existingData = try #require(local.defaults.data(forKey: Self.key))

        let store = PreferencesStore(local: local.defaults)
        store.refresh()

        #expect(store.settings == expected)
        #expect(local.defaults.data(forKey: Self.key) == existingData)
    }

    @Test func storesRemainIndependentEvenWhenAnotherRecordIsNewer() throws {
        let keyboard = try IsolatedDefaults()
        let companion = try IsolatedDefaults()
        defer { keyboard.remove(); companion.remove() }
        var keyboardSettings = KeyboardSettings()
        keyboardSettings.language = .python
        var companionSettings = KeyboardSettings()
        companionSettings.language = .javascript
        try write(keyboardSettings, at: Date(timeIntervalSince1970: 100), to: keyboard.defaults)
        try write(companionSettings, at: Date(timeIntervalSince1970: 300), to: companion.defaults)
        let companionData = try #require(companion.defaults.data(forKey: Self.key))
        let store = PreferencesStore(local: keyboard.defaults, now: { Date(timeIntervalSince1970: 400) })

        #expect(store.settings == keyboardSettings)
        store.settings.indentation = .tabs
        store.refresh()

        #expect(store.settings.language == .python)
        #expect(companion.defaults.data(forKey: Self.key) == companionData)
        #expect(try record(in: keyboard.defaults).settings.indentation == .tabs)
    }

    @Test func refreshAdoptsOnlyANewerValidLocalRecord() throws {
        let local = try IsolatedDefaults()
        defer { local.remove() }
        let store = PreferencesStore(local: local.defaults, now: { Date(timeIntervalSince1970: 200) })
        store.settings.language = .python
        var newer = store.settings
        newer.language = .typescript
        try write(newer, at: Date(timeIntervalSince1970: 300), to: local.defaults)
        store.refresh()
        #expect(store.settings == newer)

        var older = newer
        older.language = .shell
        try write(older, at: Date(timeIntervalSince1970: 100), to: local.defaults)
        store.refresh()
        #expect(store.settings == newer)

        local.defaults.set(Data("invalid record".utf8), forKey: Self.key)
        store.refresh()
        #expect(store.settings == newer)
    }

    @Test func resetPersistsDefaultsWithoutDeletingOtherLocalData() throws {
        let local = try IsolatedDefaults()
        defer { local.remove() }
        let store = PreferencesStore(local: local.defaults, now: { Date(timeIntervalSince1970: 100) })
        store.settings.language = .shell
        store.settings.snippets = [CodeSnippet(name: "Example", text: "echo example")]
        local.defaults.set("synthetic draft", forKey: "playground.draft")

        store.reset()

        #expect(store.settings == KeyboardSettings())
        #expect(try record(in: local.defaults).settings == KeyboardSettings())
        #expect(local.defaults.string(forKey: "playground.draft") == "synthetic draft")
        #expect(PreferencesStore(local: local.defaults).settings == KeyboardSettings())
    }
}
