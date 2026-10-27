import Foundation

/// Optional language features, from least to most memory.
public enum LanguageFeatureTier: Int, Comparable, Sendable {
    /// Only the system spelling service; no bundled word list, swipe, or tap learning.
    case minimal
    /// The bundled word list: touch-aware correction and English suggestions.
    case standard
    /// Also swipe typing.
    case full

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Chooses which optional features fit. Apple does not publish a memory limit
/// for keyboard extensions, and a keyboard over its limit is terminated by the
/// system. The keyboard runs in its own process, so this protects the keyboard;
/// the app being typed into has its own separate allowance.
public enum MemoryBudget {
    /// Assumed limit when the system reports only current use. Measured
    /// keyboard limits have been higher; this errs low.
    public static let assumedLimit: UInt64 = 48 << 20
    /// Free memory to keep before loading the word list and swipe index
    /// (together about 1–2 MB, plus short-lived work while decoding).
    public static let fullHeadroom: UInt64 = 16 << 20
    public static let standardHeadroom: UInt64 = 8 << 20
    /// Devices below this much RAM skip swipe, since the system reclaims
    /// memory from background and extension processes sooner on them.
    public static let swipeMinimumPhysicalMemory: UInt64 = 3 << 30

    /// - Parameters:
    ///   - available: The system's report of memory this process may still use,
    ///     or nil/zero when unavailable.
    ///   - footprint: This process's current memory footprint, if known.
    ///   - physicalMemory: Device RAM, or zero if unknown.
    public static func tier(available: UInt64?, footprint: UInt64?, physicalMemory: UInt64) -> LanguageFeatureTier {
        let headroom: UInt64? = if let available, available > 0 {
            available
        } else if let footprint {
            assumedLimit > footprint ? assumedLimit - footprint : 0
        } else {
            nil
        }
        let measured: LanguageFeatureTier = switch headroom {
        case nil: .full
        case let value? where value >= fullHeadroom: .full
        case let value? where value >= standardHeadroom: .standard
        default: .minimal
        }
        guard physicalMemory == 0 || physicalMemory >= swipeMinimumPhysicalMemory else { return min(measured, .standard) }
        return measured
    }
}
