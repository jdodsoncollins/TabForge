import Foundation
import Testing
@testable import KeyboardCore

struct SettingsSyncTests {
    private struct LegacyRecord: Codable {
        var settings: KeyboardSettings
        var modified: Date
    }

    private func time(_ seconds: TimeInterval) -> Date { Date(timeIntervalSince1970: seconds) }

    /// A record saved before settings were shared: no change history.
    private func legacy(_ settings: KeyboardSettings, at seconds: TimeInterval) throws -> SettingsRecord {
        let data = try JSONEncoder().encode(LegacyRecord(settings: settings, modified: time(seconds)))
        return try JSONDecoder().decode(SettingsRecord.self, from: data)
    }

    private func roundTrip(_ record: SettingsRecord) throws -> SettingsRecord {
        try JSONDecoder().decode(SettingsRecord.self, from: JSONEncoder().encode(record))
    }

    private func changed(_ record: SettingsRecord, at seconds: TimeInterval, _ change: (inout KeyboardSettings) -> Void) -> SettingsRecord {
        var record = record
        var settings = record.settings
        change(&settings)
        record.update(to: settings, at: time(seconds))
        return record
    }

    @Test func appChangesReachTheKeyboardWithoutUndoingItsOwn() throws {
        var keyboardSettings = KeyboardSettings()
        keyboardSettings.language = .shell
        keyboardSettings.theme = .nord
        keyboardSettings.snippets.append(CodeSnippet(name: "Keyboard", text: "echo example"))
        var keyboard = try legacy(keyboardSettings, at: 100)
        let app = try roundTrip(changed(SettingsRecord(), at: 200) { $0.indentation = .tabs })

        let adopted = keyboard.merge(app, at: time(300))
        #expect(adopted)
        #expect(keyboard.settings.indentation == .tabs)
        #expect(keyboard.settings.language == .shell)
        #expect(keyboard.settings.theme == .nord)
        #expect(keyboard.settings.snippets.map(\.name).contains("Keyboard"))
        #expect(keyboard.modified == time(300))
        // Reading the same file again changes nothing.
        let readAgain = keyboard.merge(app, at: time(400))
        #expect(!readAgain)
        #expect(keyboard.modified == time(300))
    }

    @Test func theNewerChangeToEachFieldWins() throws {
        let app = changed(SettingsRecord(), at: 200) {
            $0.language = .python
            $0.theme = .dracula
        }
        var keyboard = changed(SettingsRecord(), at: 300) { $0.language = .typescript }
        let adopted = try keyboard.merge(roundTrip(app), at: time(400))
        #expect(adopted)
        #expect(keyboard.settings.language == .typescript)
        #expect(keyboard.settings.theme == .dracula)

        let later = changed(app, at: 500) { $0.language = .json }
        let laterAdopted = keyboard.merge(later, at: time(600))
        #expect(laterAdopted)
        #expect(keyboard.settings.language == .json)
    }

