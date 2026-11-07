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

    /// Stands in for the App Group file, which unsigned test builds don't have.
    private struct TemporaryFolder {
        let url: URL

        init() throws {
            url = FileManager.default.temporaryDirectory.appending(path: "TabForge.Tests.\(UUID().uuidString)", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }

        var file: SharedSettingsFile { SharedSettingsFile(url: url.appending(path: SharedSettingsFile.fileName)) }
        func remove() { try? FileManager.default.removeItem(at: url) }
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

    @Test func theKeyboardAdoptsAppChangesAndKeepsItsOwn() throws {
        let folder = try TemporaryFolder()
        let keyboardDefaults = try IsolatedDefaults()
        defer { folder.remove(); keyboardDefaults.remove() }
        var existing = KeyboardSettings()
        existing.theme = .nord
        existing.snippets.append(CodeSnippet(name: "Keyboard", text: "ls"))
        try write(existing, at: Date(timeIntervalSince1970: 100), to: keyboardDefaults.defaults)

        let app = PreferencesStore(local: nil, sharing: .publish(folder.file), now: { Date(timeIntervalSince1970: 200) })
        #expect(app.sharesWithKeyboard && !app.readsFromApp)
        app.settings.language = .python
        let added = CodeSnippet(name: "From app", text: "print(1)")
        app.settings.snippets.append(added)
        #expect(!app.sharingFailed)
        let shared = try Data(contentsOf: folder.file.url)

        let keyboard = PreferencesStore(
            local: keyboardDefaults.defaults, sharing: .read(folder.file), now: { Date(timeIntervalSince1970: 300) }
        )
        #expect(keyboard.readsFromApp && !keyboard.sharesWithKeyboard)
        #expect(keyboard.settings.language == .python)
        #expect(keyboard.settings.theme == .nord)
        #expect(keyboard.settings.snippets.map(\.name).suffix(2) == ["Keyboard", "From app"])
        // The merged result is saved in the keyboard; the shared file is untouched.
        #expect(try record(in: keyboardDefaults.defaults).settings == keyboard.settings)
        #expect(try Data(contentsOf: folder.file.url) == shared)

        keyboard.settings.language = .shell
        keyboard.refresh()
        #expect(keyboard.settings.language == .shell)
        #expect(try Data(contentsOf: folder.file.url) == shared)
    }

    @Test func theKeyboardNeverCreatesTheSharedFile() throws {
        let folder = try TemporaryFolder()
        let keyboardDefaults = try IsolatedDefaults()
        defer { folder.remove(); keyboardDefaults.remove() }
        let keyboard = PreferencesStore(local: keyboardDefaults.defaults, sharing: .read(folder.file))
        keyboard.settings.language = .json
        keyboard.reset()
        keyboard.refresh()
        #expect(!FileManager.default.fileExists(atPath: folder.file.url.path(percentEncoded: false)))
    }

    @Test func theAppRestoresItsSharedSettings() throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let app = PreferencesStore(local: nil, sharing: .publish(folder.file))
        app.settings.keySize = .comfortable
        app.settings.snippets = [CodeSnippet(name: "Only", text: "x")]
        let relaunched = PreferencesStore(local: nil, sharing: .publish(folder.file))
        #expect(relaunched.settings == app.settings)
        relaunched.reset()
        #expect(PreferencesStore(local: nil, sharing: .publish(folder.file)).settings == KeyboardSettings())
    }

    @Test func unreadableOrOversizedSharedFilesAreIgnored() throws {
        let folder = try TemporaryFolder()
        let keyboardDefaults = try IsolatedDefaults()
        defer { folder.remove(); keyboardDefaults.remove() }
        var existing = KeyboardSettings()
        existing.language = .shell
        try write(existing, at: Date(timeIntervalSince1970: 100), to: keyboardDefaults.defaults)

        try Data("not a record".utf8).write(to: folder.file.url)
        #expect(folder.file.read() == nil)
        #expect(PreferencesStore(local: keyboardDefaults.defaults, sharing: .read(folder.file)).settings == existing)

        var huge = KeyboardSettings()
        huge.language = .python
        huge.snippets = [CodeSnippet(name: "Huge", text: String(repeating: "x", count: SharedSettingsFile.maximumSize))]
        var hugeRecord = SettingsRecord()
        hugeRecord.update(to: huge, at: Date(timeIntervalSince1970: 200))
        let oversized = try JSONEncoder().encode(hugeRecord)
        #expect(oversized.count > SharedSettingsFile.maximumSize)
        try oversized.write(to: folder.file.url)
        #expect(folder.file.read() == nil)
        #expect(!folder.file.write(oversized))
        #expect(PreferencesStore(local: keyboardDefaults.defaults, sharing: .read(folder.file)).settings == existing)
    }

    @Test func aFailedShareIsReported() throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let missing = SharedSettingsFile(url: folder.url.appending(path: "missing/settings.json"))
        let app = PreferencesStore(local: nil, sharing: .publish(missing))
        app.settings.language = .python
        #expect(app.sharingFailed)
        #expect(app.settings.language == .python)
    }

    @Test func theKeyboardAndAppShareOneAppGroupAndFullAccessIsNotRequested() throws {
        let appGroup = try #require(Bundle.main.object(forInfoDictionaryKey: SharedSettingsFile.infoKey) as? String)
        let bundleIdentifier = try #require(Bundle.main.bundleIdentifier)
        #expect(appGroup == "group." + bundleIdentifier)

        let plugIns = try #require(Bundle.main.builtInPlugInsURL)
        let extensions = try FileManager.default.contentsOfDirectory(at: plugIns, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "appex" }.compactMap(Bundle.init(url:))
        let keyboard = try #require(extensions.first { bundle in
            (bundle.object(forInfoDictionaryKey: "NSExtension") as? [String: Any])?["NSExtensionPointIdentifier"] as? String
                == "com.apple.keyboard-service"
        })
        #expect(keyboard.object(forInfoDictionaryKey: SharedSettingsFile.infoKey) as? String == appGroup)
        let attributes = (keyboard.object(forInfoDictionaryKey: "NSExtension") as? [String: Any])?["NSExtensionAttributes"] as? [String: Any]
        let requestsOpenAccess = attributes?["RequestsOpenAccess"] as? Bool ?? false
        #expect(requestsOpenAccess == KeyboardCapabilities.requestsFullAccess)
        #expect(!requestsOpenAccess)
    }
}
