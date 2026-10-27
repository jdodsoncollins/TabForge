import UIKit
import Testing
import KeyboardCore
@testable import ScriptKeyboard

/// Exercises the shared renderer's gesture handler with synthetic paths through its actual key
/// frames. A test recognizer does not establish physical multitouch or palm-rejection behavior.
@Suite @MainActor
struct KeyboardSwipeTests {
    private final class TestPan: UIPanGestureRecognizer {
        var sampleState: UIGestureRecognizer.State = .possible
        var samplePoint = CGPoint.zero
        var origin = CGPoint.zero
        var sampleTouches = 1

        override var state: UIGestureRecognizer.State {
            get { sampleState }
            set { sampleState = newValue }
        }
        override var numberOfTouches: Int { sampleTouches }
        override func location(in view: UIView?) -> CGPoint { samplePoint }
        override func translation(in view: UIView?) -> CGPoint {
            CGPoint(x: samplePoint.x - origin.x, y: samplePoint.y - origin.y)
        }
    }

    @MainActor private final class ObservedDocument: TextDocument {
        let buffer = MemoryDocument(text: "seed\n")
        var replacementCalls: [(String, String)] = []
        var insertCalls = 0
        var deleteCalls = 0
        var text: String { buffer.text }
        var before: String? { buffer.before }
        var after: String? { buffer.after }
        var selectedText: String? { buffer.selectedText }
        var hasCompleteContext: Bool { true }
        var autocorrectionContextIdentifier: UUID? { buffer.autocorrectionContextIdentifier }
        func contextBeforeInput(maximumCharacters: Int) -> String? { buffer.contextBeforeInput(maximumCharacters: maximumCharacters) }
        func contextAfterInput(maximumCharacters: Int) -> String? { buffer.contextAfterInput(maximumCharacters: maximumCharacters) }
        func insert(_ text: String) { insertCalls += 1; buffer.insert(text) }
        func deleteBackward() { deleteCalls += 1; buffer.deleteBackward() }
        func move(by offset: Int) { buffer.move(by: offset) }
        func replaceTextBeforeCursor(_ expected: String, with replacement: String) -> Bool {
            replacementCalls.append((expected, replacement))
            return buffer.replaceTextBeforeCursor(expected, with: replacement)
        }
        func resetCalls() { replacementCalls = []; insertCalls = 0; deleteCalls = 0 }
    }

    private struct Fixture {
        let keyboard: CodingKeyboardView
        let preferences: PreferencesStore
        let document: ObservedDocument
        let pan: TestPan
        let path: [CGPoint]
    }

    @Test(arguments: [
        CGSize(width: 320, height: 700),
        CGSize(width: 760, height: 350),
        CGSize(width: 834, height: 1194),
        CGSize(width: 669, height: 951),
        CGSize(width: 951, height: 669)
    ])
    func testingUsesActualLetterFramesAcrossAdaptiveLayouts(_ host: CGSize) throws {
        let fixture = try make(host: host)
        #expect(fixture.keyboard.gestureRecognizerShouldBegin(fixture.pan))
        start(fixture)
        finish(fixture)
        #expect(fixture.document.text == "seed\ntesting")
    }

    @Test func swipeRemainsOptIn() throws {
        let fixture = try make()
        fixture.preferences.settings.swipeTyping = false
        fixture.keyboard.applySettings()
        #expect(!fixture.keyboard.gestureRecognizerShouldBegin(fixture.pan))
        // Even a stale recognizer callback must respect the setting.
        start(fixture)
        finish(fixture)
        #expect(fixture.document.text == "seed\n")
    }

    @Test func disablingSwipeDuringGestureCannotCommitAStaleWord() throws {
        let fixture = try make()
        start(fixture)
        fixture.preferences.settings.swipeTyping = false
        fixture.keyboard.applySettings()
        finish(fixture)
        #expect(fixture.document.text == "seed\n")
    }

    @Test func switchingToTerminalDuringGestureCannotCommitAStaleWord() throws {
        let fixture = try make()
        start(fixture)
        fixture.preferences.settings.compatibility = .terminal
        fixture.keyboard.applySettings()
        finish(fixture)
        #expect(fixture.document.text == "seed\n")
    }

    @Test func dismissalThenLateEndedCallbackCannotCommit() throws {
        let fixture = try make()
        start(fixture)
        fixture.keyboard.releaseTransientResources()
        finish(fixture)
        #expect(fixture.document.text == "seed\n")
    }

    @Test func resizingDuringGestureCannotCommitAgainstDifferentKeys() throws {
        let fixture = try make()
        start(fixture)
        layout(fixture.keyboard, in: CGSize(width: 760, height: 350))
        finish(fixture)
        #expect(fixture.document.text == "seed\n")
    }