    @Test func snippetsMergeOneAtATime() throws {
        let arrow = CodeSnippet.defaults[0].id, comment = CodeSnippet.defaults[2].id, pipe = CodeSnippet.defaults[3].id
        let added = CodeSnippet(name: "Added in app", text: "print(1)")
        var keyboard = changed(SettingsRecord(), at: 100) {
            $0.snippets.append(CodeSnippet(name: "Keyboard", text: "ls"))
        }
        keyboard = changed(keyboard, at: 150) { $0.snippets.removeAll { $0.id == comment } }
        let app = changed(SettingsRecord(), at: 200) {
            $0.snippets[0].text = " -> "
            $0.snippets.removeAll { $0.id == pipe }
            $0.snippets.append(added)
        }

        let adopted = try keyboard.merge(roundTrip(app), at: time(300))
        #expect(adopted)
        #expect(keyboard.settings.snippets.map(\.name) == ["Arrow", "Not equal", "Home path", "Keyboard", "Added in app"])
        #expect(keyboard.settings.snippets.first { $0.id == arrow }?.text == " -> ")

        // The keyboard's later edit survives an older edit from the app.
        keyboard = changed(keyboard, at: 400) { settings in
            if let index = settings.snippets.firstIndex(where: { $0.id == added.id }) { settings.snippets[index].text = "print(2)" }
        }
        let olderEdit = changed(app, at: 350) { settings in
            if let index = settings.snippets.firstIndex(where: { $0.id == added.id }) { settings.snippets[index].text = "print(3)" }
        }
        let olderEditAdopted = keyboard.merge(olderEdit, at: time(500))
        #expect(!olderEditAdopted)
        #expect(keyboard.settings.snippets.first { $0.id == added.id }?.text == "print(2)")

        // A deletion in the app after the keyboard's edit removes it.
        let deleted = changed(olderEdit, at: 600) { $0.snippets.removeAll { $0.id == added.id } }
        let deletionAdopted = keyboard.merge(deleted, at: time(700))
        #expect(deletionAdopted)
        #expect(!keyboard.settings.snippets.contains { $0.id == added.id })
        let readAgain = keyboard.merge(deleted, at: time(800))
        #expect(!readAgain)
    }

    @Test func resetInTheAppResetsTheKeyboardButNotItsLaterChanges() throws {
        var keyboardSettings = KeyboardSettings()
        keyboardSettings.language = .shell
        keyboardSettings.snippets.append(CodeSnippet(name: "Keyboard", text: "ls"))
        var keyboard = try legacy(keyboardSettings, at: 100)
        var app = changed(SettingsRecord(), at: 150) { $0.theme = .nord }
        app.reset(at: time(200))

        let adopted = try keyboard.merge(roundTrip(app), at: time(300))
        #expect(adopted)
        #expect(keyboard.settings == KeyboardSettings())

        var later = try legacy(keyboardSettings, at: 100)
        later = changed(later, at: 250) { $0.language = .python }
        let laterAdopted = later.merge(app, at: time(300))
        #expect(laterAdopted)
        #expect(later.settings.language == .python)
        #expect(!later.settings.snippets.contains { $0.name == "Keyboard" })
    }

    @Test func resetInTheKeyboardWinsOverOlderAppChanges() throws {
        let app = changed(SettingsRecord(), at: 100) {
            $0.language = .python
            $0.snippets.append(CodeSnippet(name: "Added in app", text: "x"))
        }
        var keyboard = changed(SettingsRecord(), at: 50) { $0.language = .shell }
        keyboard.reset(at: time(200))
        let adopted = try keyboard.merge(roundTrip(app), at: time(300))
        #expect(!adopted)
        #expect(keyboard.settings == KeyboardSettings())
    }

    @Test func fieldsForOneCopyOfTheKeyboardNeverMerge() throws {
        let app = changed(SettingsRecord(), at: 200) {
            $0.tipsShown = 3
            $0.enabledFullAccessFeatures = [.haptics]
        }
        var keyboard = SettingsRecord()
        let adopted = try keyboard.merge(roundTrip(app), at: time(300))
        #expect(!adopted)
        #expect(keyboard.settings.tipsShown == 0)
        #expect(keyboard.settings.enabledFullAccessFeatures.isEmpty)
    }

