import Foundation

public struct KeyboardModifiers: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let control = Self(rawValue: 1 << 0)
    public static let option = Self(rawValue: 1 << 1)
    public static let command = Self(rawValue: 1 << 2)
}

public extension EditingEngine {
    /// iOS text proxies cannot synthesize hardware key events. Only encode
    /// shortcuts with a defined text protocol; never insert a bare fallback key.
    @discardableResult
    func sendShortcut(_ text: String, modifiers: KeyboardModifiers) -> Bool {
        guard !modifiers.isEmpty else { type(text); return true }
        invalidateAutocorrection()
        guard settings.compatibility == .terminal, !modifiers.contains(.command) else { return false }
        var output = text
        if modifiers.contains(.control) {
            guard text.unicodeScalars.count == 1, text.unicodeScalars.first!.isASCII,
                  let ascii = text.uppercased().unicodeScalars.first?.value,
                  (64...95).contains(ascii) || ascii == 32 || ascii == 63 else { return false }
            output = String(UnicodeScalar(ascii == 63 ? 127 : ascii & 0x1F)!)
        }
        if modifiers.contains(.option) { output = "\u{1B}" + output }
        document.insert(output)
        return true
    }

    @discardableResult
    func navigate(_ key: NavigationKey, modifiers: KeyboardModifiers = []) -> Bool {
        invalidateAutocorrection()
        if settings.compatibility == .terminal { return sendTerminalNavigation(key, modifiers: modifiers) }
        guard !modifiers.contains(.control), modifiers != [.option, .command],
              modifiers.isEmpty || settings.compatibility == .editor else { return false }
        if modifiers.contains(.command) {
            switch key {
            case .left: return navigate(.home)
            case .right: return navigate(.end)
            case .up, .down:
                guard document.hasCompleteContext else { return false }
                let offset = key == .up ? -(document.before?.utf16.count ?? 0) : document.after?.utf16.count ?? 0
                document.move(by: offset)
                return true
            default: return false
            }
        }
        if modifiers.contains(.option) {
            guard key == .left || key == .right,
                  let context = key == .left ? document.contextBeforeInput(maximumCharacters: 4096) : document.contextAfterInput(maximumCharacters: 4096) else { return false }
            let characters = key == .left ? Array(context.reversed()) : Array(context)
            let spaces = characters.prefix { $0.isWhitespace }.count
            let remainder = characters.dropFirst(spaces)
            let word = remainder.prefix { !$0.isWhitespace && isWordCharacter($0) == remainder.first.map(isWordCharacter) }
            let distance = String(characters.prefix(spaces + word.count)).utf16.count
            document.move(by: key == .left ? -distance : distance)
            return true
        }
        // Proxy hosts can decline movement or omit context. Up/down fall back to
        // logical lines; the native playground uses UIKit's visual-line movement.
        switch key {
        case .left: document.move(by: -(document.contextBeforeInput(maximumCharacters: 1)?.last.map { String($0).utf16.count } ?? 1))
        case .right: document.move(by: document.contextAfterInput(maximumCharacters: 1)?.first.map { String($0).utf16.count } ?? 1)
        case .home:
            guard let before = document.contextBeforeInput(maximumCharacters: 4096) else { return false }
            document.move(by: -before[...].prefixThroughCurrentLine.utf16.count)
        case .end:
            guard let after = document.contextAfterInput(maximumCharacters: 4096) else { return false }
            document.move(by: after.prefix { $0 != "\n" && $0 != "\r\n" }.utf16.count)
        case .escape: document.insert("\u{1B}")
        case .up, .down:
            if document.moveVertically(by: key == .up ? -1 : 1) { return true }
            return moveLogicalLine(up: key == .up)
        case .pageUp, .pageDown: return false
        }
        return true
    }

    private func sendTerminalNavigation(_ key: NavigationKey, modifiers: KeyboardModifiers) -> Bool {
        guard !modifiers.contains(.command) else { return false }
        let modifier = 1 + (modifiers.contains(.option) ? 2 : 0) + (modifiers.contains(.control) ? 4 : 0)
        let final: String
        switch key {
        case .left: final = "D"
        case .right: final = "C"
        case .up: final = "A"
        case .down: final = "B"
        case .home: final = "H"
        case .end: final = "F"
        case .escape:
            guard modifiers.isEmpty else { return false }
            document.insert("\u{1B}"); return true
        case .pageUp, .pageDown:
            document.insert("\u{1B}[" + (key == .pageUp ? "5" : "6") + (modifiers.isEmpty ? "~" : ";\(modifier)~"))
            return true
        }
        if !modifiers.isEmpty { document.insert("\u{1B}[1;\(modifier)" + final) }
        else {
            let application = settings.terminalApplicationCursor && [.left, .right, .up, .down].contains(key)
            document.insert("\u{1B}" + (application ? "O" : "[") + final)
        }
        return true
    }

    private func isWordCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_"
    }

    private func moveLogicalLine(up: Bool) -> Bool {
        guard let before = document.before, let after = document.after else { return false }
        let prefix = before.suffix(4096)
        let column = prefix.prefixThroughCurrentLine.count
        if up {
            guard let newline = prefix.lastIndex(where: { $0 == "\n" || $0 == "\r\n" }) else { return document.hasCompleteContext }
            let previous = prefix[..<newline].prefixThroughCurrentLine
            // A truncated context must not masquerade as a complete prior line.
            guard prefix[..<newline].contains(where: { $0 == "\n" || $0 == "\r\n" }) || (document.hasCompleteContext && before.count <= 4096) else { return false }
            let distance = prefix[newline...].utf16.count + previous.utf16.count - previous.prefix(column).utf16.count
            document.move(by: -distance)
        } else {
            let suffix = after.prefix(4096)
            guard let newline = suffix.firstIndex(where: { $0 == "\n" || $0 == "\r\n" }) else { return document.hasCompleteContext }
            let next = suffix[suffix.index(after: newline)...].prefix { $0 != "\n" && $0 != "\r\n" }
            guard next.count >= column || next.endIndex < suffix.endIndex || (document.hasCompleteContext && after.count <= 4096) else { return false }
            document.move(by: suffix[...newline].utf16.count + next.prefix(column).utf16.count)
        }
        return true
    }
}

private extension Substring {
    var prefixThroughCurrentLine: Substring {
        guard let newline = lastIndex(where: { $0 == "\n" || $0 == "\r\n" }) else { return self }
        return self[index(after: newline)...]
    }
}
