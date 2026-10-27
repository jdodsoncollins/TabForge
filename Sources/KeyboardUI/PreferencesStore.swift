import Foundation
import Observation
import KeyboardCore

@MainActor @Observable
final class PreferencesStore {
    // Keep the existing record format and key so an update retains the local
    // copy previously saved by the keyboard. Never consult a shared container.
    private static let key = "keyboardPreferences.v1"
    private let local: UserDefaults?
    private let now: () -> Date
    private var timestamp = Date.distantPast
    private var isLoading = false
    var settings: KeyboardSettings { didSet { if !isLoading { save() } } }

    private struct Record: Codable { var settings: KeyboardSettings; var modified: Date }

    // A nil store keeps the companion's keyboard previews entirely in memory.
    init(local: UserDefaults? = .standard, now: @escaping () -> Date = Date.init) {
        self.local = local
        self.now = now
        settings = .init()
        refresh()
    }

    func refresh() {
        guard let data = local?.data(forKey: Self.key),
              let record = try? JSONDecoder().decode(Record.self, from: data),
              record.modified > timestamp else { return }
        isLoading = true
        settings = record.settings
        timestamp = record.modified
        isLoading = false
    }

    private func save() {
        timestamp = now()
        guard let local,
              let data = try? JSONEncoder().encode(Record(settings: settings, modified: timestamp)) else { return }
        local.set(data, forKey: Self.key)
    }

    func reset() {
        settings = .init()
        eraseTouchAdaptation()
    }

    // Optional tap calibration lives under its own key so turning the setting
    // off can erase it completely. It holds per-key offsets, never text.
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
