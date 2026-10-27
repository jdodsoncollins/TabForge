import UIKit
import KeyboardCore

enum ScriptTheme {
    static let accent = UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.79, green: 0.94, blue: 0.48, alpha: 1)
        : UIColor(red: 0.26, green: 0.39, blue: 0.07, alpha: 1) }
}

private enum KeyAction: Equatable {
    case text(String), shift, delete, tab, space, enter, mode, symbols, globe, indent, outdent
    case navigation(NavigationKey)
    case line
    case function, modifier(KeyboardModifiers), settings, symbolPage
}

@MainActor
private final class KeyButton: UIButton {
    let action: KeyAction
    let weight: CGFloat
    var touchFrame = CGRect.zero
    let legend = UILabel()
    let hint = UILabel()
    var baseColor: UIColor
    let highlightColor: UIColor
    override var isHighlighted: Bool { didSet { backgroundColor = isHighlighted ? highlightColor : baseColor } }

    init(title: String, symbol: String? = nil, hint: String? = nil, action: KeyAction, weight: CGFloat = 1, utility: Bool = false, palette: KeyboardPalette) {
        self.action = action; self.weight = weight
        baseColor = utility ? palette.utility : palette.key
        highlightColor = palette.accent.withAlphaComponent(0.35)
        super.init(frame: .zero)
        layer.cornerRadius = 7
        layer.cornerCurve = .continuous
        backgroundColor = baseColor
        // Each key tracks one finger; separate keys never exclude one another.
        isExclusiveTouch = false
        isMultipleTouchEnabled = false
        legend.textAlignment = .center
        legend.font = .monospacedSystemFont(ofSize: 21, weight: .regular)
        legend.adjustsFontSizeToFitWidth = true
        legend.minimumScaleFactor = 0.55
        legend.textColor = palette.text
        legend.text = title
        legend.isUserInteractionEnabled = false
        addSubview(legend)
        if let symbol {
            legend.text = nil
            setImage(UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)), for: .normal)
            tintColor = palette.text
        }
        self.hint.text = hint
        self.hint.font = .monospacedSystemFont(ofSize: 9, weight: .medium)
        self.hint.textColor = palette.secondary
        self.hint.textAlignment = .right
        addSubview(self.hint)
        accessibilityLabel = title
        accessibilityIdentifier = "key.\(title)"
        isAccessibilityElement = true
        accessibilityTraits.insert(.keyboardKey)
        legend.isAccessibilityElement = false
        self.hint.isAccessibilityElement = false
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard let superview, !touchFrame.isEmpty else { return super.point(inside: point, with: event) }
        return touchFrame.contains(convert(point, to: superview))
    }
    override var accessibilityFrame: CGRect {
        get {
            guard let superview, !touchFrame.isEmpty else { return super.accessibilityFrame }
            return UIAccessibility.convertToScreenCoordinates(touchFrame, in: superview)
        }
        set { super.accessibilityFrame = newValue }
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        legend.frame = bounds.insetBy(dx: 1, dy: 2)
        hint.frame = CGRect(x: 2, y: 2, width: bounds.width - 6, height: 12)
    }
}

/// Shared by the real keyboard extension and the app's editable playground.
@MainActor
final class CodingKeyboardView: UIView, UIGestureRecognizerDelegate {
    let preferences: PreferencesStore
    let engine: EditingEngine
    private let documentRouter: KeyboardDocumentRouter
    private var snippetDraft: KeyboardSnippetDraft?
    private var snippetPanel: SnippetDraftPanel?
    private var pendingSnippetClose: Bool?
    private var pendingSnippetField: Bool?
    private let cancelledSnippetReleases = NSHashTable<UIButton>.weakObjects()
    var isEditingSnippet: Bool { snippetDraft != nil }
    var onSnippetEditingChanged: ((Bool) -> Void)?
    var isPreview = false { didSet { if oldValue != isPreview { updateMenus() } } }
    var onNextKeyboard: (() -> Void)?
    var onInputModeEvent: ((UIView, UIEvent) -> Void)?
    var onOpenSettings: (() -> Void)?
    var onDismiss: (() -> Void)?
    var onPrepareAutocorrection: (() -> Void)?
    /// The extension must protect the user's names and shortcuts before making
    /// spelling guesses. Native hosts do not request an extension lexicon.
    var requiresSupplementaryLexicon = false
    var onHeightChange: ((CGFloat) -> Void)?
    /// Stable host geometry, supplied by previews. The extension uses its scene,
    /// never its own requested height, to avoid a height feedback loop.
    var availableHostSize: CGSize? { didSet { if oldValue != availableHostSize { setNeedsLayout() } } }
    private(set) var isCompactHeight = false
    private var prefersCompactHeight = false
    private var functionLayer = false
    var needsGlobe = true { didSet { if oldValue != needsGlobe { rebuild() } } }
    private var rows: [[KeyButton]] = []
    private let toolbar = UIView()
    private let gearButton = UIButton(type: .system)
    private let escapeButton = UIButton(type: .system)
    private var quickSettingsItems: [UIMenuElement] = []
    private let deleteLineButton = UIButton(type: .system)
    private var navigationButtons: [UIButton] = []
    private var modifierButtons: [(UIButton, KeyboardModifiers)] = []
    private var displayedSuggestions: [String] = []
    private var displayedSwipeGeneration: UInt64?
    private let statusLabel = UILabel()
    private var layout = KeyboardLayout.compact
    private var tabletopHeight: CGFloat?
    private var uppercase = false
    private var capsLock = false
    private var numbers = false
    private var moreSymbols = false
    /// The Compact symbol row's second page of operators and punctuation.
    private var symbolPage = false
    /// Shift was turned on for a sentence start rather than by the user.
    private var autoShifted = false
    private var lastSpaceTime = Date.distantPast
    private var displayedReturnLabel: String?
    private var extraToolbarButtons: [ToolbarKey: UIButton] = [:]
    @MainActor private struct AlternatesPopup {
        weak var key: KeyButton?
        let options: [String]
        let view: UIView
        let labels: [UILabel]
        var selected = 0
    }
    private var alternatesPopup: AlternatesPopup?
    private var alternatesTask: Task<Void, Never>?
    private var alternatesKey: ObjectIdentifier?
    private var latchedModifiers: KeyboardModifiers = []
    private var heldModifiers: KeyboardModifiers = []
    private var usedHeldModifiers: KeyboardModifiers = []
    private var modifiers: KeyboardModifiers { latchedModifiers.union(heldModifiers) }
    private struct KeyPress {
        let modifiers: KeyboardModifiers
        let uppercase: Bool
    }
    private var activeKeyPresses: Set<ObjectIdentifier> = []
    private var keyPresses: [ObjectIdentifier: KeyPress] = [:]
    private var ignoredModifierReleases: KeyboardModifiers = []
    private var needsKeyRebuild = false
    private var shiftHeld = false
    private var shiftUsed = false
    private var lastShiftTap = Date.distantPast
    private var lastSettings: KeyboardSettings?
    private var deleteTask: Task<Void, Never>?
    private var statusTask: Task<Void, Never>?
    private var previewLabel: UILabel?
    private var swipeTrace: [SwipePoint] = []
    private var swipePath = UIBezierPath()
    private var swipeDecoder: SwipeDecoder?
    @MainActor private struct SwipeAnchor {
        let identifier: UUID?
        let before: String?
        let after: String?
        init(_ document: any TextDocument) {
            identifier = document.autocorrectionContextIdentifier
            before = document.contextBeforeInput(maximumCharacters: 32)
            after = document.contextAfterInput(maximumCharacters: 32)
        }
        func matches(_ document: any TextDocument) -> Bool {
            identifier == document.autocorrectionContextIdentifier &&
                before == document.contextBeforeInput(maximumCharacters: 32) &&
                after == document.contextAfterInput(maximumCharacters: 32) && document.selectedText == nil
        }
    }
    private var swipeAnchor: SwipeAnchor?
    private var swipeBounds: CGRect?
    private var swipeCenters: [Character: SwipePoint]?
    private var swipeGeneration: UInt64 = 0
    private var swipeReplacementAnchor: SwipeAnchor?
    private var swipeWords: [String] = []
    private var lastSwipeWord: String?
    private let swipeLayer = CAShapeLayer()
    private var scrubTranslation: CGFloat = 0
    private var isScrubbing = false
    private var palette: KeyboardPalette = .resolve(.standard)
    private var feedback: (generator: UIImpactFeedbackGenerator, strength: HapticStrength)?
    private var proseCorrector: ProseAutocorrector?
    private var correctionDocument: UUID?
    private var supplementaryProtectedWords: Set<String> = []
    private var hasSupplementaryLexicon = false

