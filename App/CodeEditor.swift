import SwiftUI
import UIKit
import KeyboardCore

/// Token colors remain readable as body text; the brighter system orange and
/// green are intended for larger interface accents in light appearance.
@MainActor
enum EditorSyntaxPalette {
    static let keyword = color(light: 0x71358C, dark: 0xD8AEFF, highLight: 0x4A0068, highDark: 0xEDDAFF)
    static let number = color(light: 0x975100, dark: 0xFFC66D, highLight: 0x713500, highDark: 0xFFE0AC)
    static let string = color(light: 0x216B35, dark: 0x9EDCAB, highLight: 0x07451A, highDark: 0xC1FFD0)
    static let comment = color(light: 0x5C6066, dark: 0xB6BDC7, highLight: 0x33363A, highDark: 0xDDE3EB)

    private static func color(light: UInt32, dark: UInt32, highLight: UInt32, highDark: UInt32) -> UIColor {
        UIColor { traits in
            let highContrast = traits.accessibilityContrast == .high
            let value = traits.userInterfaceStyle == .dark
                ? (highContrast ? highDark : dark) : (highContrast ? highLight : light)
            return UIColor(red: CGFloat((value >> 16) & 255) / 255,
                           green: CGFloat((value >> 8) & 255) / 255,
                           blue: CGFloat(value & 255) / 255, alpha: 1)
        }
    }
}

/// These patterns depend on the language, never on the document being edited.
/// Reuse both the compiled expressions and their small rule lists while typing.
@MainActor
private enum EditorSyntaxRules {
    struct Rule {
        let expression: NSRegularExpression
        let color: UIColor
    }
    private static var cache: [CodeLanguage: [Rule]] = [:]

    static func rules(for language: CodeLanguage) -> [Rule] {
        if let rules = cache[language] { return rules }
        let patterns: [(String, UIColor)] = [
            ("\\b(" + language.keywords.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|") + ")\\b", EditorSyntaxPalette.keyword),
            (#"\b[0-9]+(?:\.[0-9]+)?\b"#, EditorSyntaxPalette.number),
            (#""(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'|`[^`]*`"#, EditorSyntaxPalette.string),
            (language == .python || language == .shell ? "#[^\\n]*" : "//[^\\n]*", EditorSyntaxPalette.comment)
        ]
        let rules = patterns.compactMap { pattern, color -> Rule? in
            guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }
            return Rule(expression: expression, color: color)
        }
        cache[language] = rules
        return rules
    }
}

/// Shared by the cursor label and gutter. Character edits invalidate the index;
/// selection changes and drawing reuse it without rescanning earlier lines.
@MainActor
private final class EditorLineIndex {
    private var starts = [0]
    private var isDirty = true
    private(set) var revision: UInt = 0

    func invalidate() {
        isDirty = true
        revision &+= 1
    }

    func line(at location: Int, in storage: NSTextStorage) -> Int {
        if isDirty {
            starts = [0]
            for (offset, unit) in storage.string.utf16.enumerated() where unit == 10 {
                starts.append(offset + 1)
            }
            isDirty = false
        }
        let location = min(max(0, location), storage.length)
        var lower = 0, upper = starts.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if starts[middle] <= location { lower = middle + 1 }
            else { upper = middle }
        }
        return lower - 1
    }

    func cursorLabel(at location: Int, in storage: NSTextStorage) -> String {
        let location = min(max(0, location), storage.length)
        let line = line(at: location, in: storage)
        let range = NSRange(location: starts[line], length: location - starts[line])
        // Keep the displayed column in user-perceived characters, including
        // emoji and combining marks, while TextKit offsets remain UTF-16.
        let column = (storage.string as NSString).substring(with: range).count + 1
        return "Ln \(line + 1), Col \(column)"
    }
}

