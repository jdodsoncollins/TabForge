import Foundation

/// One saved copy of the keyboard settings, with enough history to merge it
/// with another copy.
///
/// The companion app writes its copy to the App Group container it shares
/// with the keyboard. Without Full Access the keyboard can read that container
/// but cannot write to it, so the app never sees changes made in the keyboard.
/// Merging field by field, and snippet by snippet, keeps a change made in one
/// place from erasing unrelated changes made in the other: for each part, the
/// more recent change wins.
public struct SettingsRecord: Codable, Equatable, Sendable {
    public private(set) var settings: KeyboardSettings
    /// When this copy last changed.
    public private(set) var modified: Date
    /// Absent from records saved before settings were shared. Such a record
    /// counts as changed entirely at `modified`.
    private var stamp: SettingsStamp?

    public init(settings: KeyboardSettings = KeyboardSettings(), modified: Date = .distantPast) {
        self.settings = settings
        self.modified = modified
    }

    private enum CodingKeys: String, CodingKey { case settings, modified, stamp }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        settings = try container.decode(KeyboardSettings.self, forKey: .settings)
        modified = try container.decode(Date.self, forKey: .modified)
        stamp = try container.decodeIfPresent(SettingsStamp.self, forKey: .stamp)
        if stamp == nil { settings.useStableDefaultSnippetIDs() }
    }

    var effectiveStamp: SettingsStamp { stamp ?? SettingsStamp(base: modified) }

    /// Replaces the settings and notes when each field and snippet changed.
    /// Returns false, changing nothing, when the settings are the same.
    @discardableResult
    public mutating func update(to newSettings: KeyboardSettings, at date: Date) -> Bool {
        guard newSettings != settings else { return false }
        var stamp = effectiveStamp
        let before = SettingsFields.values(of: settings), after = SettingsFields.values(of: newSettings)
        for key in Set(before.keys).union(after.keys) where before[key] != after[key] {
            stamp.fields[key] = date
        }
        let oldSnippets = SettingsFields.byID(settings.snippets)
        let newSnippets = SettingsFields.byID(newSettings.snippets)
        for (id, snippet) in newSnippets where oldSnippets[id] != snippet {
            stamp.noteChange(ofSnippet: id, at: date)
        }
        for id in oldSnippets.keys where newSnippets[id] == nil {
            stamp.noteDeletion(ofSnippet: id, at: date)
        }
        stamp.trimDeletions()
        settings = newSettings
        modified = date
        self.stamp = stamp
        return true
    }

    /// Restores the default settings and snippets. The reset counts as a
    /// change to every field and snippet, so it wins over anything older.
    public mutating func reset(at date: Date) {
        settings = KeyboardSettings()
        modified = date
        stamp = SettingsStamp(base: date)
    }

    /// Adopts each field and snippet that `incoming` changed more recently
    /// than this record did, keeping everything else. Fields that describe one
    /// copy of the keyboard, such as Full Access opt-ins, are never adopted.
    /// Returns whether anything changed.
    @discardableResult
    public mutating func merge(_ incoming: SettingsRecord, at date: Date) -> Bool {
        let theirs = incoming.effectiveStamp
        var ours = effectiveStamp
        var fieldsChanged = false

        var object = SettingsFields.object(of: settings)
        let theirObject = SettingsFields.object(of: incoming.settings)
        let keys = Set(object.keys).union(theirObject.keys)
            .subtracting(SettingsFields.localOnly)
            .subtracting([SettingsFields.snippets])
        for key in keys.sorted() {
            let time = theirs.time(ofField: key)
            guard time > ours.time(ofField: key),
                  SettingsFields.data(object[key]) != SettingsFields.data(theirObject[key]) else { continue }
            var candidate = object
            candidate[key] = theirObject[key]
            // Skip a value this version can't read rather than discard the record.
            guard SettingsFields.settings(from: candidate) != nil else { continue }
            object = candidate
            ours.fields[key] = time
            fieldsChanged = true
        }
        var merged = fieldsChanged ? SettingsFields.settings(from: object) ?? settings : settings
        // A field this version doesn't know decodes to nothing; it isn't a change.
        fieldsChanged = merged != settings

        let theirSnippets = SettingsFields.byID(incoming.settings.snippets)
        var snippets: [CodeSnippet] = []
        var seen = Set<UUID>()
        var snippetsChanged = false
        for snippet in merged.snippets {
            let id = snippet.id
            guard seen.insert(id).inserted else { snippets.append(snippet); continue }
            if let their = theirSnippets[id] {
                let time = theirs.time(ofSnippet: id)
                if time > ours.time(ofSnippet: id), their != snippet {
                    snippets.append(their)
                    ours.noteChange(ofSnippet: id, at: time)
                    snippetsChanged = true
                } else {
                    snippets.append(snippet)
                }
            } else {
                let time = theirs.time(ofDeletion: id)
                if time > ours.time(ofSnippet: id) {
                    ours.noteDeletion(ofSnippet: id, at: time)
                    snippetsChanged = true
                } else {
                    snippets.append(snippet)
                }
            }
        }
        // Snippets only the other copy has join the end, in its order.
        for their in incoming.settings.snippets {
            guard seen.insert(their.id).inserted else { continue }
            let time = theirs.time(ofSnippet: their.id)
            guard time > ours.time(ofDeletion: their.id) else { continue }
            snippets.append(their)
            ours.noteChange(ofSnippet: their.id, at: time)
            snippetsChanged = true
        }
        if snippetsChanged { merged.snippets = snippets }

        guard fieldsChanged || snippetsChanged else { return false }
        ours.trimDeletions()
        settings = merged
        stamp = ours
        modified = date
        return true
    }
}

