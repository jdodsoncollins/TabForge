import UIKit
import KeyboardCore

struct KeyboardPalette {
    let background: UIColor
    let key: UIColor
    let utility: UIColor
    let text: UIColor
    let secondary: UIColor
    let accent: UIColor

    static func resolve(_ theme: KeyboardTheme) -> Self {
        switch theme {
        case .standard:
            Self(
                background: UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.075, alpha: 1) : UIColor(white: 0.9, alpha: 1) },
                key: UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.18, alpha: 1) : .white },
                utility: UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.12, alpha: 1) : UIColor(white: 0.82, alpha: 1) },
                text: .label,
                secondary: UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.75, alpha: 1) : UIColor(white: 0.35, alpha: 1) },
                accent: UIColor { $0.userInterfaceStyle == .dark ? rgb(0x81BDFF) : rgb(0x0060C5) }
            )
        case .darcula:
            Self(background: rgb(0x2B2B2B), key: rgb(0x3C3F41), utility: rgb(0x323537),
                 text: rgb(0xC0CBD8), secondary: rgb(0xA9B7C6), accent: rgb(0xFFC66D))
        case .dracula:
            Self(background: rgb(0x282A36), key: rgb(0x353746), utility: rgb(0x44475A),
                 text: rgb(0xF8F8F2), secondary: rgb(0xC1C5DD), accent: rgb(0xBD93F9))
        case .nord:
            Self(background: rgb(0x2E3440), key: rgb(0x3B4252), utility: rgb(0x434C5E),
                 text: rgb(0xECEFF4), secondary: rgb(0xD8DEE9), accent: rgb(0x88C0D0))
        }
    }

    private static func rgb(_ value: UInt32) -> UIColor {
        UIColor(red: CGFloat((value >> 16) & 255) / 255, green: CGFloat((value >> 8) & 255) / 255,
                blue: CGFloat(value & 255) / 255, alpha: 1)
    }
}