@MainActor @Observable
final class EditorSession {
    weak var host: EditorHostView?
    var isFocused = false
    var cursorLabel = "Ln 1, Col 1"
    func insert(_ text: String) { host?.document.insert(text) }
    func focus() { host?.textView.becomeFirstResponder() }
    func dismiss() { host?.textView.resignFirstResponder() }
    func useCustomKeyboard(_ enabled: Bool) {
        host?.setCustomKeyboard(enabled)
    }
    func format(language: CodeLanguage, indentation: Indentation) throws {
        guard let host else { return }
        let view = host.textView
        let selected = view.selectedRange
        let source = host.document.selectedText ?? view.text!
        let formatted = try CodeFormatter.format(source, language: language, indentation: indentation)
        if selected.length == 0 { view.selectedRange = NSRange(location: 0, length: view.text.utf16.count) }
        host.document.insert(formatted)
    }
}

@MainActor
private final class EditorKeyboardInputView: UIInputView {
    var requestedHeight: CGFloat = 350 {
        didSet { invalidateIntrinsicContentSize() }
    }
    override var intrinsicContentSize: CGSize { CGSize(width: UIView.noIntrinsicMetric, height: requestedHeight) }
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: size.width, height: requestedHeight)
    }
    override func systemLayoutSizeFitting(_ targetSize: CGSize) -> CGSize {
        CGSize(width: targetSize.width, height: requestedHeight)
    }
    override func systemLayoutSizeFitting(_ targetSize: CGSize, withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority, verticalFittingPriority: UILayoutPriority) -> CGSize {
        CGSize(width: targetSize.width, height: requestedHeight)
    }
}

@MainActor
final class EditorHostView: UIView, UITextViewDelegate, @preconcurrency NSTextStorageDelegate {
    let textView = UITextView(usingTextLayoutManager: false)
    private let gutter = LineNumberView()
    private(set) var document: TextViewDocument!
    private(set) var keyboard: CodingKeyboardView!
    var onChange: ((String) -> Void)?
    var onCursor: ((String) -> Void)? { didSet { lastCursorLabel = nil } }
    var onFocus: ((Bool) -> Void)?
    var language: CodeLanguage = .swift
    private var highlighting = false
    private var lastSavedText: String?
    private let lineIndex = EditorLineIndex()
    private var lastCursorLabel: String?
    private var lastSelection: NSRange?
    private var lastSelectionRevision: UInt?
    private var keyboardHeight: NSLayoutConstraint?
    private let keyboardInputView = EditorKeyboardInputView(frame: .zero, inputViewStyle: .keyboard)
    private var editorFont: UIFont {
        UIFontMetrics(forTextStyle: .body).scaledFont(
            for: .monospacedSystemFont(ofSize: 15, weight: traitCollection.legibilityWeight == .bold ? .semibold : .regular),
            compatibleWith: traitCollection
        )
    }

