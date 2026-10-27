import UIKit
import KeyboardCore

/// A draft replaces the host target explicitly. No host context is consulted
/// while a local document is active, including through delayed menu actions.
@MainActor
final class KeyboardDocumentRouter: TextDocument {
    private let host: any TextDocument
    var local: MemoryDocument?
    var localLimit = 4096
    var onLocalChange: (() -> Void)?
    var onLimit: (() -> Void)?
    init(host: any TextDocument) { self.host = host }
    private var target: any TextDocument { if let local { return local }; return host }
    var before: String? { target.before }
    var after: String? { target.after }
    var selectedText: String? { target.selectedText }
    var hasCompleteContext: Bool { target.hasCompleteContext }
    var allowsAutocorrection: Bool { local == nil && target.allowsAutocorrection }
    var autocorrectionContextIdentifier: UUID? { target.autocorrectionContextIdentifier }
    var capitalizesSentences: Bool { local == nil && host.capitalizesSentences }
    var returnKeyLabel: String? { local == nil ? host.returnKeyLabel : nil }
    func contextBeforeInput(maximumCharacters: Int) -> String? { target.contextBeforeInput(maximumCharacters: maximumCharacters) }
    func contextAfterInput(maximumCharacters: Int) -> String? { target.contextAfterInput(maximumCharacters: maximumCharacters) }
    func insert(_ text: String) {
        if let local, local.text.count - (local.selectedText?.count ?? 0) + text.count > localLimit { onLimit?(); return }
        target.insert(text); changed()
    }
    func deleteBackward() { target.deleteBackward(); changed() }
    func move(by offset: Int) { target.move(by: offset); changed() }
    func moveVertically(by lines: Int) -> Bool {
        let moved = target.moveVertically(by: lines); changed(); return moved
    }
    func deleteSurroundingText(before prefix: String, after suffix: String) -> Bool {
        let deleted = target.deleteSurroundingText(before: prefix, after: suffix); changed(); return deleted
    }
    func replaceTextBeforeCursor(_ expected: String, with replacement: String) -> Bool {
        if let local {
            guard !expected.isEmpty, local.selection.length == 0,
                  let before = local.before,
                  before.utf16.suffix(expected.utf16.count).elementsEqual(expected.utf16) else { return false }
            let range = NSRange(location: local.cursor - expected.utf16.count, length: expected.utf16.count)
            guard range.location >= 0,
                  local.text.indices.contains(String.Index(utf16Offset: range.location, in: local.text)) else { return false }
            if (local.text as NSString).replacingCharacters(in: range, with: replacement).count > localLimit { onLimit?(); return false }
        }
        let replaced = target.replaceTextBeforeCursor(expected, with: replacement); changed(); return replaced
    }
    private func changed() { if local != nil { onLocalChange?() } }
}

@MainActor
final class KeyboardSnippetDraft {
    let id: UUID
    let name: MemoryDocument
    let text: MemoryDocument
    var editingName = true
    init(snippet: CodeSnippet?) {
        id = snippet?.id ?? UUID()
        name = MemoryDocument(text: snippet?.name ?? "")
        text = MemoryDocument(text: snippet?.text ?? "")
    }
    var document: MemoryDocument { editingName ? name : text }
    var limit: Int { editingName ? 80 : 4096 }
    var snippet: CodeSnippet? {
        let title = name.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title.count <= 80, !text.text.isEmpty, text.text.count <= 4096 else { return nil }
        return CodeSnippet(id: id, name: title, text: text.text)
    }
}

/// This is a read-only display, never a first responder. The existing key grid
/// edits the draft buffer directly, so another keyboard is never invoked.
@MainActor
private final class SnippetDraftDisplay: UITextView {
    override var canBecomeFirstResponder: Bool { false }
}

@MainActor
final class SnippetDraftPanel: UIView {
    var onCancel: (() -> Void)?
    var onSave: (() -> Void)?
    var onField: ((Bool) -> Void)?
    var onClear: (() -> Void)?
    private let field = UISegmentedControl(items: ["Name", "Text"])
    private let save = UIButton(type: .system)
    private let display = SnippetDraftDisplay()
    var preferredHeight: CGFloat { traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? 168 : 112 }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .secondarySystemGroupedBackground
        accessibilityIdentifier = "snippet.editor"
        let cancel = button(symbol: "xmark", label: "Cancel snippet", identifier: "snippet.cancel") { [weak self] in self?.onCancel?() }
        let clear = button(symbol: "eraser", label: "Clear current snippet field", identifier: "snippet.clear") { [weak self] in self?.onClear?() }
        save.setImage(UIImage(systemName: "checkmark"), for: .normal)
        save.accessibilityLabel = "Save snippet"
        save.accessibilityIdentifier = "snippet.save"
        save.addAction(UIAction { [weak self] _ in self?.onSave?() }, for: .touchUpInside)
        field.selectedSegmentIndex = 0
        field.accessibilityIdentifier = "snippet.field"
        field.addAction(UIAction { [weak self] _ in self?.onField?(self?.field.selectedSegmentIndex == 0) }, for: .valueChanged)
        let tools = UIStackView(arrangedSubviews: [cancel, field, clear, save])
        tools.axis = .horizontal; tools.spacing = 8; tools.alignment = .fill
        for control in [cancel, clear, save] { control.widthAnchor.constraint(equalToConstant: 44).isActive = true }
        display.isEditable = false; display.isSelectable = false
        display.backgroundColor = .tertiarySystemGroupedBackground
        display.layer.cornerRadius = 7
        display.accessibilityIdentifier = "snippet.draftValue"
        display.isAccessibilityElement = true
        display.accessibilityHint = "Type with the keys below. Changes stay in this draft until you save."
        let stack = UIStackView(arrangedSubviews: [tools, display])
        stack.axis = .vertical; stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            tools.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private func button(symbol: String, label: String, identifier: String, action: @escaping @MainActor () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: symbol), for: .normal)
        button.accessibilityLabel = label; button.accessibilityIdentifier = identifier
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }
    func update(_ draft: KeyboardSnippetDraft) {
        field.selectedSegmentIndex = draft.editingName ? 0 : 1
        let buffer = draft.document
        let weight: UIFont.Weight = traitCollection.legibilityWeight == .bold ? .semibold : .regular
        let font = UIFontMetrics(forTextStyle: .body).scaledFont(for: .monospacedSystemFont(ofSize: 16, weight: weight), compatibleWith: traitCollection)
        let content = NSMutableAttributedString(string: buffer.text, attributes: [.font: font, .foregroundColor: UIColor.label])
        content.insert(NSAttributedString(string: "│", attributes: [.font: font, .foregroundColor: tintColor ?? UIColor.label]), at: buffer.cursor)
        display.attributedText = content
        display.accessibilityLabel = draft.editingName ? "Snippet name draft" : "Snippet text draft"
        display.accessibilityValue = buffer.text.isEmpty ? "Empty" : buffer.text
        display.scrollRangeToVisible(NSRange(location: buffer.cursor, length: 1))
        save.isEnabled = draft.snippet != nil
    }
}
