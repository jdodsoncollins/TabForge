import Foundation

/// A feature that iOS allows a keyboard extension only with Full Access.
///
/// TabForge does not request Full Access, so none of these can run in the
/// keyboard today. When a later version requests it, each feature still stays
/// off until the person turns it on in the keyboard (see
/// `KeyboardSettings.enabledFullAccessFeatures`). Everything else must keep
/// working without Full Access.
public enum FullAccessFeature: String, CaseIterable, Sendable {
    /// Taptic feedback on key presses. Without Full Access iOS keeps a
    /// keyboard from vibrating, so TabForge plays the system key click instead.
    case haptics

    public var title: String {
        switch self {
        case .haptics: "Haptic feedback"
        }
    }

    public var detail: String {
        switch self {
        case .haptics: "iOS lets a keyboard vibrate only with Full Access. Key click sounds work without it."
        }
    }
}

/// Where a keyboard view runs, which decides what it may do.
public enum KeyboardHost: Equatable, Sendable {
    /// The companion app's previews. They are ordinary app code, which iOS
    /// does not restrict the way it restricts keyboard extensions.
    case companionApp
    /// The keyboard extension in another app.
    case keyboardExtension(hasFullAccess: Bool)
}

/// The single check for features that need Full Access.
public struct KeyboardCapabilities: Equatable, Sendable {
    /// Mirrors `RequestsOpenAccess` in the keyboard's Info.plist. A hosted
    /// test fails if the two disagree, so turning this on is a deliberate,
    /// reviewed change that must also update PRIVACY.md and the website policy.
    public static let requestsFullAccess = false

    public var host: KeyboardHost

    public init(host: KeyboardHost) { self.host = host }

    public var hasFullAccess: Bool {
        switch host {
        case .companionApp: false
        case .keyboardExtension(let granted): granted
        }
    }

    public func allows(_ feature: FullAccessFeature, in settings: KeyboardSettings) -> Bool {
        switch host {
        case .companionApp:
            switch feature {
            case .haptics: settings.haptics
            }
        case .keyboardExtension(let granted):
            granted && settings.enabledFullAccessFeatures.contains(feature)
        }
    }
}