    init(document: any TextDocument, preferences: PreferencesStore) {
        self.preferences = preferences
        let router = KeyboardDocumentRouter(host: document)
        self.documentRouter = router
        self.engine = EditingEngine(document: router, settings: preferences.settings)
        // The extension controller / text-input host owns the input-view shell.
        // A plain renderer also avoids creating UIKit input-service content for
        // every settings preview or layout demo.
        super.init(frame: CGRect(x: 0, y: 0, width: 390, height: 350))
        router.onLocalChange = { [weak self] in
            guard let self, let draft = self.snippetDraft else { return }
            self.snippetPanel?.update(draft)
        }
        router.onLimit = { [weak self] in self?.showStatus("Snippet names allow 80 characters; text allows 4,096") }
        engine.correctionProvider = { [weak self] word in
            guard let self else { return nil }
            guard !self.isEditingSnippet else { return nil }
            guard !self.requiresSupplementaryLexicon || self.hasSupplementaryLexicon else {
                // Loading is asynchronous; keep this word literal and retry
                // preparation after dismissal or memory-pressure cleanup.
                self.onPrepareAutocorrection?()
                return nil
            }
            let identifier = self.engine.document.autocorrectionContextIdentifier
            if self.proseCorrector == nil || self.correctionDocument != identifier {
                self.proseCorrector = ProseAutocorrector(protectedWords: self.supplementaryProtectedWords)
                self.correctionDocument = identifier
            }
            return self.proseCorrector?.correction(for: word)
        }
        accessibilityIdentifier = "keyboard.surface"
        accessibilityValue = layout.rawValue
        autoresizingMask = [.flexibleWidth]
        isMultipleTouchEnabled = true
        toolbar.isMultipleTouchEnabled = true
        backgroundColor = palette.background
        toolbar.accessibilityIdentifier = "keyboard.toolbar"
        addSubview(toolbar)
        gearButton.tintColor = .label
        gearButton.showsMenuAsPrimaryAction = true
        toolbar.addSubview(gearButton)
        gearButton.setImage(UIImage(systemName: "gearshape"), for: .normal)
        gearButton.accessibilityLabel = "Tools and settings"
        gearButton.accessibilityIdentifier = "keyboard.quickSettings"
        escapeButton.setTitle("Esc", for: .normal)
        escapeButton.titleLabel?.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        escapeButton.titleLabel?.adjustsFontSizeToFitWidth = true
        escapeButton.titleLabel?.minimumScaleFactor = 0.7
        escapeButton.accessibilityLabel = "Escape"
        escapeButton.accessibilityUserInputLabels = ["Esc", "Escape"]
        escapeButton.accessibilityIdentifier = "keyboard.escape"
        escapeButton.accessibilityTraits.insert(.keyboardKey)
        escapeButton.isExclusiveTouch = false
        escapeButton.addAction(UIAction { [weak self, weak escapeButton] _ in
            guard let self, let button = escapeButton else { return }; self.beginToolbarPress(button)
        }, for: .touchDown)
        escapeButton.addAction(UIAction { [weak self, weak escapeButton] _ in
            guard let self, let button = escapeButton else { return }; self.finishToolbarPress(button, action: .navigation(.escape))
        }, for: .touchUpInside)
        escapeButton.addAction(UIAction { [weak self, weak escapeButton] _ in
            guard let self, let button = escapeButton else { return }; self.finishToolbarPress(button, cancelled: true)
        }, for: [.touchCancel, .touchUpOutside])
        toolbar.addSubview(escapeButton)
        for key in ToolbarKey.allCases where key == .tab || key.text != nil {
            let button = UIButton(type: .system)
            let name = String(key.title.split(separator: " ").first ?? "")
            if let text = key.text {
                button.setTitle(text, for: .normal)
                button.titleLabel?.font = .monospacedSystemFont(ofSize: 18, weight: .medium)
                button.accessibilityUserInputLabels = [name, text]
            } else {
                button.setImage(UIImage(systemName: "arrow.right.to.line", withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)), for: .normal)
            }
            button.accessibilityLabel = name
            button.accessibilityIdentifier = "keyboard.toolbar.\(key.rawValue)"
            button.accessibilityTraits.insert(.keyboardKey)
            button.isExclusiveTouch = false
            let action: KeyAction = key.text.map { .text($0) } ?? .tab
            button.addAction(UIAction { [weak self, weak button] _ in
                guard let self, let button else { return }; self.beginToolbarPress(button)
            }, for: .touchDown)
            button.addAction(UIAction { [weak self, weak button] _ in
                guard let self, let button else { return }; self.finishToolbarPress(button, action: action)
            }, for: .touchUpInside)
            button.addAction(UIAction { [weak self, weak button] _ in
                guard let self, let button else { return }; self.finishToolbarPress(button, cancelled: true)
            }, for: [.touchCancel, .touchUpOutside])
            button.isHidden = true
            toolbar.addSubview(button); extraToolbarButtons[key] = button
        }
        deleteLineButton.tintColor = .label
        deleteLineButton.accessibilityIdentifier = "keyboard.deleteLine"
        deleteLineButton.isExclusiveTouch = false
        deleteLineButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }; self.beginToolbarPress(self.deleteLineButton)
        }, for: .touchDown)
        deleteLineButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }; self.finishToolbarPress(self.deleteLineButton, action: .line)
        }, for: .touchUpInside)
        deleteLineButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }; self.finishToolbarPress(self.deleteLineButton, cancelled: true)
        }, for: [.touchCancel, .touchUpOutside])
        toolbar.addSubview(deleteLineButton)
        for (key, symbol) in [(NavigationKey.left, "arrow.left"), (.down, "arrow.down"), (.up, "arrow.up"), (.right, "arrow.right")] {
            let button = UIButton(type: .system)
            button.setImage(UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)), for: .normal)
            button.accessibilityLabel = key.rawValue.capitalized + " arrow"
            button.accessibilityIdentifier = "keyboard.arrow.\(key.rawValue)"
            button.accessibilityTraits.insert(.keyboardKey)
            button.isExclusiveTouch = false
            button.addAction(UIAction { [weak self, weak button] _ in
                guard let self, let button else { return }; self.beginToolbarPress(button)
            }, for: .touchDown)
            button.addAction(UIAction { [weak self, weak button] _ in
                guard let self, let button else { return }; self.finishToolbarPress(button, action: .navigation(key))
            }, for: .touchUpInside)
            button.addAction(UIAction { [weak self, weak button] _ in
                guard let self, let button else { return }; self.finishToolbarPress(button, cancelled: true)
            }, for: [.touchCancel, .touchUpOutside])
            toolbar.addSubview(button); navigationButtons.append(button)
        }
        for (modifier, title, name) in [(KeyboardModifiers.control, "Ctrl", "Control"), (.option, "⌥", "Option"), (.command, "⌘", "Command")] {
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: title == "Ctrl" ? 12 : 22, weight: .medium)
            button.titleLabel?.adjustsFontSizeToFitWidth = true
            button.layer.cornerRadius = 6
            button.accessibilityLabel = name
            button.accessibilityIdentifier = "keyboard.modifier.\(name.lowercased())"
            button.isAccessibilityElement = true
            button.accessibilityTraits.insert([.button, .keyboardKey])
            button.accessibilityUserInputLabels = [title, name]
            button.titleLabel?.isAccessibilityElement = false
            button.accessibilityHint = "Tap for the next key, or hold while pressing other keys. Tap again to cancel. Support depends on the input profile and host app."
            button.isExclusiveTouch = false
            button.addAction(UIAction { [weak self, weak button] _ in
                guard let self, let button else { return }; self.beginToolbarPress(button, consumesModifiers: false); self.beginModifier(modifier)
            }, for: .touchDown)
            button.addAction(UIAction { [weak self, weak button] _ in
                guard let self, let button else { return }; self.finishToolbarPress(button, action: .modifier(modifier))
            }, for: .touchUpInside)
            button.addAction(UIAction { [weak self, weak button] _ in
                guard let self, let button else { return }; self.finishToolbarPress(button, action: .modifier(modifier), cancelled: true)
            }, for: [.touchCancel, .touchUpOutside])
            toolbar.addSubview(button); modifierButtons.append((button, modifier))
        }
        statusLabel.accessibilityIdentifier = "keyboard.status"
        statusLabel.isUserInteractionEnabled = false
        statusLabel.font = .systemFont(ofSize: 11, weight: .medium)
        statusLabel.numberOfLines = 2
        statusLabel.textAlignment = .center
        statusLabel.textColor = palette.accent
        statusLabel.backgroundColor = palette.background
        statusLabel.isHidden = true
        toolbar.addSubview(statusLabel)
        swipeLayer.strokeColor = palette.accent.resolvedColor(with: traitCollection).cgColor
        swipeLayer.lineWidth = 3
        swipeLayer.fillColor = UIColor.clear.cgColor
        swipeLayer.lineCap = .round
        swipeLayer.actions = ["path": NSNull(), "strokeColor": NSNull()]
        layer.addSublayer(swipeLayer)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        pan.delegate = self
        pan.maximumNumberOfTouches = 1
        pan.delaysTouchesBegan = false
        pan.delaysTouchesEnded = false
        addGestureRecognizer(pan)
        registerForTraitChanges([UITraitUserInterfaceStyle.self, UITraitLegibilityWeight.self, UITraitPreferredContentSizeCategory.self]) { (view: CodingKeyboardView, _: UITraitCollection) in
            view.swipeLayer.strokeColor = view.palette.accent.resolvedColor(with: view.traitCollection).cgColor
            view.updateKeyFonts()
            view.updateModifierButtons()
            if let draft = view.snippetDraft {
                view.snippetPanel?.update(draft); view.setNeedsLayout()
                view.onHeightChange?(view.desiredHeight)
            }
        }
        applySettings()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: desiredHeight)
    }
    var desiredHeight: CGFloat {
        // Keep the requested height independent from any temporary host clipping.
        tabletopHeight ?? ((prefersCompactHeight ? 4 * (44 + 4) : 44 + CGFloat(fullRowCount) * (preferences.settings.keySize.height + 6)) + 8 + safeAreaInsets.top + safeAreaInsets.bottom + snippetPanelHeight)
    }
    private var snippetPanelHeight: CGFloat { snippetPanel?.preferredHeight ?? 0 }
    private var fullRowCount: Int {
        5 + (layout == .tabletop ? 1 : 0) + (showsNumberRow ? 1 : 0)
    }
    /// Host height in points, when the scene reports one.
    private var hostHeight: CGFloat?
    /// The automatic number row needs a tall host as well as a wide one. A
    /// wide but short screen, such as a closed Duo, keeps the q–p digits.
    private var showsNumberRow: Bool {
        guard !numbers else { return false }
        if preferences.settings.showNumberRow { return true }
        return layout != .compact && (hostHeight ?? .infinity) >= 760
    }
    func applySettings() {
        // SwiftUI updates the editor for cursor and focus changes as well as
        // preferences. Avoid touching every control or rescanning suggestions
        // when no preference changed; text/selection events refresh context.
        guard preferences.settings != lastSettings else { return }
        invalidateSwipeContext()
        if lastSettings?.language != preferences.settings.language ||
            !preferences.settings.swipeTyping || !preferences.settings.smartEditingEnabled {
            swipeDecoder = nil
        }
        engine.invalidateAutocorrection()
        if !preferences.settings.autocorrectProse {
            proseCorrector = nil; correctionDocument = nil; supplementaryProtectedWords = []
            hasSupplementaryLexicon = false
        } else if lastSettings?.autocorrectProse != true && !isEditingSnippet { onPrepareAutocorrection?() }
        engine.settings = isEditingSnippet ? snippetInputSettings : preferences.settings
        if lastSettings?.theme != preferences.settings.theme { palette = .resolve(preferences.settings.theme) }
        switch preferences.settings.theme.usesDarkPalette ? .dark : preferences.settings.appearance {
        case .system: overrideUserInterfaceStyle = .unspecified
        case .light: overrideUserInterfaceStyle = .light
        case .dark: overrideUserInterfaceStyle = .dark
        }
        backgroundColor = palette.background
        for button in allToolbarButtons { button.tintColor = palette.text }
        statusLabel.textColor = palette.accent
        statusLabel.backgroundColor = palette.background
        swipeLayer.strokeColor = palette.accent.resolvedColor(with: traitCollection).cgColor
        if lastSettings?.compatibility != preferences.settings.compatibility { clearModifiers() }
        updateModifierButtons()
        if preferences.settings != lastSettings {
            lastSettings = preferences.settings
            rebuild()
            updateMenus()
        }
        refreshContext()
    }

    private func makeKey(_ title: String, symbol: String? = nil, hint: String? = nil, _ action: KeyAction, weight: CGFloat = 1, utility: Bool = false) -> KeyButton {
        let key = KeyButton(title: title, symbol: symbol, hint: preferences.settings.showKeyHints ? hint : nil, action: action, weight: weight, utility: utility, palette: palette)
        if case .text(let value) = action, "{}[]<>()".contains(value) { key.legend.textColor = palette.accent }
        let names = ["{": "Open brace", "}": "Close brace", "[": "Open square bracket", "]": "Close square bracket", "<": "Less than", ">": "Greater than", "(": "Open parenthesis", ")": "Close parenthesis"]
        key.accessibilityLabel = names[title] ?? title
        key.accessibilityUserInputLabels = [title, key.accessibilityLabel ?? title]
        if action == .settings {
            key.showsMenuAsPrimaryAction = true
            key.menu = gearButton.menu
            key.accessibilityLabel = "Tools and settings"
            key.accessibilityUserInputLabels = [title, "Tools and settings"]
        }
        if case .modifier(let modifier) = action {
            key.accessibilityLabel = modifier == .control ? "Control" : title
            key.accessibilityUserInputLabels = [title, key.accessibilityLabel ?? title]
            key.accessibilityHint = "Tap for the next key, or hold while pressing other keys. Tap again to cancel."
        }
        if case .text(let value) = action, !utility {
            let options = KeyAlternates.alternates(for: value)
            if !options.isEmpty {
                key.accessibilityCustomActions = options.map { option in
                    UIAccessibilityCustomAction(name: "Type " + option) { [weak self] _ in
                        self?.perform(.text(option), capturedModifiers: [], capturedUppercase: false); return self != nil
                    }
                }
            }
        }
        if action == .symbolPage {
            key.accessibilityLabel = symbolPage ? "Brackets" : "More symbols"
            key.accessibilityUserInputLabels = [title, key.accessibilityLabel ?? title]
            key.accessibilityHint = "Switch the symbol row between brackets and operators."
            key.accessibilityIdentifier = "key.symbolPage"
        }
        if action == .function {
            key.accessibilityLabel = "Function layer"
            key.accessibilityUserInputLabels = ["Fn", "Function layer"]
            key.accessibilityHint = "Switch between typing and editing keys without changing keyboard height."
            key.accessibilityValue = functionLayer ? "Editing keys" : "Typing keys"
            if functionLayer { key.accessibilityTraits.insert(.selected) }
        }
        if action == .shift {
            key.accessibilityHint = "Double-tap for Caps Lock, or use the Caps Lock accessibility action."
            key.accessibilityCustomActions = [UIAccessibilityCustomAction(name: capsLock ? "Turn Caps Lock off" : "Turn Caps Lock on") { [weak self] _ in
                self?.toggleCapsLock(); return self != nil
            }]
        }
        key.addAction(UIAction { [weak self, weak key] _ in
            guard let self, let key else { return }
            if self.consumeCancelledSnippetRelease(key) { self.finishPress(key); return }
            self.hidePreview()
            if let alternate = self.takeAlternate(for: key) {
                self.perform(.text(alternate), capturedModifiers: [], capturedUppercase: false)
                self.finishPress(key); return
            }
            if key.action == .shift {
                self.shiftHeld = false
                if !self.shiftUsed { self.perform(.shift) }
                else { self.needsKeyRebuild = true }
                self.shiftUsed = false
            } else if case .modifier(let modifier) = key.action {
                self.endModifier(modifier, cancelled: false)
            } else {
                let press = self.keyPresses[ObjectIdentifier(key)]
                self.perform(key.action, capturedModifiers: press?.modifiers, capturedUppercase: press?.uppercase)
            }
            self.finishPress(key)
        }, for: .touchUpInside)
        key.addAction(UIAction { [weak self, weak key] _ in
            guard let self, let key else { return }
            self.beginPress(key)
            self.playKeyFeedback()
            self.showPreview(for: key)
            if key.action == .delete, self.keyPresses[ObjectIdentifier(key)]?.modifiers.isEmpty == true { self.startDeleting() }
            self.scheduleAlternates(for: key)
        }, for: .touchDown)
        key.addAction(UIAction { [weak self, weak key] _ in
            guard let self, let key else { return }
            self.cancelPress(key)
        }, for: .touchCancel)
        key.addAction(UIAction { [weak self, weak key] _ in
            guard let self, let key else { return }
            // Sliding onto the alternates callout leaves the key's own area.
            if !self.consumeCancelledSnippetRelease(key), let alternate = self.takeAlternate(for: key) {
                self.perform(.text(alternate), capturedModifiers: [], capturedUppercase: false)
                self.finishPress(key); return
            }
            self.cancelPress(key)
        }, for: .touchUpOutside)
        key.addTarget(self, action: #selector(keyDragged(_:event:)), for: [.touchDragInside, .touchDragOutside])
        if action == .globe { key.addTarget(self, action: #selector(globeEvent(_:event:)), for: .allTouchEvents) }
        if action == .space {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(scrubCursor(_:)))
            pan.delegate = self
            pan.maximumNumberOfTouches = 1
            pan.delaysTouchesBegan = false
            pan.delaysTouchesEnded = false
            key.addGestureRecognizer(pan)
        }
        addSubview(key)
        return key
    }

    private func textKeys(_ values: [String]) -> [KeyButton] { values.map { makeKey($0, .text($0)) } }
    private func cancelPress(_ key: KeyButton) {
        if key.action == .shift { shiftHeld = false; shiftUsed = false; updateLetterLegends() }
        if case .modifier(let modifier) = key.action { endModifier(modifier, cancelled: true) }
        hidePreview(); finishPress(key)
    }

    /// Holding a key with alternates shows a callout; sliding picks one.
    private func scheduleAlternates(for key: KeyButton) {
        alternatesTask?.cancel(); alternatesTask = nil; alternatesKey = nil
        guard case .text(let text) = key.action, keyPresses[ObjectIdentifier(key)]?.modifiers.isEmpty == true else { return }
        let options = KeyAlternates.alternates(for: text)
        guard !options.isEmpty else { return }
        alternatesKey = ObjectIdentifier(key)
        alternatesTask = Task { [weak self, weak key] in
            try? await Task.sleep(for: .milliseconds(380))
            guard !Task.isCancelled, let self, let key, self.activeKeyPresses.contains(ObjectIdentifier(key)),
                  !self.isScrubbing, self.swipeTrace.isEmpty else { return }
            self.showAlternates(options, for: key)
        }
    }
    private func showAlternates(_ options: [String], for key: KeyButton) {
        hidePreview(); hideAlternates()
        let cellWidth = max(key.frame.width, 36)
        let height: CGFloat = 46
        let width = cellWidth * CGFloat(options.count)
        let x = max(2, min(bounds.width - width - 2, key.frame.midX - cellWidth / 2))
        let container = UIView(frame: CGRect(x: x, y: max(0, key.frame.minY - height - 4), width: width, height: height))
        container.backgroundColor = palette.key
        container.layer.cornerRadius = 10
        container.layer.cornerCurve = .continuous
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.25
        container.layer.shadowRadius = 4
        container.layer.shadowOffset = CGSize(width: 0, height: 1)
        container.isUserInteractionEnabled = false
        container.accessibilityElementsHidden = true
        container.accessibilityIdentifier = "keyboard.alternates"
        let labels = options.enumerated().map { index, option in
            let label = UILabel(frame: CGRect(x: CGFloat(index) * cellWidth + 2, y: 3, width: cellWidth - 4, height: height - 6))
            label.text = option
            label.textAlignment = .center
            label.font = .monospacedSystemFont(ofSize: option.count > 2 ? 15 : 20, weight: .medium)
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.6
            label.layer.cornerRadius = 7
            label.layer.cornerCurve = .continuous
            label.clipsToBounds = true
            container.addSubview(label)
            return label
        }
        addSubview(container)
        alternatesPopup = AlternatesPopup(key: key, options: options, view: container, labels: labels)
        selectAlternate(0)
        if preferences.settings.haptics { feedback?.generator.impactOccurred(intensity: 0.6) }
    }
    private func selectAlternate(_ index: Int) {
        guard var popup = alternatesPopup else { return }
        popup.selected = index
        alternatesPopup = popup
        for (position, label) in popup.labels.enumerated() {
            label.backgroundColor = position == index ? palette.accent : .clear
            label.textColor = position == index ? palette.background : palette.text
        }
    }
    @objc private func keyDragged(_ sender: UIControl, event: UIEvent) {
        guard let popup = alternatesPopup, popup.key === sender,
              let touch = event.touches(for: sender)?.first else { return }
        let cell = popup.view.frame.width / CGFloat(popup.options.count)
        let index = Int(((touch.location(in: self).x - popup.view.frame.minX) / cell).rounded(.down))
        let clamped = min(max(index, 0), popup.options.count - 1)
        if clamped != popup.selected { selectAlternate(clamped) }
    }
    private func takeAlternate(for key: KeyButton) -> String? {
        guard let popup = alternatesPopup, popup.key === key else { return nil }
        hideAlternates()
        return popup.options[popup.selected]
    }
    private func hideAlternates() {
        alternatesPopup?.view.removeFromSuperview(); alternatesPopup = nil
    }
    private func consumeCancelledSnippetRelease(_ button: UIButton) -> Bool {
        let cancelled = cancelledSnippetReleases.contains(button)
        cancelledSnippetReleases.remove(button)
        return cancelled
    }
    private func playKeyFeedback() {
        let settings = preferences.settings
        if settings.keyClicks { UIDevice.current.playInputClick() }
        guard settings.haptics else { feedback = nil; return }
        // Reuse one generator per strength rather than creating one per key.
        if feedback?.strength != settings.hapticStrength {
            let style: UIImpactFeedbackGenerator.FeedbackStyle = switch settings.hapticStrength {
            case .light: .light
            case .medium: .medium
            case .strong: .heavy
            }
            feedback = (UIImpactFeedbackGenerator(style: style, view: self), settings.hapticStrength)
        }
        feedback?.generator.impactOccurred()
        feedback?.generator.prepare()
    }
    private func beginToolbarPress(_ button: UIButton, consumesModifiers: Bool = true) {
        playKeyFeedback()
        let id = ObjectIdentifier(button)
        cancelledSnippetReleases.remove(button); activeKeyPresses.insert(id)
        keyPresses[id] = KeyPress(modifiers: modifiers, uppercase: false)
        if consumesModifiers {
            usedHeldModifiers.formUnion(heldModifiers)
            latchedModifiers = []; updateModifierButtons()
        }
    }
    private func finishToolbarPress(_ button: UIButton, action: KeyAction? = nil, cancelled: Bool = false) {
        let id = ObjectIdentifier(button)
        let suppressed = consumeCancelledSnippetRelease(button)
        let press = keyPresses.removeValue(forKey: id)
        activeKeyPresses.remove(id)
        if case .modifier(let modifier) = action { endModifier(modifier, cancelled: cancelled || suppressed) }
        else if let action, !cancelled, !suppressed { perform(action, capturedModifiers: press?.modifiers) }
        if activeKeyPresses.isEmpty, needsKeyRebuild { needsKeyRebuild = false; rebuild() }
        completePendingSnippetAction()
    }
    private func beginPress(_ key: KeyButton) {
        cancelledSnippetReleases.remove(key)
        // Primary-action menus own their tracking lifecycle and may present
        // without a matching touchUpInside from UIKit.
        if key.action == .settings { return }
        activeKeyPresses.insert(ObjectIdentifier(key))
        if key.action == .shift {
            shiftHeld = true; shiftUsed = false; updateLetterLegends()
        } else if case .modifier(let modifier) = key.action {
            beginModifier(modifier)
        } else if ![.mode, .symbols, .function, .settings, .symbolPage].contains(key.action) {
            // Capture a chord at finger-down, so releasing its modifier before
            // this finger lifts cannot turn it into an ordinary character.
            keyPresses[ObjectIdentifier(key)] = KeyPress(modifiers: modifiers, uppercase: uppercase || shiftHeld)
            usedHeldModifiers.formUnion(heldModifiers)
            if !latchedModifiers.isEmpty {
                latchedModifiers = []; updateModifierButtons()
            }
            if shiftHeld { shiftUsed = true }
            if case .text = key.action, uppercase && !capsLock && !shiftHeld {
                uppercase = false; needsKeyRebuild = true; updateLetterLegends()
            }
        }
    }

    private func finishPress(_ key: KeyButton) {
        if alternatesKey == ObjectIdentifier(key) { alternatesTask?.cancel(); alternatesTask = nil; alternatesKey = nil }
        if alternatesPopup?.key === key || alternatesPopup?.key == nil { hideAlternates() }
        activeKeyPresses.remove(ObjectIdentifier(key))
        keyPresses.removeValue(forKey: ObjectIdentifier(key))
        // Releasing a letter must not cancel a different finger's held Delete.
        if key.action == .delete { stopDeleting() }
        if activeKeyPresses.isEmpty, needsKeyRebuild { needsKeyRebuild = false; rebuild() }
        completePendingSnippetAction()
    }

    private func updateLetterLegends() {
        for key in rows.flatMap({ $0 }) {
            if key.action == .shift {
                key.accessibilityValue = capsLock ? "Caps lock" : (uppercase || shiftHeld ? "On for next key" : "Off")
                if uppercase || shiftHeld { key.accessibilityTraits.insert(.selected) }
                else { key.accessibilityTraits.remove(.selected) }
            }
            if case .text(let text) = key.action, text.count == 1, text.first?.isLetter == true {
                let displayed = uppercase || shiftHeld ? text.uppercased() : text.lowercased()
                key.legend.text = displayed
                key.accessibilityLabel = displayed
                key.accessibilityUserInputLabels = [displayed]
            }
        }
    }

    private func rebuild() {
        // Replacing a pressed UIControl cancels its other in-flight touches.
        // Finish all independent presses before replacing the grid.
        guard activeKeyPresses.isEmpty else { needsKeyRebuild = true; return }
        stopDeleting(); hidePreview(); hideAlternates()
        let focusedAction = rows.flatMap { $0 }.first { $0.accessibilityElementIsFocused() }?.action
        rows.flatMap { $0 }.forEach { $0.removeFromSuperview() }
        rows = []
        if isCompactHeight && functionLayer {
            rows.append([makeKey("Esc", .navigation(.escape), utility: true),
                makeKey("Left", symbol: "arrow.left", .navigation(.left), utility: true),
                makeKey("Down", symbol: "arrow.down", .navigation(.down), utility: true),
                makeKey("Up", symbol: "arrow.up", .navigation(.up), utility: true),
                makeKey("Right", symbol: "arrow.right", .navigation(.right), utility: true),
                makeKey("Home", .navigation(.home), utility: true), makeKey("End", .navigation(.end), utility: true)])
            rows.append([makeKey("Ctrl", .modifier(.control), utility: true),
                makeKey("Option", symbol: "option", .modifier(.option), utility: true),
                makeKey("Command", symbol: "command", .modifier(.command), utility: true),
                makeKey("Outdent", symbol: "decrease.indent", .outdent, utility: true),
                makeKey("Indent", symbol: "increase.indent", .indent, utility: true),
                makeKey("Delete line", symbol: "text.badge.minus", .line, utility: true)])
            rows.append(textKeys(["{", "}", "[", "]", "<", ">", "(", ")"]) + [
                makeKey("Settings", symbol: "gearshape", .settings, utility: true)])
        } else {
            if !isCompactHeight {
                var symbols: [KeyButton] = []
                if layout == .tabletop {
                    var navigation = [makeKey("Esc", .navigation(.escape), utility: true),
                        makeKey("Outdent", symbol: "decrease.indent", .outdent, utility: true),
                        makeKey("Indent", symbol: "increase.indent", .indent, utility: true),
                        makeKey("Home", .navigation(.home), utility: true), makeKey("End", .navigation(.end), utility: true)]
                    if preferences.settings.compatibility == .terminal {
                        navigation += [makeKey("Page Up", symbol: "arrow.up.to.line", .navigation(.pageUp), utility: true),
                            makeKey("Up", symbol: "arrow.up", .navigation(.up), utility: true),
                            makeKey("Down", symbol: "arrow.down", .navigation(.down), utility: true),
                            makeKey("Page Down", symbol: "arrow.down.to.line", .navigation(.pageDown), utility: true)]
                    }
                    let line = makeKey("Delete line", symbol: "text.badge.minus", .line, utility: true)
                    line.isEnabled = preferences.settings.compatibility != .remoteDesktop
                    line.accessibilityLabel = preferences.settings.compatibility == .terminal ? "Send Ctrl-U" : "Delete line"
                    navigation.append(line)
                    rows.append(navigation)
                } else {
                    symbols = [makeKey("Outdent", symbol: "decrease.indent", .outdent, utility: true), makeKey("Indent", symbol: "increase.indent", .indent, utility: true)]
                }
                if layout == .compact {
                    // Most iPhones in portrait use this layout. A second page puts
                    // the most-typed operators one tap away instead of on 123.
                    symbols += textKeys(symbolPage ? ["=", "\"", "'", ";", ":", "/", "-", "_"] : ["{", "}", "[", "]", "<", ">", "(", ")"])
                    symbols.append(makeKey(symbolPage ? "{}" : "=;", .symbolPage, weight: 0.9, utility: true))
                } else {
                    symbols += textKeys(["{", "}", "[", "]", "<", ">", "(", ")"])
                }
                if layout == .widePhone { symbols += textKeys(["=", "_"]) }
                if layout.hasFullSymbolRow { symbols += textKeys(["=", "_", ":", ";", "/", "|"]) }
                if layout == .studio || layout == .tabletop { symbols += textKeys(["&", "!", "~", "?"]) }
                rows.append(symbols)
                if showsNumberRow {
                    rows.append(textKeys(Array("1234567890").map(String.init) + (layout == .studio || layout == .tabletop ? ["-", "+", "*", "%"] : [])))
                }
            }
            if numbers {
                if moreSymbols {
                    rows.append(textKeys(["[", "]", "{", "}", "#", "%", "^", "*", "+", "="]))
                    rows.append(textKeys(["_", "\\", "|", "~", "<", ">", "`", "$", ":", ";"]))
                } else {
                    rows.append(textKeys(Array("1234567890").map(String.init)))
                    rows.append(textKeys(["@", "#", "$", "%", "&", "-", "+", "=", "/", "\\"]))
                }
                rows.append([makeKey(moreSymbols ? "123" : "#+=", .symbols, weight: 1.4, utility: true)]
                    + textKeys(["!", "?", "'", "\"", ",", ".", "/"])
                    + [makeKey("Delete", symbol: "delete.left", .delete, weight: 1.4, utility: true)])
            } else {
                let letterRows = ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
                for (index, letters) in letterRows.enumerated() {
                    var keys = Array(letters).enumerated().map { position, letter in
                        let title = uppercase ? String(letter).uppercased() : String(letter)
                        // The number row already shows these digits.
                        let digit = index == 0 && (isCompactHeight || !showsNumberRow) ? String((position + 1) % 10) : nil
                        return makeKey(title, hint: digit, .text(title))
                    }
                    if !isCompactHeight && layout.hasFullSymbolRow, index == 0 { keys += textKeys(["-", "+"]) }
                    if !isCompactHeight && layout.hasFullSymbolRow, index == 1 { keys += textKeys([";", "'", "\\"]) }
                    if index == 2 {
                        if !isCompactHeight && layout.hasFullSymbolRow { keys += textKeys([",", ".", "/"]) }
                        let shift = makeKey(capsLock ? "Caps lock" : "Shift", symbol: capsLock ? "capslock.fill" : uppercase ? "shift.fill" : "shift", .shift, weight: 1.4, utility: true)
                        keys.insert(shift, at: 0)
                        keys.append(makeKey("Delete", symbol: "delete.left", .delete, weight: 1.4, utility: true))
                    }
                    rows.append(keys)
                }
            }
        }
        var bottom = [makeKey(numbers ? "ABC" : "123", .mode, weight: 1.2, utility: true)]
        if needsGlobe { bottom.append(makeKey("Next keyboard", symbol: "globe", .globe, utility: true)) }
        if isCompactHeight { bottom.append(makeKey("Fn", .function, utility: true)) }
        bottom.append(makeKey("Tab", symbol: "arrow.right.to.line", .tab, utility: true))
        bottom.append(makeKey("space", .space, weight: isCompactHeight || layout == .compact ? 3.5 : 6))
        if !isCompactHeight { bottom.append(makeKey(".", .text("."))) }
        if !isCompactHeight && layout != .compact {
            bottom += [makeKey("Left", symbol: "arrow.left", .navigation(.left), utility: true), makeKey("Right", symbol: "arrow.right", .navigation(.right), utility: true)]
        }
        let returnLabel = isEditingSnippet ? nil : engine.document.returnKeyLabel
        displayedReturnLabel = returnLabel
        let enter = returnLabel.map { makeKey($0, .enter, weight: 1.5, utility: true) }
            ?? makeKey("Return", symbol: "return", .enter, weight: 1.5, utility: true)
        // Keep one identifier whatever the host's title.
        enter.accessibilityIdentifier = "key.Return"
        bottom.append(enter)
        // The outer bottom corners follow the display's rounded corners.
        bottom.first?.cornerConfiguration = .corners(topLeftRadius: .fixed(7), topRightRadius: .fixed(7),
            bottomLeftRadius: .containerConcentric(minimum: 7), bottomRightRadius: .fixed(7))
        bottom.last?.cornerConfiguration = .corners(topLeftRadius: .fixed(7), topRightRadius: .fixed(7),
            bottomLeftRadius: .fixed(7), bottomRightRadius: .containerConcentric(minimum: 7))
        rows.append(bottom)
        updateLetterLegends()
        updateKeyFonts()
        updateModifierButtons()
        for key in rows.flatMap({ $0 }) where key.action == .line {
            key.isEnabled = preferences.settings.compatibility != .remoteDesktop
            key.accessibilityLabel = preferences.settings.compatibility == .terminal ? "Send Ctrl-U" : "Delete line"
        }
        layer.addSublayer(swipeLayer)
        bringSubviewToFront(toolbar)
        if let focusedAction, let replacement = rows.flatMap({ $0 }).first(where: { $0.action == focusedAction }) {
            UIAccessibility.post(notification: .layoutChanged, argument: replacement)
        }
        invalidateIntrinsicContentSize()
        setNeedsLayout()
        onHeightChange?(desiredHeight)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        var lowerPanelHeight: CGFloat?
        if #available(iOS 27.1, *), let window {
            lowerPanelHeight = KeyboardGeometry.tabletopHeight(in: window.bounds,
                divisions: window.reservedRegions(kind: .division).filter(\.isActive).map(\.frame))
                .map { max(260, $0 - window.safeAreaInsets.bottom) }
        }
        let usableWidth = bounds.width - safeAreaInsets.left - safeAreaInsets.right
        let fullLayout = lowerPanelHeight != nil || (usableWidth >= 650 && preferences.settings.showNavigationRow)
        let resolved = fullLayout ? KeyboardLayout.tabletop : KeyboardLayout.resolve(width: Double(usableWidth))
        let heightChanged = tabletopHeight != lowerPanelHeight
        tabletopHeight = lowerPanelHeight
        var sceneSize = window?.windowScene?.effectiveGeometry.coordinateSpace.bounds.size
        if let size = sceneSize, window?.windowScene?.effectiveGeometry.interfaceOrientation.isLandscape == true, size.width < size.height {
            sceneSize = CGSize(width: size.height, height: size.width)
        }
        let hostSize = availableHostSize ?? sceneSize
        let roomChanged = ((hostHeight ?? .infinity) >= 760) != ((hostSize?.height ?? .infinity) >= 760)
        hostHeight = hostSize?.height
        let previouslyPreferredCompact = prefersCompactHeight
        prefersCompactHeight = KeyboardHeightPolicy.resolve(mode: preferences.settings.heightMode,
            availableHeight: hostSize.map { Double($0.height) },
            compactVertical: traitCollection.verticalSizeClass == .compact, tabletop: lowerPanelHeight != nil)
        let minimumFullHeight = 52 + CGFloat(fullRowCount) * 34 + safeAreaInsets.top + safeAreaInsets.bottom + snippetPanelHeight
        // A host may temporarily force less space than requested. Page the extra
        // controls away before allowing the full grid's targets to become tiny.
        let compact = prefersCompactHeight || (lowerPanelHeight == nil && bounds.height < minimumFullHeight)
        let compactChanged = compact != isCompactHeight
        isCompactHeight = compact
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--layout-diagnostics"), #available(iOS 27.1, *), let window {
            let divisions = window.reservedRegions(kind: .division).filter(\.isActive).map(\.frame)
            let horizontal = divisions.contains { $0.width >= window.bounds.width * 0.8 && $0.width > $0.height }
            accessibilityValue = "\(resolved.rawValue) horizontalDivision=\(horizontal) local=\(bounds) window=\(window.bounds) divisions=\(divisions)"
        }
        #endif
        if resolved != layout || compactChanged || roomChanged {
            layout = resolved
            if !compact { functionLayer = false }
            if !ProcessInfo.processInfo.arguments.contains("--layout-diagnostics") { accessibilityValue = resolved.rawValue }
            rebuild()
        } else if heightChanged || previouslyPreferredCompact != prefersCompactHeight {
            invalidateIntrinsicContentSize()
            onHeightChange?(desiredHeight)
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--layout-diagnostics") {
            accessibilityValue = "\(resolved.rawValue) horizontalDivision=\(lowerPanelHeight != nil) compact=\(isCompactHeight) preferred=\(prefersCompactHeight) requested=\(desiredHeight) bounds=\(bounds) host=\(String(describing: hostSize)) vertical=\(traitCollection.verticalSizeClass.rawValue)"
        }
        #endif
        if let snippetPanel {
            let rect = CGRect(x: safeAreaInsets.left + 5, y: safeAreaInsets.top, width: max(0, usableWidth - 10), height: snippetPanelHeight)
            snippetPanel.frame = usableSegments(in: rect).max(by: { $0.width < $1.width }) ?? .zero
        }
        let contentTop = safeAreaInsets.top + snippetPanelHeight
        toolbar.frame = CGRect(x: safeAreaInsets.left + 6, y: contentTop, width: bounds.width - safeAreaInsets.left - safeAreaInsets.right - 12, height: 44)
        toolbar.isHidden = isCompactHeight
        if !isCompactHeight { arrangeToolbar() }
        if isCompactHeight && statusLabel.superview !== self { addSubview(statusLabel) }
        if !isCompactHeight && statusLabel.superview !== toolbar { toolbar.addSubview(statusLabel) }
        if isCompactHeight { statusLabel.frame = CGRect(x: safeAreaInsets.left + 8, y: contentTop, width: max(0, usableWidth - 16), height: 44) }
        // Hosts can compress input views during rotations and keyboard transitions.
        let toolbarHeight: CGFloat = isCompactHeight ? 0 : 44
        let gap: CGFloat = isCompactHeight ? 4 : 6
        let available = max(0, bounds.height - contentTop - safeAreaInsets.bottom - toolbarHeight - 8)
        let fittedHeight = max(0, available / CGFloat(max(1, rows.count)) - gap)
        let preferredHeight: CGFloat = isCompactHeight ? 44 : preferences.settings.keySize.height
        let height = tabletopHeight == nil ? min(preferredHeight, fittedHeight) : fittedHeight
        for (index, row) in rows.enumerated() {
            var rect = CGRect(x: safeAreaInsets.left + 5, y: contentTop + toolbarHeight + 2 + CGFloat(index) * (height + gap), width: max(0, usableWidth - 10), height: height)
            if !functionLayer, !numbers, (isCompactHeight || layout == .compact), row.count == 9 { rect = rect.insetBy(dx: rect.width * 0.045, dy: 0) }
            arrange(row, in: rect)
        }
        var elements: [Any] = []
        if let snippetPanel { elements.append(snippetPanel) }
        if !isCompactHeight { elements.append(contentsOf: toolbarControls.filter { !$0.isHidden }) }
        elements.append(contentsOf: rows.flatMap { $0 }.filter { !$0.isHidden })
        accessibilityElements = elements
        if !statusLabel.isHidden { statusLabel.superview?.bringSubviewToFront(statusLabel) }
        swipeLayer.frame = bounds
    }

    private func usableSegments(in rect: CGRect) -> [CGRect] {
        if #available(iOS 27.1, *) {
            let regions = reservedRegions(kind: .division) + reservedRegions(kind: .occlusion)
            return KeyboardGeometry.horizontalSegments(in: rect, excluding: regions.filter(\.isActive).map(\.frame))
        }
        return [rect]
    }

    private func arrange(_ keys: [KeyButton], in rect: CGRect) {
        let segments = usableSegments(in: rect)
        guard !segments.isEmpty else { keys.forEach { $0.isHidden = true }; return }
        let totalWidth = segments.reduce(0) { $0 + $1.width }
        var offset = 0
        for (index, segment) in segments.enumerated() {
            let remaining = keys.count - offset
            let count = index == segments.count - 1 ? remaining : min(remaining, max(1, Int((CGFloat(keys.count) * segment.width / totalWidth).rounded())))
            guard count > 0 else { continue }
            let group = Array(keys[offset..<(offset + count)])
            let totalWeight = group.reduce(CGFloat.zero) { $0 + $1.weight }
            let unit = max(0, segment.width - CGFloat(count - 1) * 5) / totalWeight
            var x = segment.minX
            for key in group {
                key.isHidden = false
                key.frame = CGRect(x: x, y: segment.minY, width: unit * key.weight, height: segment.height).integral
                x += unit * key.weight + 5
            }
            for (keyIndex, key) in group.enumerated() {
                let left = keyIndex == 0 ? segment.minX : (group[keyIndex - 1].frame.maxX + key.frame.minX) / 2
                let right = keyIndex == group.count - 1 ? segment.maxX : (key.frame.maxX + group[keyIndex + 1].frame.minX) / 2
                let start = safeAreaInsets.top + snippetPanelHeight + (isCompactHeight ? 0 : 44)
                let top = max(start, segment.minY - (isCompactHeight ? 2 : 3))
                let target = CGRect(x: left, y: top, width: right - left, height: segment.maxY + (isCompactHeight ? 2 : 3) - top)
                let allowed = CGRect(x: segment.minX, y: start, width: segment.width,
                    height: max(0, bounds.height - safeAreaInsets.bottom - start))
                // Recheck the expanded vertical region against folds/cameras.
                key.touchFrame = usableSegments(in: target.intersection(allowed)).first(where: { $0.contains(CGPoint(x: key.frame.midX, y: key.frame.midY)) }) ?? key.frame
            }
            offset += count
        }
    }

    private var toolbarControls: [UIButton] {
        // Desktop order by default: Escape at the leading edge, then modifiers,
        // with the arrows toward the trailing side and settings last.
        preferences.settings.toolbarKeys.prefix(ToolbarKey.maximumCount).compactMap(toolbarButton) + [gearButton]
    }
    private var allToolbarButtons: [UIButton] {
        navigationButtons + modifierButtons.map(\.0) + [deleteLineButton, escapeButton, gearButton] + Array(extraToolbarButtons.values)
    }
    private func toolbarButton(_ key: ToolbarKey) -> UIButton? {
        switch key {
        case .escape: escapeButton
        case .deleteLine: deleteLineButton
        case .control: modifierButtons.first { $0.1 == .control }?.0
        case .option: modifierButtons.first { $0.1 == .option }?.0
        case .command: modifierButtons.first { $0.1 == .command }?.0
        case .left: navigationButtons[0]
        case .down: navigationButtons[1]
        case .up: navigationButtons[2]
        case .right: navigationButtons[3]
        default: extraToolbarButtons[key]
        }
    }

    private func arrangeToolbar() {
        let segments = usableSegments(in: toolbar.frame)
        let controls = toolbarControls
        for button in allToolbarButtons where !controls.contains(button) { button.isHidden = true }
        let totalWidth = segments.reduce(CGFloat.zero) { $0 + $1.width }
        var offset = 0
        for (index, segment) in segments.enumerated() {
            let remaining = controls.count - offset
            guard remaining > 0 else { break }
            let count = index == segments.count - 1 ? remaining
                : min(remaining, max(1, Int((CGFloat(controls.count) * segment.width / totalWidth).rounded())))
            for number in 0..<count {
                let button = controls[offset + number]
                button.isHidden = false
                // Adjacent hit targets fill the toolbar without dead gaps.
                let left = max(segment.minX, (segment.minX + CGFloat(number) * segment.width / CGFloat(count)).rounded(.down))
                let right = min(segment.maxX, (segment.minX + CGFloat(number + 1) * segment.width / CGFloat(count)).rounded(.down))
                button.frame = toolbar.convert(CGRect(x: left, y: segment.minY, width: right - left, height: segment.height), from: self)
            }
            offset += count
        }
        controls.dropFirst(offset).forEach { $0.isHidden = true }
        statusLabel.frame = toolbar.convert(segments.max(by: { $0.width < $1.width }) ?? .zero, from: self)
    }

    private func clearModifiers() {
        ignoredModifierReleases.formUnion(heldModifiers)
        latchedModifiers = []; heldModifiers = []; usedHeldModifiers = []
    }

    private func beginModifier(_ modifier: KeyboardModifiers) {
        ignoredModifierReleases.remove(modifier)
        heldModifiers.insert(modifier)
        usedHeldModifiers.remove(modifier)
        updateModifierButtons()
    }

    private func endModifier(_ modifier: KeyboardModifiers, cancelled: Bool) {
        if ignoredModifierReleases.contains(modifier) {
            ignoredModifierReleases.remove(modifier); return
        }
        let wasUsed = usedHeldModifiers.contains(modifier)
        heldModifiers.remove(modifier); usedHeldModifiers.remove(modifier)
        if wasUsed { latchedModifiers.remove(modifier) }
        else if !cancelled { latchedModifiers.formSymmetricDifference(modifier) }
        updateModifierButtons()
    }

    private func updateModifierButtons() {
        let gridModifiers = rows.flatMap { $0 }.compactMap { key -> (UIButton, KeyboardModifiers)? in
            if case .modifier(let modifier) = key.action { return (key, modifier) }
            return nil
        }
        for (button, modifier) in modifierButtons + gridModifiers {
            let active = modifiers.contains(modifier)
            button.isSelected = active
            button.backgroundColor = active ? palette.accent.withAlphaComponent(0.25) : .clear
            // Use the normal text color over the selected fill for contrast.
            button.tintColor = palette.text
            if let key = button as? KeyButton {
                key.legend.textColor = palette.text
                key.baseColor = active ? palette.accent.withAlphaComponent(0.25) : palette.utility
                key.backgroundColor = key.baseColor
            }
            button.layer.borderWidth = active ? 2 : 0
            button.layer.borderColor = palette.text.resolvedColor(with: traitCollection).cgColor
            button.accessibilityValue = active ? "On for next key" : "Off"
            if active { button.accessibilityTraits.insert(.selected) }
            else { button.accessibilityTraits.remove(.selected) }
        }
        for key in rows.flatMap({ $0 }) where key.action == .function {
            let names = [(KeyboardModifiers.control, "Control"), (.option, "Option"), (.command, "Command")]
                .filter { modifiers.contains($0.0) }.map(\.1)
            key.hint.text = [(KeyboardModifiers.control, "⌃"), (.option, "⌥"), (.command, "⌘")]
                .filter { modifiers.contains($0.0) }.map(\.1).joined()
            key.accessibilityValue = (functionLayer ? "Editing keys" : "Typing keys")
                + (names.isEmpty ? "" : ", " + names.joined(separator: ", ") + " on for next key")
            key.layer.borderWidth = functionLayer || !names.isEmpty ? 2 : 0
            key.layer.borderColor = palette.text.resolvedColor(with: traitCollection).cgColor
        }
    }

    private func updateKeyFonts() {
        let bold = traitCollection.legibilityWeight == .bold
        let metrics = UIFontMetrics(forTextStyle: .body)
        escapeButton.titleLabel?.font = metrics.scaledFont(for: .monospacedSystemFont(ofSize: 12, weight: bold ? .bold : .medium), maximumPointSize: 16, compatibleWith: traitCollection)
        for button in extraToolbarButtons.values where button.title(for: .normal) != nil {
            button.titleLabel?.font = metrics.scaledFont(for: .monospacedSystemFont(ofSize: 18, weight: bold ? .bold : .medium), maximumPointSize: 22, compatibleWith: traitCollection)
        }
        for key in rows.flatMap({ $0 }) {
            let baseSize: CGFloat = [.function, .modifier(.control), .enter, .symbolPage].contains(key.action) ? 14 : 21
            key.legend.font = metrics.scaledFont(for: .monospacedSystemFont(ofSize: baseSize, weight: bold ? .bold : .regular), maximumPointSize: baseSize + 5, compatibleWith: traitCollection)
            key.hint.font = .monospacedSystemFont(ofSize: 9, weight: bold ? .bold : .medium)
            key.setPreferredSymbolConfiguration(UIImage.SymbolConfiguration(pointSize: 18, weight: bold ? .bold : .medium), forImageIn: .normal)
        }
        for (button, modifier) in modifierButtons {
            let baseSize: CGFloat = modifier == .control ? 12 : 22
            button.titleLabel?.font = metrics.scaledFont(for: .monospacedSystemFont(ofSize: baseSize, weight: bold ? .bold : .semibold), maximumPointSize: baseSize + 4, compatibleWith: traitCollection)
        }
    }

    private func perform(_ action: KeyAction, capturedModifiers: KeyboardModifiers? = nil, capturedUppercase: Bool? = nil) {
        defer { completePendingSnippetAction() }
        if isEditingSnippet {
            if action == .enter, snippetDraft?.editingName == true { selectSnippetField(name: false); return }
            if action == .navigation(.escape) { finishSnippetEditing(save: false); return }
            if action == .globe { finishSnippetEditing(save: false); if !isEditingSnippet { onNextKeyboard?() }; return }
        }
        if isScrubbing { isScrubbing = false; return }
        statusTask?.cancel(); statusLabel.isHidden = true
        invalidateSwipeContext()
        // Changing character pages or Shift must preserve the pending chord.
        if [.mode, .symbols, .shift, .function, .symbolPage].contains(action) {
            switch action {
            case .mode: numbers.toggle(); moreSymbols = false; functionLayer = false
            case .symbols: moreSymbols.toggle()
            case .function: functionLayer.toggle()
            case .symbolPage: symbolPage.toggle()
            default:
                autoShifted = false
                if Date().timeIntervalSince(lastShiftTap) < 0.35 { capsLock = true; uppercase = true }
                else { uppercase.toggle(); capsLock = false }
                lastShiftTap = Date()
            }
            rebuild()
            if action == .shift { updateCombinedMenu() }
            refreshContext(); return
        }
        if action == .settings { return }
        let pending = capturedModifiers ?? modifiers
        if capturedModifiers == nil {
            usedHeldModifiers.formUnion(heldModifiers)
            if !latchedModifiers.isEmpty {
                latchedModifiers = []; updateModifierButtons()
            }
        }
        let outputText: (String) -> String = { [self] text in
            guard text.count == 1, text.first?.isLetter == true else { return text }
            return (capturedUppercase ?? (uppercase || shiftHeld)) ? text.uppercased() : text.lowercased()
        }
        var handled = true
        if !pending.isEmpty {
            switch action {
            case .text(let text): handled = engine.sendShortcut(outputText(text), modifiers: pending)
            case .space: handled = engine.sendShortcut(" ", modifiers: pending)
            case .tab: handled = engine.sendShortcut("\t", modifiers: pending)
            case .enter: handled = engine.sendShortcut("\r", modifiers: pending)
            case .navigation(let key): handled = engine.navigate(key, modifiers: pending)
            case .delete: handled = engine.sendShortcut("\u{7F}", modifiers: pending)
            default: handled = false
            }
        } else {
            switch action {
            case .text(let text): engine.type(outputText(text))
            case .delete: engine.backspace()
            case .line: performLineAction()
            case .tab: engine.tab()
            case .space: typeSpace()
            case .enter: engine.newline()
            case .indent: engine.indent()
            case .outdent:
                if engine.settings.compatibility == .remoteDesktop { showStatus("Use the client’s Shift-Tab") }
                else { engine.outdent() }
            case .navigation(let key): handled = engine.navigate(key)
            case .globe: onNextKeyboard?()
            default: break
            }
        }
        if !handled { showStatus(pending.isEmpty ? "Host limits cursor movement" : "Shortcut unavailable · use the client’s keys") }
        if action != .space || !pending.isEmpty { lastSpaceTime = .distantPast }
        if case .text = action, capturedUppercase == nil {
            if shiftHeld { shiftUsed = true }
            if uppercase && !capsLock { uppercase = false; autoShifted = false; rebuild() }
        }
        updateAutoCapitalization()
        refreshContext()
    }

    private var proseInputActive: Bool {
        !isEditingSnippet && engine.settings.smartEditingEnabled && engine.document.capitalizesSentences
    }
    /// A quick second Space after a word becomes ". ", replacing only a verified space.
    private func typeSpace() {
        if preferences.settings.periodShortcut, proseInputActive,
           Date().timeIntervalSince(lastSpaceTime) < 1.5,
           ProseInputPolicy.doubleSpaceMakesPeriod(before: engine.document.contextBeforeInput(maximumCharacters: 2)) {
            engine.invalidateAutocorrection()
            if engine.document.replaceTextBeforeCursor(" ", with: ". ") { lastSpaceTime = .distantPast; return }
        }
        engine.type(" ")
        lastSpaceTime = Date()
    }
    private func updateAutoCapitalization() {
        let wanted = preferences.settings.autoCapitalize && proseInputActive && !numbers && !functionLayer && !capsLock
            && engine.document.selectedText == nil
            && ProseInputPolicy.startsSentence(before: engine.document.contextBeforeInput(maximumCharacters: 8))
        if wanted {
            guard !uppercase else { return }
            uppercase = true; autoShifted = true; rebuild()
        } else if autoShifted {
            autoShifted = false
            if uppercase && !capsLock { uppercase = false; rebuild() }
        }
    }
    /// The host changed its text, selection or field: re-evaluate sentence
    /// capitals before refreshing suggestions and the return key.
    func hostContextDidChange() {
        updateAutoCapitalization()
        refreshContext()
    }

    func refreshContext() {
        if let draft = snippetDraft { snippetPanel?.update(draft); return }
        if engine.document.returnKeyLabel != displayedReturnLabel { rebuild() }
        if preferences.settings.autocorrectProse { engine.validateAutocorrectionContext() }
        // Suggestions remain available in the shared tools and settings menu,
        // leaving a toolbar slot for the dedicated Escape key.
        let words = swipeWords.isEmpty ? engine.completions : swipeWords
        let generation = swipeWords.isEmpty ? nil : swipeGeneration
        guard words != displayedSuggestions || generation != displayedSwipeGeneration else { return }
        displayedSuggestions = words
        displayedSwipeGeneration = generation
        updateCombinedMenu()
    }
    /// Use iOS's keyboard lexicon to leave names and text-shortcut inputs alone.
    /// Keep only bounded words in memory; never persist or log the lexicon.
    func useSupplementaryLexicon(_ lexicon: UILexicon) {
        guard !isEditingSnippet, preferences.settings.autocorrectProse else { return }
        supplementaryProtectedWords = Set(lexicon.entries.prefix(4096).flatMap { [$0.userInput, $0.documentText] }
            .filter { !$0.isEmpty && $0.count <= 64 }.map { $0.lowercased() })
        hasSupplementaryLexicon = true
        proseCorrector?.protectedWords = supplementaryProtectedWords
    }
    private func accept(_ word: String) {
        guard !isEditingSnippet else { return }
        engine.invalidateAutocorrection()
        latchedModifiers = []; usedHeldModifiers.formUnion(heldModifiers); updateModifierButtons()
        if let last = lastSwipeWord {
            // A verified native replacement temporarily selects its source.
            // Preserve alternatives across those synchronous host callbacks.
            let alternatives = swipeWords
            guard swipeReplacementAnchor?.matches(engine.document) == true,
                  engine.document.replaceTextBeforeCursor(last, with: word) else {
                invalidateSwipeContext(); refreshContext(); return
            }
            lastSwipeWord = word
            swipeWords = alternatives
            swipeReplacementAnchor = SwipeAnchor(engine.document)
            swipeGeneration &+= 1
            // Every retained alternative belongs to the source word and anchor
            // shown when its menu was built. Refresh them after replacement.
            updateCombinedMenu()
        } else { engine.complete(word) }
        refreshContext()
    }

    private var snippetInputSettings: KeyboardSettings {
        var settings = preferences.settings
        settings.compatibility = .editor
        settings.autoPair = false; settings.skipClosingDelimiter = false
        settings.smartIndent = false; settings.autocorrectProse = false
        settings.suggestions = false; settings.swipeTyping = false
        return settings
    }

    func beginSnippetEditing(_ snippet: CodeSnippet?) {
        guard !isEditingSnippet, activeKeyPresses.isEmpty, keyPresses.isEmpty else { showStatus("Release the keys before editing a snippet"); return }
        if let snippet, snippet.name.count > 80 || snippet.text.count > 4096 {
            showStatus("This snippet exceeds the editor limit. Names allow 80 characters; text allows 4,096."); return
        }
        releaseTransientResources()
        let draft = KeyboardSnippetDraft(snippet: snippet)
        snippetDraft = draft
        documentRouter.local = draft.document; documentRouter.localLimit = draft.limit
        engine.settings = snippetInputSettings
        let panel = SnippetDraftPanel()
        panel.tintColor = ScriptTheme.accent
        panel.onCancel = { [weak self] in self?.finishSnippetEditing(save: false) }
        panel.onSave = { [weak self] in self?.finishSnippetEditing(save: true) }
        panel.onField = { [weak self] name in self?.selectSnippetField(name: name) }
        panel.onClear = { [weak self] in
            guard let self, let draft = self.snippetDraft, self.activeKeyPresses.isEmpty, self.keyPresses.isEmpty else { return }
            draft.document.selection = NSRange(location: 0, length: draft.document.text.utf16.count)
            self.documentRouter.insert("")
        }
        snippetPanel = panel; addSubview(panel); panel.update(draft)
        onSnippetEditingChanged?(true)
        rebuild(); updateMenus(); setNeedsLayout()
        onHeightChange?(desiredHeight)
        UIAccessibility.post(notification: .layoutChanged, argument: panel)
    }

    func selectSnippetField(name: Bool) {
        guard let draft = snippetDraft else { return }
        guard activeKeyPresses.isEmpty, keyPresses.isEmpty else { pendingSnippetField = name; snippetPanel?.update(draft); return }
        stopDeleting(); clearModifiers()
        draft.editingName = name
        documentRouter.local = draft.document; documentRouter.localLimit = draft.limit
        snippetPanel?.update(draft)
    }

    func finishSnippetEditing(save: Bool) {
        guard let draft = snippetDraft else { return }
        guard activeKeyPresses.isEmpty, keyPresses.isEmpty else { pendingSnippetClose = save; return }
        if save {
            guard let snippet = draft.snippet else { showStatus("Enter a name and snippet text before saving"); return }
            if let index = preferences.settings.snippets.firstIndex(where: { $0.id == snippet.id }) { preferences.settings.snippets[index] = snippet }
            else { preferences.settings.snippets.append(snippet) }
        }
        closeSnippetDraft()
        showStatus(save ? "Snippet saved. Choose it from Snippets to insert." : "Snippet changes discarded")
    }

    private func completePendingSnippetAction() {
        guard isEditingSnippet, activeKeyPresses.isEmpty, keyPresses.isEmpty else { return }
        if let save = pendingSnippetClose { pendingSnippetClose = nil; finishSnippetEditing(save: save) }
        else if let name = pendingSnippetField { pendingSnippetField = nil; selectSnippetField(name: name) }
    }

    private func closeSnippetDraft() {
        guard isEditingSnippet else { return }
        stopDeleting(); hidePreview(); clearModifiers()
        engine.invalidateAutocorrection()
        documentRouter.local = nil
        snippetDraft = nil; snippetPanel?.removeFromSuperview(); snippetPanel = nil
        pendingSnippetClose = nil; pendingSnippetField = nil
        uppercase = false; capsLock = false; shiftHeld = false; shiftUsed = false
        engine.settings = preferences.settings
        rebuild(); updateMenus(); setNeedsLayout()
        onHeightChange?(desiredHeight)
        onSnippetEditingChanged?(false)
    }

    private func updateMenus() {
        let settings = preferences.settings
        let terminal = engine.settings.compatibility == .terminal
        deleteLineButton.setImage(terminal ? nil : UIImage(systemName: "text.badge.minus"), for: .normal)
        deleteLineButton.setTitle(terminal ? "^U" : nil, for: .normal)
        deleteLineButton.titleLabel?.font = .monospacedSystemFont(ofSize: 14, weight: .semibold)
        deleteLineButton.accessibilityLabel = terminal ? "Send Ctrl-U" : "Delete line"
        deleteLineButton.accessibilityHint = terminal
            ? "Sends the terminal's line clearing command. Behavior depends on the shell."
            : "Deletes the current line when the app exposes its boundaries. Use Delete for selected text."
        deleteLineButton.isEnabled = settings.compatibility != .remoteDesktop
        func toggle(_ title: String, _ keyPath: WritableKeyPath<KeyboardSettings, Bool>) -> UIAction {
            UIAction(title: title, state: settings[keyPath: keyPath] ? .on : .off) { [weak self] _ in
                guard let self else { return }
                self.preferences.settings[keyPath: keyPath].toggle(); self.applySettings()
            }
        }
        let autocorrect = UIAction(title: "Autocorrect prose (English)",
            attributes: settings.smartEditingEnabled ? [] : .disabled,
            state: settings.autocorrectProse ? .on : .off) { [weak self] _ in
                guard let self else { return }
                self.preferences.settings.autocorrectProse.toggle()
                self.applySettings()
                if self.preferences.settings.autocorrectProse && !self.engine.document.allowsAutocorrection {
                    self.showStatus("Autocorrect is unavailable in this field")
                }
            }
        autocorrect.subtitle = "On Space in supported prose fields. Delete immediately to undo."
        let enabledToolbarKeys = settings.toolbarKeys
        let toolbarKeys = UIMenu(title: "Toolbar keys", children: ToolbarKey.allCases.map { key in
            let on = enabledToolbarKeys.contains(key)
            let full = !on && enabledToolbarKeys.count >= ToolbarKey.maximumCount
            let action = UIAction(title: key.title, attributes: full ? .disabled : [], state: on ? .on : .off) { [weak self] _ in
                guard let self else { return }
                var keys = self.preferences.settings.toolbarKeys
                if let index = keys.firstIndex(of: key) { keys.remove(at: index) } else { keys.append(key) }
                self.preferences.settings.toolbarKeys = keys; self.applySettings()
            }
            if full { action.subtitle = "Turn another key off first" }
            return action
        } + [UIAction(title: "Restore default toolbar", image: UIImage(systemName: "arrow.counterclockwise")) { [weak self] _ in
            self?.preferences.settings.toolbarKeys = ToolbarKey.defaults; self?.applySettings()
        }])
        let size = UIMenu(title: "Key size", children: KeySize.allCases.map { size in
            UIAction(title: size.rawValue, state: settings.keySize == size ? .on : .off) { [weak self] _ in
                self?.preferences.settings.keySize = size; self?.applySettings()
            }
        })
        quickSettingsItems = [
            UIMenu(title: "Language · " + settings.language.rawValue, image: UIImage(systemName: "chevron.left.forwardslash.chevron.right"), children: CodeLanguage.allCases.map { language in
                UIAction(title: language.rawValue, state: settings.language == language ? .on : .off) { [weak self] _ in
                    self?.preferences.settings.language = language; self?.applySettings()
                }
            }),
            UIMenu(title: "Input profile", image: UIImage(systemName: "terminal"), children: CompatibilityMode.allCases.map { mode in
                let action = UIAction(title: mode.rawValue, state: settings.compatibility == mode ? .on : .off) { [weak self] _ in
                    self?.preferences.settings.compatibility = mode; self?.applySettings()
                }
                action.subtitle = mode.detail
                return action
            }),
            UIMenu(title: "Indentation", image: UIImage(systemName: "increase.indent"), children: Indentation.allCases.map { indentation in
                UIAction(title: indentation.rawValue, state: settings.indentation == indentation ? .on : .off) { [weak self] _ in
                    self?.preferences.settings.indentation = indentation; self?.applySettings()
                }
            }),
            UIMenu(title: "Keyboard height", image: UIImage(systemName: "rectangle.compress.vertical"), children: KeyboardHeightMode.allCases.map { mode in
                UIAction(title: mode.rawValue, state: settings.heightMode == mode ? .on : .off) { [weak self] _ in
                    self?.preferences.settings.heightMode = mode; self?.applySettings()
                }
            }),
            UIMenu(title: "Keyboard theme", image: UIImage(systemName: "paintpalette"), children: KeyboardTheme.allCases.map { theme in
                UIAction(title: theme.rawValue, state: settings.theme == theme ? .on : .off) { [weak self] _ in
                    self?.preferences.settings.theme = theme; self?.applySettings()
                }
            }),
            UIMenu(title: "Appearance", children: KeyboardAppearance.allCases.map { appearance in
                UIAction(title: appearance.rawValue, attributes: settings.theme.usesDarkPalette ? .disabled : [], state: settings.appearance == appearance ? .on : .off) { [weak self] _ in
                    self?.preferences.settings.appearance = appearance; self?.applySettings()
                }
            }),
            UIMenu(title: "Editing preferences", image: UIImage(systemName: "text.cursor"), children: [
                toggle("Pair brackets & quotes", \.autoPair), toggle("Skip existing closing delimiter", \.skipClosingDelimiter),
                toggle("Automatic indentation", \.smartIndent), toggle("Code suggestions", \.suggestions), autocorrect,
                toggle("Auto-capitalization", \.autoCapitalize), toggle("“.” shortcut", \.periodShortcut),
                toggle("Swipe typing · beta", \.swipeTyping)
            ]),
            UIMenu(title: "Layout & keys", image: UIImage(systemName: "keyboard"), children: [
                size, toggle("Show number row in full layouts", \.showNumberRow),
                toggle("Extra editing row on wide layouts", \.showNavigationRow), toggle("Show number hints", \.showKeyHints),
                toggle("Key press previews", \.keyPreviews), toolbarKeys
            ]),
            UIMenu(title: "Gestures & feedback", children: [
                toggle("Drag space to move cursor", \.cursorScrubbing), toggle("Hold Delete to repeat", \.repeatDelete), toggle("Key click sounds", \.keyClicks), toggle("Haptic feedback", \.haptics),
                UIMenu(title: "Haptic strength", children: HapticStrength.allCases.map { strength in
                    UIAction(title: strength.rawValue, attributes: settings.haptics ? [] : .disabled, state: settings.hapticStrength == strength ? .on : .off) { [weak self] _ in
                        self?.preferences.settings.hapticStrength = strength; self?.applySettings()
                    }
                })
            ]),
            UIMenu(title: "Terminal · ANSI", image: UIImage(systemName: "terminal"), children: [
                toggle("Return sends carriage return (CR)", \.terminalReturnIsCR),
                toggle("Delete sends DEL instead of BS", \.terminalDeleteIsDEL), toggle("Application cursor mode (SS3)", \.terminalApplicationCursor)
            ]),
            UIMenu(title: "Reset settings & snippets", image: UIImage(systemName: "arrow.counterclockwise"), children: [
                UIAction(title: "Reset keyboard preferences and snippets", attributes: .destructive) { [weak self] _ in
                    guard let self, self.activeKeyPresses.isEmpty, self.keyPresses.isEmpty else { return }
                    self.preferences.reset(); self.applySettings(); self.showStatus("Keyboard preferences and snippets reset")
                }
            ]),
            UIMenu(options: .displayInline, children: [
                UIAction(title: isPreview ? "About this preview" : "Stored in this keyboard", image: UIImage(systemName: "info.circle")) { [weak self] _ in
                    guard let self else { return }
                    self.showStatus(self.isPreview ? "Changes and snippets stay in this preview until the app closes" : "Preferences and snippets stay in this keyboard. Full Access is not requested.")
                },
                UIAction(title: "Use system keyboard / dictation", image: UIImage(systemName: "globe")) { [weak self] _ in self?.onNextKeyboard?() },
                UIAction(title: "Dismiss keyboard", image: UIImage(systemName: "keyboard.chevron.compact.down")) { [weak self] _ in self?.onDismiss?() }
            ])
        ]
        updateCombinedMenu()
    }

    private func updateCombinedMenu() {
        let settings = preferences.settings
        let terminal = settings.compatibility == .terminal
        let navigation = NavigationKey.allMenuKeys.map { key, title in
            let terminalOnly = [.pageUp, .pageDown].contains(key)
            return UIAction(title: title, attributes: terminalOnly && settings.compatibility != .terminal ? .disabled : []) { [weak self] _ in self?.perform(.navigation(key)) }
        }
        let isSwipeAlternative = !swipeWords.isEmpty
        let expectedGeneration = swipeGeneration
        let expectedWord = lastSwipeWord
        let expectedAnchor = swipeReplacementAnchor
        let suggestions = UIMenu(title: isSwipeAlternative ? "Swipe alternatives" : "Code suggestions", children: displayedSuggestions.map { word in
            UIAction(title: word) { [weak self] _ in
                guard let self else { return }
                if isSwipeAlternative {
                    // A menu can outlive a host callback or another gesture.
                    // Never reinterpret an old swipe alternative as a completion.
                    guard self.swipeGeneration == expectedGeneration,
                          let expectedWord, self.lastSwipeWord == expectedWord,
                          expectedAnchor?.matches(self.engine.document) == true else { return }
                } else {
                    guard self.lastSwipeWord == nil else { return }
                }
                self.accept(word)
            }
        })
        let editing = UIMenu(title: "Editing actions", image: UIImage(systemName: "text.cursor"), children: [
            UIAction(title: capsLock ? "Turn Caps Lock off" : "Turn Caps Lock on", image: UIImage(systemName: "capslock")) { [weak self] _ in self?.toggleCapsLock() },
            UIAction(title: "Modifier key help", image: UIImage(systemName: "info.circle")) { [weak self] _ in
                self?.showStatus(terminal ? "Ctrl: control codes · ⌥: Meta · ⌘: client only" : "⌥ ←/→: word · ⌘ ←/→: line · Ctrl: ANSI mode")
            },
            UIMenu(options: .displayInline, children: [
                UIAction(title: "Delete line", image: UIImage(systemName: "text.badge.minus"), attributes: settings.compatibility == .editor ? .destructive : .disabled) { [weak self] _ in self?.performLineAction() },
                UIAction(title: "Clear toward line start · Ctrl-U", attributes: terminal ? [] : .disabled) { [weak self] _ in self?.engine.control("u"); self?.refreshContext() },
                UIAction(title: "Clear toward line end · Ctrl-K", attributes: terminal ? [] : .disabled) { [weak self] _ in self?.engine.control("k"); self?.refreshContext() }
            ]),
            UIMenu(title: "Cursor & terminal keys", children: navigation),
            UIMenu(title: "Control codes · ANSI only", children: ["c", "d", "z", "a", "e", "l", "r", "u", "w", "k"].map { letter in
                UIAction(title: "Ctrl-" + letter.uppercased(), attributes: settings.compatibility == .terminal ? [] : .disabled) { [weak self] _ in self?.engine.control(letter) }
            }),
            UIAction(title: "Reindent selection", image: UIImage(systemName: "text.alignleft"), attributes: settings.smartEditingEnabled ? [] : .disabled) { [weak self] _ in self?.formatSelection() }
        ])
        let management = UIMenu(title: "Manage snippets", children: [
            UIAction(title: "Add snippet", image: UIImage(systemName: "plus")) { [weak self] _ in self?.beginSnippetEditing(nil) }
        ] + settings.snippets.map { snippet in
            UIMenu(title: snippet.name, children: [
                UIAction(title: "Edit snippet", image: UIImage(systemName: "pencil")) { [weak self] _ in self?.beginSnippetEditing(snippet) },
                UIMenu(title: "Delete snippet", children: [UIAction(title: "Delete “" + snippet.name + "”", attributes: .destructive) { [weak self] _ in
                    self?.preferences.settings.snippets.removeAll { $0.id == snippet.id }; self?.applySettings()
                }])
            ])
        })
        let snippets = UIMenu(title: "Snippets", image: UIImage(systemName: "text.badge.plus"), children: [
            UIMenu(options: .displayInline, children: settings.snippets.map { snippet in
                UIAction(title: snippet.name) { [weak self] _ in self?.engine.invalidateAutocorrection(); self?.engine.document.insert(snippet.text); self?.refreshContext() }
            }), management
        ])
        // Reuse the settings actions while typing: only completion-dependent
        // tools need to refresh when the text context changes.
        gearButton.isEnabled = !isEditingSnippet
        gearButton.menu = isEditingSnippet ? nil : UIMenu(title: isPreview ? "Playground preview" : "Keyboard settings", children: [editing, suggestions, snippets] + quickSettingsItems)
        for key in rows.flatMap({ $0 }) where key.action == .settings { key.menu = gearButton.menu; key.isEnabled = !isEditingSnippet }
    }

    private func toggleCapsLock() {
        capsLock.toggle(); uppercase = capsLock; lastShiftTap = .distantPast
        rebuild(); updateCombinedMenu()
    }

    private func performLineAction() {
        if engine.settings.compatibility == .terminal {
            engine.control("u")
        } else if !engine.deleteLine() {
            showStatus(engine.document.selectedText == nil ? "Host limits line editing" : "Use Delete for selected text")
        }
        lastSwipeWord = nil; swipeWords = []
        refreshContext()
    }

    private func formatSelection() {
        engine.invalidateAutocorrection()
        guard let selected = engine.document.selectedText, !selected.isEmpty else { showStatus("Select code first"); return }
        do {
            let formatted = try CodeFormatter.format(selected, language: preferences.settings.language, indentation: preferences.settings.indentation)
            engine.document.insert(formatted)
            showStatus("Selection formatted")
        } catch { showStatus(preferences.settings.language == .json ? "Check JSON syntax" : "Use the indent keys here") }
    }
    func showStatus(_ message: String, seconds: Int = 3) {
        statusTask?.cancel()
        statusLabel.text = message; statusLabel.isHidden = false
        statusLabel.superview?.bringSubviewToFront(statusLabel)
        UIAccessibility.post(notification: .announcement, argument: message)
        statusTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.statusLabel.isHidden = true
        }
    }
    private static let tips = [
        "Tip: hold q–p for numbers, or hold a symbol for related operators",
        "Tip: on iPhone, =; switches the symbol row to operators",
        "Tip: drag the space bar to move the cursor",
        "Tip: the gear holds snippets, themes, toolbar keys and settings"
    ]
    /// Shows each one-time tip once, on a later keyboard appearance each.
    func showNextTipIfNeeded() {
        guard !isPreview, !isEditingSnippet, window != nil else { return }
        let index = preferences.settings.tipsShown
        guard Self.tips.indices.contains(index) else { return }
        preferences.settings.tipsShown = index + 1
        showStatus(Self.tips[index], seconds: 6)
    }
    @objc private func globeEvent(_ sender: UIView, event: UIEvent) {
        if !isEditingSnippet { onInputModeEvent?(sender, event) }
    }
    private func startDeleting() {
        guard preferences.settings.repeatDelete, modifiers.isEmpty else { return }
        deleteTask?.cancel()
        deleteTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            while !Task.isCancelled {
                if let self { self.engine.backspace(); self.refreshContext() }
                else { return }
                try? await Task.sleep(for: .milliseconds(75))
            }
        }
    }
    private func stopDeleting() { deleteTask?.cancel(); deleteTask = nil }
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { releaseTransientResources() }
    }
    /// The keyboard process may stay alive after dismissal. Keep only its small
    /// reusable key grid and saved preferences, not gesture or timer state.
    func releaseTransientResources() {
        if isEditingSnippet {
            for button in allToolbarButtons + rows.flatMap({ $0 }) {
                let id = ObjectIdentifier(button)
                if activeKeyPresses.contains(id) || keyPresses[id] != nil { cancelledSnippetReleases.add(button) }
            }
            closeSnippetDraft()
        }
        engine.invalidateAutocorrection()
        proseCorrector = nil; correctionDocument = nil
        supplementaryProtectedWords = []
        hasSupplementaryLexicon = false
        stopDeleting(); hidePreview(); hideAlternates()
        alternatesTask?.cancel(); alternatesTask = nil; alternatesKey = nil
        statusTask?.cancel(); statusTask = nil
        statusLabel.isHidden = true
        invalidateSwipeContext()
        swipeDecoder = nil
        feedback = nil
        clearModifiers(); isScrubbing = false
        activeKeyPresses = []; keyPresses = [:]; shiftHeld = false; shiftUsed = false
        if needsKeyRebuild { needsKeyRebuild = false; rebuild() }
        updateLetterLegends()
        updateModifierButtons()
        displayedSuggestions = []; updateCombinedMenu()
    }
    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        invalidateIntrinsicContentSize()
        onHeightChange?(desiredHeight)
        setNeedsLayout()
    }
    private func showPreview(for key: KeyButton) {
        guard preferences.settings.keyPreviews, case .text(let text) = key.action, text.count == 1 else { return }
        hidePreview()
        let preview = UILabel(frame: CGRect(x: max(2, min(bounds.width - 54, key.frame.midX - 26)), y: max(44, key.frame.minY - 42), width: 52, height: 52))
        let upper = keyPresses[ObjectIdentifier(key)]?.uppercase ?? (uppercase || shiftHeld)
        preview.text = upper ? text.uppercased() : text
        preview.textAlignment = .center
        preview.font = .monospacedSystemFont(ofSize: 30, weight: .medium)
        preview.backgroundColor = palette.key; preview.textColor = palette.accent
        preview.layer.cornerRadius = 10; preview.clipsToBounds = true
        preview.isUserInteractionEnabled = false
        preview.isAccessibilityElement = false
        preview.accessibilityElementsHidden = true
        addSubview(preview); previewLabel = preview
    }
    private func hidePreview() { previewLabel?.removeFromSuperview(); previewLabel = nil }

    @objc private func scrubCursor(_ gesture: UIPanGestureRecognizer) {
        guard !isEditingSnippet else { return }
        guard !UIAccessibility.isVoiceOverRunning, !UIAccessibility.isSwitchControlRunning,
            preferences.settings.cursorScrubbing, preferences.settings.compatibility != .terminal, modifiers.isEmpty else { return }
        if gesture.state == .began { invalidateSwipeContext(); scrubTranslation = 0; isScrubbing = true; hidePreview() }
        let x = gesture.translation(in: self).x
        let steps = Int((x - scrubTranslation) / 12)
        if steps != 0 {
            for _ in 0..<abs(steps) { engine.navigate(steps > 0 ? .right : .left) }
            scrubTranslation += CGFloat(steps) * 12
        }
        if gesture.state == .ended || gesture.state == .cancelled { isScrubbing = false; refreshContext() }
    }
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard !isEditingSnippet, alternatesPopup == nil else { return false }
        guard !UIAccessibility.isVoiceOverRunning, !UIAccessibility.isSwitchControlRunning else { return false }
        if gestureRecognizer.view is KeyButton {
            return preferences.settings.cursorScrubbing && preferences.settings.compatibility != .terminal && modifiers.isEmpty
        }
        guard preferences.settings.swipeTyping, preferences.settings.smartEditingEnabled, !numbers, !functionLayer, modifiers.isEmpty else { return false }
        let point = gestureRecognizer.location(in: self)
        return rows.flatMap { $0 }.contains { key in
            if case .text(let value) = key.action { return value.count == 1 && value.first!.isLetter && key.frame.contains(point) }
            return false
        }
    }
    /// Host-owned cursor/field changes must not carry a gesture or replacement into another input.
    func invalidateSwipeContext() {
        swipeGeneration &+= 1
        swipeTrace = []; swipePath = UIBezierPath(); swipeLayer.path = nil
        swipeAnchor = nil; swipeBounds = nil; swipeCenters = nil; swipeReplacementAnchor = nil
        swipeWords = []; lastSwipeWord = nil
    }

    private func swipeKeyCenters() -> [Character: SwipePoint] {
        guard bounds.width > 0 else { return [:] }
        var centers: [Character: SwipePoint] = [:]
        for key in rows.flatMap({ $0 }) where !key.isHidden {
            if case .text(let text) = key.action, text.count == 1,
               let letter = text.lowercased().first, letter.isLetter {
                centers[letter] = SwipePoint(x: Double(key.frame.midX / bounds.width), y: Double(key.frame.midY / bounds.width))
            }
        }
        return centers
    }

    @objc private func handleSwipe(_ gesture: UIPanGestureRecognizer) {
        guard !isEditingSnippet, preferences.settings.swipeTyping, preferences.settings.smartEditingEnabled,
              !numbers, modifiers.isEmpty, !functionLayer, bounds.width > 0, gesture.numberOfTouches <= 1 else { invalidateSwipeContext(); return }
        let point = gesture.location(in: self)
        let normalized = SwipePoint(x: Double(point.x / bounds.width), y: Double(point.y / bounds.width))
        switch gesture.state {
        case .began:
            invalidateSwipeContext()
            guard engine.document.selectedText == nil else { return }
            swipeAnchor = SwipeAnchor(engine.document)
            swipeBounds = bounds
            swipeCenters = swipeKeyCenters()
            hidePreview()
            let translation = gesture.translation(in: self)
            swipeTrace = [SwipePoint(x: Double((point.x - translation.x) / bounds.width), y: Double((point.y - translation.y) / bounds.width)), normalized]
            swipePath = UIBezierPath()
            swipePath.move(to: CGPoint(x: point.x - translation.x, y: point.y - translation.y))
            swipePath.addLine(to: point)
            swipeLayer.path = swipePath.cgPath
        case .changed:
            guard swipeBounds == bounds, swipeCenters == swipeKeyCenters(),
                  swipeAnchor?.matches(engine.document) == true else { invalidateSwipeContext(); return }
            // Long or stalled gestures must not grow an unbounded path/array.
            if swipeTrace.count >= 256 {
                swipeTrace = stride(from: 0, to: swipeTrace.count, by: 2).map { swipeTrace[$0] }
                swipePath = UIBezierPath()
                for (index, sample) in swipeTrace.enumerated() {
                    let location = CGPoint(x: sample.x * bounds.width, y: sample.y * bounds.width)
                    if index == 0 { swipePath.move(to: location) } else { swipePath.addLine(to: location) }
                }
            }
            swipeTrace.append(normalized)
            swipePath.addLine(to: point)
            swipeLayer.path = swipePath.cgPath
        case .ended:
            guard swipeBounds == bounds, let centers = swipeCenters, centers == swipeKeyCenters(),
                  swipeAnchor?.matches(engine.document) == true else { invalidateSwipeContext(); return }
            engine.invalidateAutocorrection()
            swipeTrace.append(normalized)
            if swipeDecoder == nil {
                swipeDecoder = SwipeDecoder(words: SwipeDecoder.vocabulary + preferences.settings.language.keywords)
            }
            let candidates = swipeDecoder?.candidates(trace: swipeTrace, centers: centers) ?? []
            if let word = candidates.first {
                let prefix = engine.document.contextBeforeInput(maximumCharacters: 1)?.last
                if prefix?.isLetter == true || prefix?.isNumber == true { engine.document.insert(" ") }
                let output = uppercase ? word.prefix(1).uppercased() + word.dropFirst() : word
                engine.document.insert(output); lastSwipeWord = output
                swipeWords = candidates
                swipeReplacementAnchor = SwipeAnchor(engine.document)
                if uppercase && !capsLock { uppercase = false; rebuild() }
            } else { showStatus("No swipe match") }
            swipeLayer.path = nil; swipeTrace = []; swipePath = UIBezierPath()
            swipeAnchor = nil; swipeBounds = nil; swipeCenters = nil
            refreshContext()
        case .cancelled, .failed: invalidateSwipeContext()
        default: break
        }
    }
}

private extension NavigationKey {
    static let allMenuKeys: [(NavigationKey, String)] = [(.left, "← Left"), (.right, "→ Right"), (.home, "Home"), (.end, "End"), (.up, "↑ Up"), (.down, "↓ Down"), (.pageUp, "Page Up · ANSI"), (.pageDown, "Page Down · ANSI"), (.escape, "Escape")]
}