    init(preferences: PreferencesStore, openSettings: @escaping () -> Void) {
        super.init(frame: .zero)
        backgroundColor = .secondarySystemGroupedBackground
        gutter.isOpaque = false
        gutter.backgroundColor = .clear
        textView.backgroundColor = .clear
        textView.font = editorFont
        textView.adjustsFontForContentSizeCategory = true
        textView.textColor = .label
        textView.tintColor = ScriptTheme.accent
        textView.textContainerInset = UIEdgeInsets(top: 18, left: 4, bottom: 120, right: 16)
        textView.textContainer.lineFragmentPadding = 0
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.smartInsertDeleteType = .no
        textView.spellCheckingType = .no
        textView.writingToolsBehavior = .complete
        textView.keyboardDismissMode = .interactive
        textView.alwaysBounceVertical = true
        textView.accessibilityIdentifier = "playground.editor"
        textView.accessibilityLabel = "Code editor"
        textView.delegate = self
        textView.textStorage.delegate = self
        addSubview(gutter); addSubview(textView)
        document = TextViewDocument(textView)
        document.onChange = { [weak self] in self?.changed() }
        document.onSelectionChange = { [weak self] in self?.selectionChanged() }
        keyboard = CodingKeyboardView(document: document, preferences: preferences)
        keyboard.isPreview = true
        keyboardInputView.allowsSelfSizing = true
        keyboardInputView.autoresizingMask = [.flexibleWidth]
        keyboardInputView.requestedHeight = keyboard.desiredHeight
        keyboardInputView.frame.size.height = keyboard.desiredHeight
        keyboard.translatesAutoresizingMaskIntoConstraints = false
        keyboardInputView.addSubview(keyboard)
        NSLayoutConstraint.activate([
            keyboard.leadingAnchor.constraint(equalTo: keyboardInputView.leadingAnchor),
            keyboard.trailingAnchor.constraint(equalTo: keyboardInputView.trailingAnchor),
            keyboard.topAnchor.constraint(equalTo: keyboardInputView.topAnchor),
            keyboard.bottomAnchor.constraint(equalTo: keyboardInputView.bottomAnchor)
        ])
        let height = keyboardInputView.heightAnchor.constraint(equalToConstant: keyboard.desiredHeight)
        height.priority = .required
        height.isActive = true
        keyboardHeight = height
        keyboard.onOpenSettings = { [weak self] in self?.textView.resignFirstResponder(); openSettings() }
        keyboard.onDismiss = { [weak self] in self?.textView.resignFirstResponder() }
        keyboard.onNextKeyboard = { [weak self] in self?.setCustomKeyboard(false) }
        keyboard.onHeightChange = { [weak self] height in
            guard let self, self.keyboardHeight?.constant != height else { return }
            self.keyboardHeight?.constant = height
            self.keyboardInputView.requestedHeight = height
            self.keyboardInputView.frame.size.height = height
            self.keyboardInputView.invalidateIntrinsicContentSize()
            self.keyboardInputView.setNeedsLayout()
            // UIKit caches the input window's fitting size across rotation.
            // Refresh after the current layout transaction, only on changes.
            Task { @MainActor [weak self] in
                guard let self, self.textView.isFirstResponder else { return }
                self.textView.reloadInputViews()
            }
        }
        textView.inputView = keyboardInputView
        gutter.textView = textView
        gutter.lineIndex = lineIndex
        registerForTraitChanges([UITraitUserInterfaceStyle.self, UITraitPreferredContentSizeCategory.self,
                                 UITraitLegibilityWeight.self, UITraitAccessibilityContrast.self]) { (view: EditorHostView, previous: UITraitCollection) in
            if previous.preferredContentSizeCategory != view.traitCollection.preferredContentSizeCategory
                || previous.legibilityWeight != view.traitCollection.legibilityWeight {
                view.updateEditorFont()
            }
            view.highlight()
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews()
        // The keyboard is hosted in a separate input window. The editor's
        // window is the stable, oriented app area, including resized iPad scenes.
        keyboard.availableHostSize = window?.bounds.size
        gutter.frame = CGRect(x: 0, y: 0, width: 42, height: bounds.height)
        textView.frame = CGRect(x: 42, y: 0, width: max(0, bounds.width - 42), height: bounds.height)
        gutter.setNeedsDisplay()
    }
    func setCustomKeyboard(_ enabled: Bool) {
        textView.inputView = enabled ? keyboardInputView : nil
        textView.reloadInputViews()
    }
    func synchronize(text: String, language: CodeLanguage) {
        let languageChanged = self.language != language
        self.language = language
        if textView.text != text {
            textView.text = text
            textView.selectedRange = NSRange(location: text.utf16.count, length: 0)
            highlight()
            cursorChanged()
            keyboard.refreshContext()
        } else if languageChanged {
            highlight()
        }
    }
    func textViewDidChange(_ textView: UITextView) { changed() }
    func textViewDidBeginEditing(_ textView: UITextView) {
        // Dismissal releases suggestions. Refocusing can keep the same text,
        // selection and preferences, so restore context independently of them.
        keyboard.refreshContext()
        onFocus?(true)
    }
    func textViewDidEndEditing(_ textView: UITextView) { onFocus?(false) }
    func textViewDidChangeSelection(_ textView: UITextView) { selectionChanged() }
    func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorage.EditActions, range editedRange: NSRange, changeInLength delta: Int) {
        if editedMask.contains(.editedCharacters) { lineIndex.invalidate() }
    }
    private func selectionChanged() {
        guard !highlighting else { return }
        let selection = textView.selectedRange
        guard selection != lastSelection || lineIndex.revision != lastSelectionRevision else { return }
        if selection != lastSelection, lineIndex.revision == lastSelectionRevision {
            keyboard.engine.invalidateAutocorrection()
        }
        lastSelection = selection
        lastSelectionRevision = lineIndex.revision
        cursorChanged()
        keyboard.refreshContext()
    }
    func scrollViewDidScroll(_ scrollView: UIScrollView) { gutter.setNeedsDisplay() }
    func changed() {
        guard !highlighting else { return }
        if lastSavedText != textView.text {
            lastSavedText = textView.text
            highlight(); onChange?(textView.text)
        }
        selectionChanged()
    }
    func cursorChanged() {
        let label = lineIndex.cursorLabel(at: textView.selectedRange.location, in: textView.textStorage)
        if label != lastCursorLabel {
            lastCursorLabel = label
            onCursor?(label)
        }
        gutter.setNeedsDisplay()
    }
    private func updateEditorFont() {
        let font = editorFont
        textView.font = font
        textView.textStorage.addAttribute(.font, value: font, range: NSRange(location: 0, length: textView.text.utf16.count))
        textView.typingAttributes[.font] = font
        gutter.setNeedsDisplay()
    }
    func highlight() {
        let storage = textView.textStorage
        guard !highlighting, storage.length < 120_000 else { return }
        highlighting = true
        let source = storage.string
        let range = NSRange(location: 0, length: storage.length)
        let selection = textView.selectedRange
        let font = editorFont
        storage.beginEditing()
        storage.setAttributes([.font: font, .foregroundColor: UIColor.label], range: range)
        for rule in EditorSyntaxRules.rules(for: language) {
            rule.expression.enumerateMatches(in: source, range: range) { match, _, _ in
                if let match { storage.addAttribute(.foregroundColor, value: rule.color, range: match.range) }
            }
        }
        storage.endEditing()
        textView.selectedRange = selection
        textView.typingAttributes = [.font: font, .foregroundColor: UIColor.label]
        highlighting = false
        gutter.setNeedsDisplay()
    }
}