/// When each part of a settings record last changed.
struct SettingsStamp: Codable, Equatable, Sendable {
    /// The time of every field and snippet without a time of its own.
    var base: Date
    var fields: [String: Date] = [:]
    /// Snippet times and deletions, keyed by snippet ID.
    var snippets: [String: Date] = [:]
    var deletedSnippets: [String: Date] = [:]

    /// Only the newest deletions are kept. A snippet deleted before them
    /// counts as deleted at `base`.
    static let deletionLimit = 200

    init(base: Date) { self.base = base }

    private enum CodingKeys: String, CodingKey { case base, fields, snippets, deletedSnippets }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        base = try container.decode(Date.self, forKey: .base)
        fields = try container.decodeIfPresent([String: Date].self, forKey: .fields) ?? [:]
        snippets = try container.decodeIfPresent([String: Date].self, forKey: .snippets) ?? [:]
        deletedSnippets = try container.decodeIfPresent([String: Date].self, forKey: .deletedSnippets) ?? [:]
    }

    func time(ofField key: String) -> Date { fields[key] ?? base }
    func time(ofSnippet id: UUID) -> Date { snippets[id.uuidString] ?? base }
    func time(ofDeletion id: UUID) -> Date { max(deletedSnippets[id.uuidString] ?? .distantPast, base) }

    mutating func noteChange(ofSnippet id: UUID, at date: Date) {
        snippets[id.uuidString] = date
        deletedSnippets[id.uuidString] = nil
    }

    mutating func noteDeletion(ofSnippet id: UUID, at date: Date) {
        snippets[id.uuidString] = nil
        deletedSnippets[id.uuidString] = date
    }

    mutating func trimDeletions() {
        guard deletedSnippets.count > Self.deletionLimit else { return }
        let kept = deletedSnippets.sorted { $0.value > $1.value }.prefix(Self.deletionLimit)
        deletedSnippets = Dictionary(uniqueKeysWithValues: kept.map { ($0.key, $0.value) })
    }
}

/// Compares settings field by field through their saved JSON form, so a
/// field added later takes part in merging without being listed here.
enum SettingsFields {
    static let snippets = "snippets"
    /// Fields that describe one copy of the keyboard rather than the person's
    /// preferences: tips this copy has shown, and Full Access opt-ins, which
    /// only the keyboard where Full Access is granted can confirm.
    static let localOnly: Set<String> = ["shownTips", "fullAccessOptIns"]

    static func object(of settings: KeyboardSettings) -> [String: Any] {
        guard let data = try? JSONEncoder().encode(settings),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return object
    }

    /// Each field except the snippets, in a form that compares reliably.
    static func values(of settings: KeyboardSettings) -> [String: Data] {
        var fields = object(of: settings)
        fields[snippets] = nil
        return fields.compactMapValues { data($0) }
    }

    static func data(_ value: Any?) -> Data? {
        // Wrapping the value makes any JSON value a valid top-level object.
        guard let value, JSONSerialization.isValidJSONObject([value]) else { return nil }
        return try? JSONSerialization.data(withJSONObject: [value], options: .sortedKeys)
    }

    static func settings(from object: [String: Any]) -> KeyboardSettings? {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object) else { return nil }
        return try? JSONDecoder().decode(KeyboardSettings.self, from: data)
    }

    static func byID(_ snippets: [CodeSnippet]) -> [UUID: CodeSnippet] {
        Dictionary(snippets.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }
}
