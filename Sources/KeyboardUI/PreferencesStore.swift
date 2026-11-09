import Foundation
import Observation
import KeyboardCore

/// The companion app's copy of the keyboard settings and snippets, kept in the
/// App Group container the app and the keyboard share.
///
/// Only the app writes this file. Without Full Access, iOS lets a keyboard
/// read its containing app's shared container but not write to it, so the
/// keyboard reads the file when it appears and merges newer changes into its
/// own local record. A missing, oversized or unreadable file is ignored.
struct SharedSettingsFile: Sendable {
    /// The Info.plist key that holds the App Group identifier.
    static let infoKey = "TabForgeAppGroup"
    static let fileName = "keyboard-settings.v1.json"
    /// Far larger than any real record. A bigger file is never read into the keyboard.
    static let maximumSize = 512 * 1024

    let url: URL

    /// The shared file, or nil when this build has no App Group, such as an
    /// unsigned Simulator build.
    static func appGroup(in bundle: Bundle = .main) -> SharedSettingsFile? {
        guard let identifier = bundle.object(forInfoDictionaryKey: infoKey) as? String,
              identifier.hasPrefix("group."), !identifier.contains("$("),
              let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
        else { return nil }
        return SharedSettingsFile(url: container.appending(path: fileName, directoryHint: .notDirectory))
    }

    func read() -> SettingsRecord? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: Self.maximumSize + 1),
              data.count <= Self.maximumSize else { return nil }
        return try? JSONDecoder().decode(SettingsRecord.self, from: data)
    }

    /// Replaces the file in one step, so a reader never sees half a record.
    func write(_ data: Data) -> Bool {
        guard data.count <= Self.maximumSize else { return false }
        do {
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            return true
        } catch {
            return false
        }
    }
}

@MainActor @Observable
final class PreferencesStore {
    enum Sharing {
        /// Settings stay in this store.
        case off
        /// The keyboard: merges newer changes from the app's shared file into
        /// its local record. It never writes the file.
        case read(SharedSettingsFile)
        /// The companion app: the shared file is this store's record.
        case publish(SharedSettingsFile)
    }

    // Keep the existing key and record format so an update retains the copy
    // the keyboard saved before settings were shared.
    nonisolated static let keyboardKey = "keyboardPreferences.v1"
    private let local: UserDefaults?
    private let key: String
    private let sharing: Sharing
    private let now: () -> Date
    @ObservationIgnored private var record = SettingsRecord()
    private var isLoading = false
    var settings: KeyboardSettings { didSet { if !isLoading { save() } } }
    /// True when the last attempt to share settings with the keyboard failed.
    private(set) var sharingFailed = false

    /// A nil local store with no sharing keeps settings entirely in memory.
    init(
        local: UserDefaults? = .standard,
        key: String = PreferencesStore.keyboardKey,
        sharing: Sharing = .off,
        now: @escaping () -> Date = Date.init
    ) {
        self.local = local
        self.key = key
        self.sharing = sharing
        self.now = now
        settings = .init()
        refresh()
    }

    /// True when changes here reach the keyboard in other apps.
    var sharesWithKeyboard: Bool {
        switch sharing {
        case .publish: true
        case .off, .read: false
        }
    }

    /// True in the keyboard when it can read the app's shared settings.
    var readsFromApp: Bool {
        switch sharing {
        case .read: true
        case .off, .publish: false
        }
    }

    func refresh() {
        if let data = local?.data(forKey: key),
           let stored = try? JSONDecoder().decode(SettingsRecord.self, from: data),
           stored.modified > record.modified {
            adopt(stored)
        }
        switch sharing {
        case .off:
            break
        case .read(let file):
            guard let incoming = file.read() else { break }
            var merged = record
            if merged.merge(incoming, at: now()) {
                adopt(merged)
                persist()
            }
        case .publish(let file):
            if let stored = file.read(), stored.modified > record.modified { adopt(stored) }
        }
    }

    func reset() {
        record.reset(at: now())
        adopt(record)
        persist()
        eraseTouchAdaptation()
    }

    private func adopt(_ newRecord: SettingsRecord) {
        record = newRecord
        isLoading = true
        settings = newRecord.settings
        isLoading = false
    }

    private func save() {
        guard record.update(to: settings, at: now()) else { return }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(record) else { return }
        local?.set(data, forKey: key)
        if case .publish(let file) = sharing {
            let failed = !file.write(data)
            if sharingFailed != failed { sharingFailed = failed }
        }
    }

    // Optional tap calibration lives under its own key so turning the setting
    // off can erase it completely. It holds per-key offsets, never text, and
    // is never shared.
    private static let touchKey = "touchAdaptation.v1"

    func loadTouchAdaptation() -> TouchAdaptation {
        guard settings.learnTapPositions, let data = local?.data(forKey: Self.touchKey),
              let adaptation = try? JSONDecoder().decode(TouchAdaptation.self, from: data) else { return .init() }
        return adaptation
    }

    func saveTouchAdaptation(_ adaptation: TouchAdaptation) {
        guard settings.learnTapPositions, !adaptation.isEmpty else { return }
        local?.set(try? JSONEncoder().encode(adaptation), forKey: Self.touchKey)
    }

    func eraseTouchAdaptation() { local?.removeObject(forKey: Self.touchKey) }
}
