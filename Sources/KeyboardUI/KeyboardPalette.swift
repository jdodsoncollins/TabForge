import UIKit
import KeyboardCore

struct KeyboardPalette {
    /// Painted behind the keys. iOS Standard is clear inside a system keyboard
    /// input view, so the system's own keyboard material shows through.
    let background: UIColor
    /// An opaque stand-in for that material, used where nothing else draws one
    /// (in-app previews) and as the reference for contrast checks.
    let backdrop: UIColor
    let key: UIColor
    let utility: UIColor
    /// A key while it is held down.
    let pressed: UIColor
    /// Opaque surfaces drawn over other keys: callouts, previews and status.
    let callout: UIColor
    let text: UIColor
    let secondary: UIColor
    let accent: UIColor
    /// Text drawn on an accent fill, such as the selected callout entry.
    let onAccent: UIColor
    /// The return key's fill when the host names a primary action (Go, Search,
    /// Send…), as the system keyboard does. Nil keeps the utility fill.
    let primaryAction: UIColor?
    /// Matches the system keyboard: the system font and rounder keys.
    let matchesSystem: Bool

    /// The system keyboard's material shows through a clear background only
    /// when a keyboard-style input view hosts the keys.
    func background(hostedBySystemKeyboard: Bool) -> UIColor {
        matchesSystem && !hostedBySystemKeyboard ? backdrop : background
    }

    static func resolve(_ theme: KeyboardTheme) -> Self {
        switch theme {
        case .standard:
            // Measured from the iPadOS system keyboard over its glass: keys are a
            // translucent light fill, letters and function keys alike.
            let backdrop = UIColor { $0.userInterfaceStyle == .dark
                ? UIColor(red: 0.137, green: 0.137, blue: 0.145, alpha: 1)
                : UIColor(red: 0.82, green: 0.835, blue: 0.86, alpha: 1) }
            let key = UIColor { $0.userInterfaceStyle == .dark
                ? UIColor(white: 0.63, alpha: 0.29)
                : UIColor(white: 1, alpha: 0.92) }
            return Self(
                background: .clear,
                backdrop: backdrop,
                key: key,
                utility: key,
                pressed: UIColor { $0.userInterfaceStyle == .dark
                    ? UIColor(white: 0.72, alpha: 0.55)
                    : UIColor(white: 0.6, alpha: 0.55) },
                callout: UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.27, alpha: 1) : .white },
                text: .label,
                secondary: UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.75, alpha: 1) : UIColor(white: 0.35, alpha: 1) },
                accent: UIColor { $0.userInterfaceStyle == .dark ? rgb(0x81BDFF) : rgb(0x0060C5) },
                onAccent: UIColor { $0.userInterfaceStyle == .dark ? .black : .white },
                primaryAction: .systemBlue,
                matchesSystem: true
            )
        case .darcula:
            return code(background: rgb(0x2B2B2B), key: rgb(0x3C3F41), utility: rgb(0x323537),
                        text: rgb(0xC0CBD8), secondary: rgb(0xA9B7C6), accent: rgb(0xFFC66D))
        case .dracula:
            return code(background: rgb(0x282A36), key: rgb(0x353746), utility: rgb(0x44475A),
                        text: rgb(0xF8F8F2), secondary: rgb(0xC1C5DD), accent: rgb(0xBD93F9))
        case .nord:
            return code(background: rgb(0x2E3440), key: rgb(0x3B4252), utility: rgb(0x434C5E),
                        text: rgb(0xECEFF4), secondary: rgb(0xD8DEE9), accent: rgb(0x88C0D0))
        }
    }

    /// Code palettes keep their own opaque background and monospaced legends.
    private static func code(background: UIColor, key: UIColor, utility: UIColor,
                             text: UIColor, secondary: UIColor, accent: UIColor) -> Self {
        Self(background: background, backdrop: background, key: key, utility: utility,
             pressed: accent.withAlphaComponent(0.35), callout: key, text: text, secondary: secondary,
             accent: accent, onAccent: background, primaryAction: nil, matchesSystem: false)
    }

    private static func rgb(_ value: UInt32) -> UIColor {
        UIColor(red: CGFloat((value >> 16) & 255) / 255, green: CGFloat((value >> 8) & 255) / 255,
                blue: CGFloat(value & 255) / 255, alpha: 1)
    }
}
