import Foundation

@MainActor
public protocol TextDocument: AnyObject {
    var before: String? { get }
    var after: String? { get }
    /// Nearby context, bounded in extended grapheme clusters. Native adapters
    /// should slice their buffer before creating a String to avoid copying the
    /// entire document on every keystroke. Nil still means unavailable context.
    func contextBeforeInput(maximumCharacters: Int) -> String?
    func contextAfterInput(maximumCharacters: Int) -> String?
    var selectedText: String? { get }
    /// True only for adapters that expose the entire buffer, including both ends.
    var hasCompleteContext: Bool { get }
    /// Host traits must explicitly permit prose correction. Unknown hosts stay
    /// literal; secure or code-oriented fields should never opt in.
    var allowsAutocorrection: Bool { get }
    /// Identifies the focused document when the host exposes an identity.
    var autocorrectionContextIdentifier: UUID? { get }
    func insert(_ text: String)
    func deleteBackward()
    /// Matches UITextInput offsets, measured in UTF-16 code units.
    func move(by offset: Int)
    /// Native editors can move by a visual line, including soft wrapping.
    /// Returns false when the host only exposes a text proxy.
    func moveVertically(by lines: Int) -> Bool
    /// Deletes the exact text adjacent to a collapsed cursor. Native adapters can
    /// implement this as one edit; proxy adapters must verify cursor movement.
    func deleteSurroundingText(before prefix: String, after suffix: String) -> Bool
    /// Replaces only a verified suffix at a collapsed cursor. Implementations
    /// backed by a native text view can register this as one undoable edit.
    func replaceTextBeforeCursor(_ expected: String, with replacement: String) -> Bool
}

public extension TextDocument {
    var hasCompleteContext: Bool { false }
    var allowsAutocorrection: Bool { false }
    var autocorrectionContextIdentifier: UUID? { nil }
    func contextBeforeInput(maximumCharacters: Int) -> String? {
        before.map { String($0.suffix(max(0, maximumCharacters))) }
    }
    func contextAfterInput(maximumCharacters: Int) -> String? {
        after.map { String($0.prefix(max(0, maximumCharacters))) }
    }
    func moveVertically(by lines: Int) -> Bool { false }

    func replaceTextBeforeCursor(_ expected: String, with replacement: String) -> Bool {
        guard !expected.isEmpty, expected.count <= 64, replacement.count <= 64,
              selectedText == nil,
              let before = contextBeforeInput(maximumCharacters: expected.count + 32),
              before.hasSuffix(expected) else { return false }
        let after = contextAfterInput(maximumCharacters: 32)
        let anchor = String(before.dropLast(expected.count).suffix(32))
        let identifier = autocorrectionContextIdentifier
        var remaining = expected
        func matches(_ suffix: String) -> Bool {
            selectedText == nil && autocorrectionContextIdentifier == identifier &&
                contextBeforeInput(maximumCharacters: max(1, anchor.count + suffix.count)) == anchor + suffix &&
                contextAfterInput(maximumCharacters: 32) == after
        }
        func restoreDeletedSuffix() {
            guard remaining.count < expected.count, matches(remaining) else { return }
            insert(String(expected.dropFirst(remaining.count)))
        }
        for character in expected.reversed() {
            guard matches(remaining) else { return false }
            deleteBackward()
            let shorter = String(remaining.dropLast())
            guard matches(shorter) else {
                // A host may ignore a delete. Restore the part we removed only
                // when both sides still identify the exact same cursor.
                restoreDeletedSuffix()
                return false
            }
            guard remaining.last == character else { return false }
            remaining = shorter
        }
        guard matches("") else { return false }
        if replacement.isEmpty { return true }
        insert(replacement)
        if matches(replacement) { return true }
        // Length limits or host transforms may accept only part of an insert.
        // Recover the exact inserted segment from the same complete left
        // anchor, then remove only that verified text before restoring the
        // original spelling. A shortened or unavailable context is not proof.
        guard selectedText == nil, autocorrectionContextIdentifier == identifier,
              contextAfterInput(maximumCharacters: 32) == after,
              let actual = contextBeforeInput(maximumCharacters: anchor.count + 64) else { return false }
        let inserted: String
        if anchor.isEmpty {
            inserted = actual
        } else {
            // A transform can insert the anchor itself (for example a space).
            // Neither the first nor last occurrence proves the old boundary
            // when more than one is present. Include overlapping matches.
            var boundary: Range<String.Index>?
            var searchStart = actual.startIndex
            while searchStart < actual.endIndex,
                  let match = actual.range(of: anchor, range: searchStart..<actual.endIndex) {
                guard boundary == nil else { return false }
                boundary = match
                searchStart = actual.index(after: match.lowerBound)
            }
            guard let boundary else { return false }
            inserted = String(actual[boundary.upperBound...])
        }
        guard inserted.count <= 64, matches(inserted) else { return false }
        var insertedRemainder = inserted
        while !insertedRemainder.isEmpty {
            guard matches(insertedRemainder) else { return false }
            deleteBackward()
            insertedRemainder.removeLast()
            guard matches(insertedRemainder) else { return false }
        }
        guard matches("") else { return false }
        insert(expected)
        return false
    }