    @Test func movingKeysWithoutResizingCannotCommitAgainstOldGeometry() throws {
        let fixture = try make()
        start(fixture)
        let bounds = fixture.keyboard.bounds
        let key = try #require(fixture.keyboard.subviews.compactMap { $0 as? UIButton }.first {
            $0.accessibilityIdentifier == "key.g"
        })
        // Simulate a key shift from a safe-area/fold change without changing the input-view bounds.
        key.frame.origin.x += 8
        finish(fixture)
        #expect(fixture.keyboard.bounds == bounds)
        #expect(fixture.document.text == "seed\n")
    }

    @Test func secondFingerCancelsTheWholeGesture() throws {
        let fixture = try make()
        let recognizers = fixture.keyboard.gestureRecognizers?.compactMap { $0 as? UIPanGestureRecognizer } ?? []
        let installed = try #require(recognizers.first { $0 !== fixture.pan })
        #expect(installed.maximumNumberOfTouches == 1)
        start(fixture)
        send(fixture.pan, to: fixture.keyboard, state: .changed, point: fixture.path[fixture.path.count / 2], touches: 2)
        finish(fixture)
        #expect(fixture.document.text == "seed\n")
    }

    @Test func cancellationAndFailureIgnoreLateCallbacks() throws {
        for state in [UIGestureRecognizer.State.cancelled, .failed] {
            let fixture = try make()
            start(fixture)
            send(fixture.pan, to: fixture.keyboard, state: state, point: fixture.path[2], touches: 0)
            finish(fixture)
            #expect(fixture.document.text == "seed\n")
        }
    }

    @Test func changedHostTextDoesNotReceiveAWordStartedElsewhere() throws {
        let fixture = try make()
        start(fixture)
        fixture.document.insert("external")
        finish(fixture)
        #expect(fixture.document.text == "seed\nexternal")
    }

    @Test func selectedHostTextIsPreservedAndCollapsedCursorCanSwipe() throws {
        let fixture = try make()
        fixture.document.buffer.selection = NSRange(location: 0, length: 4)
        fixture.document.resetCalls()
        start(fixture); finish(fixture)
        #expect(fixture.document.text == "seed\n")
        #expect(fixture.document.buffer.selection == NSRange(location: 0, length: 4))
        #expect(fixture.document.insertCalls == 0)
        #expect(fixture.document.deleteCalls == 0)
        fixture.document.buffer.selection = NSRange(location: fixture.document.text.utf16.count, length: 0)
        start(fixture); finish(fixture)
        #expect(fixture.document.text == "seed\ntesting")
    }

    @Test func hostCallbackInvalidatesOldGestureAndAllowsTheNextOne() throws {
        let fixture = try make()
        start(fixture)
        fixture.keyboard.invalidateSwipeContext()
        finish(fixture)
        #expect(fixture.document.text == "seed\n")
        start(fixture)
        finish(fixture)
        #expect(fixture.document.text == "seed\ntesting")
    }

    @Test func immediateAlternativesUseOneVerifiedReplacementEach() throws {
        let fixture = try make()
        start(fixture); finish(fixture)
        let alternative = try alternative(in: fixture.keyboard)
        fixture.document.resetCalls()
        invoke(alternative)
        #expect(fixture.document.text == "seed\n" + alternative.title)
        #expect(fixture.document.replacementCalls.count == 1)
        #expect(fixture.document.replacementCalls.first?.0 == "testing")
        #expect(fixture.document.replacementCalls.first?.1 == alternative.title)
        #expect(fixture.document.insertCalls == 0)
        #expect(fixture.document.deleteCalls == 0)
        let refreshed = try suggestionsMenu("Swipe alternatives", in: fixture.keyboard)
        let original = try #require(refreshed.children.compactMap { $0 as? UIAction }.first { $0.title == "testing" })
        fixture.document.resetCalls()
        invoke(original)
        #expect(fixture.document.text == "seed\ntesting")
        #expect(fixture.document.replacementCalls.count == 1)
        #expect(fixture.document.replacementCalls.first?.0 == alternative.title)
        #expect(fixture.document.replacementCalls.first?.1 == "testing")
        #expect(fixture.document.insertCalls == 0)
        #expect(fixture.document.deleteCalls == 0)
    }

    @Test func repeatedIdenticalSwipesRefreshTheAlternativeActions() throws {
        let fixture = try make()
        start(fixture); finish(fixture)
        start(fixture); finish(fixture)
        #expect(fixture.document.text == "seed\ntesting testing")
        let replacement = try alternative(in: fixture.keyboard)
        fixture.document.resetCalls()
        invoke(replacement)
        #expect(fixture.document.text == "seed\ntesting " + replacement.title)
        #expect(fixture.document.replacementCalls.count == 1)
    }

    @Test func nativeEditorKeepsAlternativesThroughVerifiedReplacementCallbacks() async throws {
        let preferences = PreferencesStore(local: nil)
        preferences.settings.swipeTyping = true
        preferences.settings.haptics = false
        preferences.settings.keyClicks = false
        let host = EditorHostView(preferences: preferences, openSettings: {})
        let controller = UIViewController()
        controller.view = host
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKeyWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer {
            host.textView.resignFirstResponder()
            host.keyboard.releaseTransientResources()
            window.isHidden = true
            previousKeyWindow?.makeKeyAndVisible()
        }
        host.synchronize(text: "seed\n", language: .swift)
        #expect(host.textView.becomeFirstResponder())
        try await Task.sleep(for: .milliseconds(100))
        window.layoutIfNeeded()
        host.keyboard.superview?.layoutIfNeeded()
        try swipe(in: host.keyboard)
        #expect(host.textView.text == "seed\ntesting")
        let replacement = try alternative(in: host.keyboard, context: "after the native swipe")
        invoke(replacement)
        #expect(host.textView.text == "seed\n" + replacement.title)
        try await Task.sleep(for: .milliseconds(50))
        let refreshed = try suggestionsMenu("Swipe alternatives", in: host.keyboard, context: "after the native replacement")
        let original = try #require(refreshed.children.compactMap { $0 as? UIAction }.first { $0.title == "testing" })
        invoke(original)
        #expect(host.textView.text == "seed\ntesting")
    }

    @Test func regularCodeSuggestionsStillCompleteTheCurrentPrefix() throws {
        let fixture = try make()
        fixture.document.insert("pri")
        fixture.keyboard.refreshContext()
        let menu = try suggestionsMenu("Code suggestions", in: fixture.keyboard)
        let action = try #require(menu.children.compactMap { $0 as? UIAction }.first { $0.title == "print" })
        invoke(action)
        #expect(fixture.document.text == "seed\nprint")
    }

    @Test(arguments: [false, true])
    func staleAlternativeCannotReplaceSameSuffixInAnotherContext(_ receivesHostCallback: Bool) throws {
        let fixture = try make()
        start(fixture); finish(fixture)
        let retainedAction = try alternative(in: fixture.keyboard)
        fixture.document.insert("\nelsewhere testing")
        if receivesHostCallback { fixture.keyboard.invalidateSwipeContext() }
        let expected = fixture.document.text
        fixture.document.resetCalls()
        invoke(retainedAction)
        #expect(fixture.document.text == expected)
        #expect(fixture.document.replacementCalls.isEmpty)
        #expect(fixture.document.insertCalls == 0)
        #expect(fixture.document.deleteCalls == 0)
    }

    @Test func cursorChangeWithTheSameWordCannotReuseAnOldAlternative() throws {
        let fixture = try make()
        fixture.document.insert("testing\n")
        start(fixture); finish(fixture)
        let retainedAction = try alternative(in: fixture.keyboard)
        fixture.document.move(by: -"\ntesting".utf16.count)
        let expected = fixture.document.text
        fixture.document.resetCalls()
        invoke(retainedAction)
        #expect(fixture.document.text == expected)
        #expect(fixture.document.replacementCalls.isEmpty)
        #expect(fixture.document.insertCalls == 0)
        #expect(fixture.document.deleteCalls == 0)
    }

    @Test func cursorScrubbingInvalidatesAlternativesWhenRepeatingAnchorsMatch() throws {
        let fixture = try make()
        fixture.document.buffer.selection = NSRange(location: 0, length: fixture.document.text.utf16.count)
        fixture.document.buffer.insert(String(repeating: "testing ", count: 30))
        fixture.document.buffer.selection = NSRange(location: 79, length: 0)
        start(fixture); finish(fixture)
        #expect(fixture.document.buffer.cursor == 87)
        let retainedAction = try alternative(in: fixture.keyboard)
        let expected = fixture.document.text
        let scrub = TestPan(target: nil, action: nil)
        scrub.sampleState = .began
        _ = fixture.keyboard.perform(NSSelectorFromString("scrubCursor:"), with: scrub)
        scrub.sampleState = .changed
        scrub.samplePoint = CGPoint(x: -96, y: 0)
        _ = fixture.keyboard.perform(NSSelectorFromString("scrubCursor:"), with: scrub)
        scrub.sampleState = .ended
        _ = fixture.keyboard.perform(NSSelectorFromString("scrubCursor:"), with: scrub)
        #expect(fixture.document.buffer.cursor == 79)
        fixture.document.resetCalls()
        invoke(retainedAction)
        #expect(fixture.document.text == expected)
        #expect(fixture.document.replacementCalls.isEmpty)
        #expect(fixture.document.insertCalls == 0)
        #expect(fixture.document.deleteCalls == 0)
    }

    private func make(host: CGSize = CGSize(width: 390, height: 844)) throws -> Fixture {
        let preferences = PreferencesStore(local: nil)
        preferences.settings.swipeTyping = true
        preferences.settings.haptics = false
        preferences.settings.keyClicks = false
        let document = ObservedDocument()
        let keyboard = CodingKeyboardView(document: document, preferences: preferences)
        layout(keyboard, in: host)
        let path = try swipePath(in: keyboard)
        let pan = TestPan(target: nil, action: nil)
        pan.origin = path[0]
        pan.samplePoint = path[0]
        pan.maximumNumberOfTouches = 1
        keyboard.addGestureRecognizer(pan)
        return Fixture(keyboard: keyboard, preferences: preferences, document: document, pan: pan, path: path)
    }

    private func swipePath(in keyboard: CodingKeyboardView) throws -> [CGPoint] {
        let vertices = try "testing".map { letter in
            let key = try #require(keyboard.subviews.compactMap { $0 as? UIButton }.first {
                !$0.isHidden && $0.accessibilityIdentifier == "key.\(letter)"
            })
            #expect(key.frame.width > 0 && key.frame.height > 0)
            return CGPoint(x: key.frame.midX, y: key.frame.midY)
        }
        var path = [try #require(vertices.first)]
        for (a, b) in zip(vertices, vertices.dropFirst()) {
            for step in 1...8 {
                let fraction = CGFloat(step) / 8
                path.append(CGPoint(x: a.x + (b.x - a.x) * fraction, y: a.y + (b.y - a.y) * fraction))
            }
        }
        return path
    }

    private func swipe(in keyboard: CodingKeyboardView) throws {
        let path = try swipePath(in: keyboard)
        let pan = TestPan(target: nil, action: nil)
        pan.origin = path[0]
        pan.maximumNumberOfTouches = 1
        keyboard.addGestureRecognizer(pan)
        defer { keyboard.removeGestureRecognizer(pan) }
        send(pan, to: keyboard, state: .began, point: path[1])
        for point in path.dropFirst(2).dropLast() {
            send(pan, to: keyboard, state: .changed, point: point)
        }
        send(pan, to: keyboard, state: .ended, point: path.last!, touches: 0)
    }

    private func layout(_ keyboard: CodingKeyboardView, in host: CGSize) {
        keyboard.availableHostSize = host
        keyboard.frame = CGRect(origin: .zero, size: CGSize(width: host.width, height: keyboard.desiredHeight))
        keyboard.layoutIfNeeded()
        keyboard.frame.size.height = keyboard.desiredHeight
        keyboard.layoutIfNeeded()
    }

    private func alternative(in keyboard: CodingKeyboardView, context: String = "") throws -> UIAction {
        let alternatives = try suggestionsMenu("Swipe alternatives", in: keyboard, context: context)
        return try #require(alternatives.children.compactMap { $0 as? UIAction }.first { $0.title != "testing" })
    }

    private func suggestionsMenu(_ title: String, in keyboard: CodingKeyboardView, context: String = "") throws -> UIMenu {
        let toolbar = try #require(keyboard.subviews.first { $0.accessibilityIdentifier == "keyboard.toolbar" })
        let gear = try #require(toolbar.subviews.compactMap { $0 as? UIButton }.first {
            $0.accessibilityIdentifier == "keyboard.quickSettings"
        })
        return try #require(gear.menu?.children.compactMap { $0 as? UIMenu }.first {
            $0.title == title
        }, Comment(rawValue: "Missing \(title) \(context); available menus: \(gear.menu?.children.map(\.title) ?? [])"))
    }

    private func invoke(_ action: UIAction) {
        let button = UIButton()
        button.addAction(action, for: .primaryActionTriggered)
        button.sendActions(for: .primaryActionTriggered)
    }

    private func start(_ fixture: Fixture) {
        send(fixture.pan, to: fixture.keyboard, state: .began, point: fixture.path[1])
        for point in fixture.path.dropFirst(2).prefix(fixture.path.count / 2 - 2) {
            send(fixture.pan, to: fixture.keyboard, state: .changed, point: point)
        }
    }

    private func finish(_ fixture: Fixture) {
        for point in fixture.path.dropFirst(fixture.path.count / 2).dropLast() {
            send(fixture.pan, to: fixture.keyboard, state: .changed, point: point)
        }
        send(fixture.pan, to: fixture.keyboard, state: .ended, point: fixture.path.last!, touches: 0)
    }

    private func send(_ pan: TestPan, to keyboard: CodingKeyboardView, state: UIGestureRecognizer.State,
                      point: CGPoint, touches: Int = 1) {
        pan.sampleState = state
        pan.samplePoint = point
        pan.sampleTouches = touches
        _ = keyboard.perform(NSSelectorFromString("handleSwipe:"), with: pan)
    }
}
