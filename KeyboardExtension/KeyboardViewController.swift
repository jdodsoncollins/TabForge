import UIKit

@MainActor
final class KeyboardViewController: UIInputViewController {
    private var keyboard: CodingKeyboardView!
    private var preferences: PreferencesStore!
    private var heightConstraint: NSLayoutConstraint?
    private var lexiconTask: Task<Void, Never>?

    override func loadView() {
        // A custom input view adopts UIInputViewAudioFeedback for key clicks.
        let input = KeyClickInputView(frame: .zero, inputViewStyle: .keyboard)
        input.clicksEnabled = { [weak self] in self?.preferences?.settings.keyClicks ?? false }
        view = input
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        inputView?.allowsSelfSizing = true
        inputView?.autoresizingMask = [.flexibleWidth]
        // Leave the system-provided dictation key enabled; recording is not permitted here.
        hasDictationKey = false
        primaryLanguage = "en-US"
        preferences = PreferencesStore()
        keyboard = CodingKeyboardView(document: ProxyDocument(self), preferences: preferences)
        keyboard.requiresSupplementaryLexicon = true
        keyboard.needsGlobe = needsInputModeSwitchKey
        keyboard.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(keyboard)
        NSLayoutConstraint.activate([
            keyboard.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboard.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboard.topAnchor.constraint(equalTo: view.topAnchor),
            keyboard.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        let constraint = view.heightAnchor.constraint(equalToConstant: keyboard.desiredHeight)
        constraint.priority = .required
        constraint.isActive = true
        heightConstraint = constraint
        keyboard.onHeightChange = { [weak self] height in
            guard let self, self.heightConstraint?.constant != height else { return }
            self.heightConstraint?.constant = height
            self.inputView?.invalidateIntrinsicContentSize()
            self.view.setNeedsLayout()
        }
        keyboard.onInputModeEvent = { [weak self] sender, event in self?.handleInputModeList(from: sender, with: event) }
        keyboard.onNextKeyboard = { [weak self] in self?.advanceToNextInputMode() }
        keyboard.onDismiss = { [weak self] in self?.dismissKeyboard() }
        keyboard.onPrepareAutocorrection = { [weak self] in self?.prepareAutocorrection() }
        keyboard.onSnippetEditingChanged = { [weak self] editing in
            guard let self else { return }
            if editing {
                self.lexiconTask?.cancel()
                self.lexiconTask = nil
            } else {
                self.prepareAutocorrection()
            }
        }
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        preferences.refresh()
        keyboard.applySettings()
        // Reopening can attach to a different field without a settings change.
        keyboard.hostContextDidChange()
        prepareAutocorrection()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        prepareAutocorrection()
        keyboard.showNextTipIfNeeded()
    }
    override func textDidChange(_ textInput: (any UITextInput)?) {
        super.textDidChange(textInput)
        keyboard?.hostContextDidChange()
    }
    override func textWillChange(_ textInput: (any UITextInput)?) {
        super.textWillChange(textInput)
        keyboard?.engine.invalidateAutocorrection()
        keyboard?.invalidateSwipeContext()
    }
    override func selectionWillChange(_ textInput: (any UITextInput)?) {
        super.selectionWillChange(textInput)
        // UITextInputDelegate reports host-owned changes, such as a tap moving
        // the cursor. A prior correction must never follow the user elsewhere.
        keyboard?.engine.invalidateAutocorrection()
        keyboard?.invalidateSwipeContext()
    }
    override func selectionDidChange(_ textInput: (any UITextInput)?) {
        super.selectionDidChange(textInput)
        keyboard?.hostContextDidChange()
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        keyboard?.releaseTransientResources()
        lexiconTask?.cancel(); lexiconTask = nil
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        keyboard?.releaseTransientResources()
        lexiconTask?.cancel(); lexiconTask = nil
    }
    private func prepareAutocorrection() {
        guard preferences.settings.autocorrectProse, lexiconTask == nil,
              keyboard.window != nil, !keyboard.isEditingSnippet else { return }
        lexiconTask = Task { [weak self] in
            guard let self else { return }
            defer { if !Task.isCancelled { self.lexiconTask = nil } }
            guard !Task.isCancelled, self.preferences.settings.autocorrectProse,
                  self.keyboard.window != nil, !self.keyboard.isEditingSnippet else { return }
            let lexicon = await self.requestSupplementaryLexicon()
            guard !Task.isCancelled, self.preferences.settings.autocorrectProse,
                  self.keyboard.window != nil, !self.keyboard.isEditingSnippet else { return }
            self.keyboard.useSupplementaryLexicon(lexicon)
        }
    }
}