    @Test func unknownFieldsFromANewerVersionAreIgnored() throws {
        let app = changed(SettingsRecord(), at: 200) { $0.keySize = .comfortable }
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(app)) as? [String: Any])
        var settings = try #require(object["settings"] as? [String: Any])
        settings["featureFromTheFuture"] = true
        object["settings"] = settings
        var stamp = try #require(object["stamp"] as? [String: Any])
        var fields = try #require(stamp["fields"] as? [String: Any])
        fields["featureFromTheFuture"] = 250.0 - Date.timeIntervalBetween1970AndReferenceDate
        stamp["fields"] = fields
        object["stamp"] = stamp
        let newer = try JSONDecoder().decode(SettingsRecord.self, from: JSONSerialization.data(withJSONObject: object))

        var keyboard = SettingsRecord()
        let adopted = keyboard.merge(newer, at: time(300))
        #expect(adopted)
        #expect(keyboard.settings.keySize == .comfortable)
        let readAgain = keyboard.merge(newer, at: time(400))
        #expect(!readAgain)
    }

    @Test func builtInSnippetsHaveFixedIDsAndOlderRecordsAdoptThem() throws {
        #expect(KeyboardSettings().snippets.map(\.id) == CodeSnippet.defaults.map(\.id))
        #expect(CodeSnippet.defaults[0].id.uuidString == "54414246-0000-4000-8000-000000000001")
        #expect(Set(CodeSnippet.defaults.map(\.id)).count == CodeSnippet.defaults.count)

        var settings = KeyboardSettings()
        // Older builds gave the built-in snippets new random IDs on each launch.
        settings.snippets = CodeSnippet.defaults.map { CodeSnippet(name: $0.name, text: $0.text) }
        let custom = CodeSnippet(name: "Arrow", text: " -> ")
        settings.snippets.append(custom)
        let older = try legacy(settings, at: 100)
        #expect(older.settings.snippets.dropLast().map(\.id) == CodeSnippet.defaults.map(\.id))
        #expect(older.settings.snippets.last?.id == custom.id)

        // A record with history keeps the IDs it saved.
        var current = SettingsRecord()
        let copy = CodeSnippet(name: "Arrow", text: " => ")
        current.update(to: { var s = KeyboardSettings(); s.snippets = [copy]; return s }(), at: time(100))
        #expect(try roundTrip(current).settings.snippets.map(\.id) == [copy.id])
    }

    @Test func deletionHistoryStaysBounded() {
        let many = (0..<250).map { CodeSnippet(name: "S\($0)", text: "\($0)") }
        var record = changed(SettingsRecord(), at: 100) { $0.snippets = many }
        record = changed(record, at: 200) { $0.snippets = [] }
        #expect(record.effectiveStamp.deletedSnippets.count == SettingsStamp.deletionLimit)
    }

    @Test func unchangedSettingsAreNotRecordedAsAChange() {
        var record = changed(SettingsRecord(), at: 100) { $0.language = .python }
        let updated = record.update(to: record.settings, at: time(200))
        #expect(!updated)
        #expect(record.modified == time(100))
    }
}

struct KeyboardCapabilitiesTests {
    @Test func fullAccessIsNotRequested() {
        #expect(!KeyboardCapabilities.requestsFullAccess)
    }

    @Test func fullAccessFeaturesStayOffUntilChosen() throws {
        var settings = KeyboardSettings()
        #expect(settings.haptics)
        #expect(settings.enabledFullAccessFeatures.isEmpty)
        let granted = KeyboardCapabilities(host: .keyboardExtension(hasFullAccess: true))
        let denied = KeyboardCapabilities(host: .keyboardExtension(hasFullAccess: false))
        for feature in FullAccessFeature.allCases {
            #expect(!granted.allows(feature, in: settings))
            #expect(!denied.allows(feature, in: settings))
        }
        settings.enabledFullAccessFeatures = [.haptics]
        #expect(granted.allows(.haptics, in: settings))
        #expect(!denied.allows(.haptics, in: settings))
        #expect(granted.hasFullAccess && !denied.hasFullAccess)

        let restored = try JSONDecoder().decode(KeyboardSettings.self, from: JSONEncoder().encode(settings))
        #expect(restored.enabledFullAccessFeatures == [.haptics])
        settings.enabledFullAccessFeatures = []
        let object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(settings)) as? [String: Any])
        #expect(object["fullAccessOptIns"] == nil)
    }

    @Test func companionPreviewsFollowTheirOwnSetting() {
        var settings = KeyboardSettings()
        let app = KeyboardCapabilities(host: .companionApp)
        #expect(app.allows(.haptics, in: settings))
        settings.haptics = false
        #expect(!app.allows(.haptics, in: settings))
        #expect(!app.hasFullAccess)
    }
}