    func deleteSurroundingText(before prefix: String, after suffix: String) -> Bool {
        guard selectedText == nil, before?.hasSuffix(prefix) == true,
              after?.hasPrefix(suffix) == true, !prefix.isEmpty || !suffix.isEmpty else { return false }
        let text = prefix + suffix
        let originalBefore = before
        let originalAfter = after
        if !suffix.isEmpty {
            // Repeated lines can make an ignored move look successful. Decline
            // before moving when the current context already matches the target.
            guard originalBefore?.hasSuffix(text) != true else { return false }
            move(by: suffix.utf16.count)
        }
        guard before?.hasSuffix(text) == true else {
            // A host may decline movement or provide a smaller context window.
            if before != originalBefore || after != originalAfter { move(by: -suffix.utf16.count) }
            return false
        }
        for character in text.reversed() {
            guard before?.last == character else { return false }
            deleteBackward()
        }
        return true
    }
}

/// A real text buffer used by tests and non-UIKit clients.
@MainActor
public final class MemoryDocument: TextDocument {
    public private(set) var text: String
    public var selection: NSRange
    public var exposesContext = true
    public var allowsAutocorrection = false
    public var autocorrectionContextIdentifier: UUID? = UUID()
    public var hasCompleteContext: Bool { exposesContext }
    public var cursor: Int { selection.location }
    public init(text: String = "", cursor: Int? = nil, selection: NSRange? = nil) {
        self.text = text
        self.selection = selection ?? NSRange(location: cursor ?? text.utf16.count, length: 0)
    }
    public var before: String? { exposesContext ? (text as NSString).substring(to: selection.location) : nil }
    public var after: String? { exposesContext ? (text as NSString).substring(from: NSMaxRange(selection)) : nil }
    public func contextBeforeInput(maximumCharacters: Int) -> String? {
        guard exposesContext, let range = Range(selection, in: text),
              range.lowerBound.samePosition(in: text) != nil, range.upperBound.samePosition(in: text) != nil else { return nil }
        let start = text.index(range.lowerBound, offsetBy: -max(0, maximumCharacters), limitedBy: text.startIndex) ?? text.startIndex
        return String(text[start..<range.lowerBound])
    }
    public func contextAfterInput(maximumCharacters: Int) -> String? {
        guard exposesContext, let range = Range(selection, in: text),
              range.lowerBound.samePosition(in: text) != nil, range.upperBound.samePosition(in: text) != nil else { return nil }
        let end = text.index(range.upperBound, offsetBy: max(0, maximumCharacters), limitedBy: text.endIndex) ?? text.endIndex
        return String(text[range.upperBound..<end])
    }
    public var selectedText: String? {
        selection.length > 0 ? (text as NSString).substring(with: selection) : nil
    }
    public func insert(_ value: String) {
        text = (text as NSString).replacingCharacters(in: selection, with: value)
        selection = NSRange(location: selection.location + value.utf16.count, length: 0)
    }
    public func deleteBackward() {
        if selection.length > 0 { insert(""); return }
        guard selection.location > 0 else { return }
        let prefix = (text as NSString).substring(to: selection.location)
        guard let last = prefix.last else { return }
        selection = NSRange(location: selection.location - String(last).utf16.count, length: String(last).utf16.count)
        insert("")
    }
    public func move(by offset: Int) {
        let proposed = min(max(selection.location + offset, 0), text.utf16.count)
        // Keep the cursor at a composed-character boundary.
        let source = text as NSString
        let position = proposed < source.length ? source.rangeOfComposedCharacterSequence(at: proposed).location : proposed
        selection = NSRange(location: position, length: 0)
    }
    public func deleteSurroundingText(before prefix: String, after suffix: String) -> Bool {
        guard selection.length == 0, before?.hasSuffix(prefix) == true,
              after?.hasPrefix(suffix) == true, !prefix.isEmpty || !suffix.isEmpty else { return false }
        selection = NSRange(location: selection.location - prefix.utf16.count,
                            length: prefix.utf16.count + suffix.utf16.count)
        insert("")
        return true
    }
    public func replaceTextBeforeCursor(_ expected: String, with replacement: String) -> Bool {
        guard selection.length == 0, !expected.isEmpty,
              contextBeforeInput(maximumCharacters: expected.count)?.hasSuffix(expected) == true else { return false }
        selection = NSRange(location: selection.location - expected.utf16.count, length: expected.utf16.count)
        insert(replacement)
        return true
    }
}