@MainActor
private final class LineNumberView: UIView {
    weak var textView: UITextView?
    var lineIndex: EditorLineIndex?
    private let attributes: [NSAttributedString.Key: Any] = {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right
        return [.font: UIFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                .foregroundColor: UIColor.tertiaryLabel, .paragraphStyle: paragraph]
    }()
    override func draw(_ rect: CGRect) {
        guard let view = textView, let lineIndex else { return }
        let layout = view.layoutManager
        let visible = CGRect(origin: view.contentOffset, size: view.bounds.size)
        let glyphs = layout.glyphRange(forBoundingRect: visible, in: view.textContainer)
        let source = view.text as NSString
        let attributes = attributes
        layout.enumerateLineFragments(forGlyphRange: glyphs) { _, _, _, range, _ in
            let location = layout.characterIndexForGlyph(at: range.location)
            // Only number the first visual line of each paragraph.
            guard location == 0 || source.character(at: location - 1) == 10 else { return }
            let line = lineIndex.line(at: location, in: view.textStorage) + 1
            let y = layout.lineFragmentRect(forGlyphAt: range.location, effectiveRange: nil).minY + view.textContainerInset.top - view.contentOffset.y + 3
            (String(line) as NSString).draw(in: CGRect(x: 0, y: y, width: 29, height: 20), withAttributes: attributes)
        }
    }
}

struct CodeEditor: UIViewRepresentable {
    @Binding var text: String
    let preferences: PreferencesStore
    let session: EditorSession
    var openSettings: () -> Void

    func makeUIView(context: Context) -> EditorHostView {
        let host = EditorHostView(preferences: preferences, openSettings: openSettings)
        session.host = host
        host.language = preferences.settings.language
        host.textView.text = text
        host.textView.selectedRange = NSRange(location: text.utf16.count, length: 0)
        host.onChange = { text = $0 }
        host.onCursor = { session.cursorLabel = $0 }
        host.onFocus = { session.isFocused = $0 }
        host.highlight(); host.cursorChanged()
        return host
    }
    func updateUIView(_ host: EditorHostView, context: Context) {
        host.keyboard.applySettings()
        host.synchronize(text: text, language: preferences.settings.language)
    }
}
