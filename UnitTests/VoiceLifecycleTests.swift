import Testing
@testable import ScriptKeyboard

@MainActor
struct VoiceLifecycleTests {
    @Test func stoppingWaitsForFinalTranscriptBeforeAllowingAnotherRecording() async {
        let session = TestSpeechSession()
        let recorder = makeRecorder(session: session)
        await recorder.start()
        session.emit(text: "let value", final: false)

        recorder.finishRecording()
        #expect(!recorder.isRecording)
        #expect(recorder.isFinalizing)
        #expect(session.finishCount == 1)
        #expect(session.cancelCount == 0)
        await recorder.start()
        #expect(session.startCount == 1)

        session.emit(text: "let value equals one", final: true)
        #expect(recorder.transcript == "let value equals one")
        #expect(!recorder.isFinalizing)
        #expect(!recorder.isRecording)
        #expect(session.cancelCount == 1)
        #expect(recorder.error == nil)
    }

    @Test func cancellationRejectsResultsAlreadyInFlight() async {
        let session = TestSpeechSession()
        let recorder = makeRecorder(session: session)
        await recorder.start()
        session.emit(text: "keep this partial", final: false)
        recorder.finishRecording()
        recorder.cancel()

        session.emit(text: "late final result", final: true)
        #expect(recorder.transcript == "keep this partial")
        #expect(!recorder.isFinalizing)
        #expect(!recorder.isRecording)
        #expect(session.cancelCount == 1)
    }

    @Test func recognitionErrorDuringFinalizationReleasesTheSession() async {
        let session = TestSpeechSession()
        let recorder = makeRecorder(session: session)
        await recorder.start()
        session.emit(text: "partial", final: false)
        recorder.finishRecording()
        session.emit(error: "Recognition interrupted")

        #expect(recorder.transcript == "partial")
        #expect(recorder.error == "Recognition interrupted")
        #expect(!recorder.isFinalizing)
        #expect(session.cancelCount == 1)
    }

    @Test func finalizationHasABoundedTimeoutAndKeepsPartialText() async {
        let session = TestSpeechSession()
        let cancelled = TestSignal()
        session.onCancel = { cancelled.signal() }
        let recorder = makeRecorder(session: session, timeout: .zero)
        await recorder.start()
        session.emit(text: "partial", final: false)
        recorder.finishRecording()
        await cancelled.wait()

        #expect(!recorder.isFinalizing)
        #expect(recorder.transcript == "partial")
        #expect(recorder.error?.contains("didn’t finish in time") == true)
        session.emit(text: "too late", final: true)
        #expect(recorder.transcript == "partial")
    }

    @Test func cancellationWhileSpeechPermissionIsPendingCannotStartCapture() async {
        let speech = TestPermission()
        let session = TestSpeechSession()
        var microphoneRequests = 0
        let recorder = SpeechRecorder(authorizeSpeech: { await speech.request() }, authorizeMicrophone: {
            microphoneRequests += 1
            return true
        }, makeSession: { session.onUpdate = $0; return session })
        let start = Task { await recorder.start() }
        await speech.requested.wait()
        recorder.cancel()
        speech.resolve(true)
        await start.value

        #expect(!recorder.isPreparing)
        #expect(!recorder.isRecording)
        #expect(microphoneRequests == 0)
        #expect(session.startCount == 0)
    }

    @Test func cancellationWhileMicrophonePermissionIsPendingIgnoresLateDenial() async {
        let microphone = TestPermission()
        let session = TestSpeechSession()
        let recorder = SpeechRecorder(authorizeSpeech: { true }, authorizeMicrophone: {
            await microphone.request()
        }, makeSession: { session.onUpdate = $0; return session })
        let start = Task { await recorder.start() }
        await microphone.requested.wait()
        recorder.cancel()
        microphone.resolve(false)
        await start.value

        #expect(!recorder.isPreparing)
        #expect(!recorder.isRecording)
        #expect(session.startCount == 0)
        #expect(recorder.error == nil)
    }

    @Test func anOldPermissionResponseCannotClearANewerPreparingState() async {
        let first = TestPermission()
        let second = TestPermission()
        let session = TestSpeechSession()
        var requests = 0
        let recorder = SpeechRecorder(authorizeSpeech: {
            requests += 1
            return await (requests == 1 ? first : second).request()
        }, authorizeMicrophone: { true }, makeSession: { session.onUpdate = $0; return session })
        let firstStart = Task { await recorder.start() }
        await first.requested.wait()
        recorder.cancel()
        let secondStart = Task { await recorder.start() }
        await second.requested.wait()
        first.resolve(true)
        await firstStart.value

        #expect(recorder.isPreparing)
        #expect(session.startCount == 0)
        recorder.cancel()
        second.resolve(true)
        await secondStart.value
        #expect(!recorder.isPreparing)
        #expect(session.startCount == 0)
    }

    @Test func failedAudioStartCancelsResourcesAndRejectsLateRecognition() async {
        let session = TestSpeechSession()
        session.failStart = true
        let recorder = makeRecorder(session: session)
        await recorder.start()

        #expect(session.cancelCount == 1)
        #expect(!recorder.isPreparing)
        #expect(!recorder.isRecording)
        #expect(recorder.error != nil)
        session.emit(text: "result from failed capture", final: true)
        #expect(recorder.transcript.isEmpty)
    }

    private func makeRecorder(session: TestSpeechSession, timeout: Duration = .seconds(8)) -> SpeechRecorder {
        SpeechRecorder(authorizeSpeech: { true }, authorizeMicrophone: { true }, makeSession: {
            session.onUpdate = $0
            return session
        }, finalizationTimeout: timeout)
    }
}

@MainActor
private final class TestSpeechSession: SpeechCaptureSession {
    var onUpdate: SpeechRecorder.ResultHandler?
    var onCancel: (() -> Void)?
    var failStart = false
    var startCount = 0
    var finishCount = 0
    var cancelCount = 0
    func start() throws {
        startCount += 1
        if failStart { throw TestAudioError() }
    }
    func finish() { finishCount += 1 }
    func cancel() { cancelCount += 1; onCancel?() }
    func emit(text: String? = nil, final: Bool = false, error: String? = nil) {
        onUpdate?(SpeechRecognitionUpdate(text: text, isFinal: final, error: error))
    }
    private struct TestAudioError: Error {}
}

@MainActor
private final class TestSignal {
    private var signalled = false
    private var continuation: CheckedContinuation<Void, Never>?
    func wait() async {
        guard !signalled else { return }
        await withCheckedContinuation { continuation = $0 }
    }
    func signal() {
        signalled = true
        continuation?.resume(); continuation = nil
    }
}

@MainActor
private final class TestPermission {
    let requested = TestSignal()
    private var continuation: CheckedContinuation<Bool, Never>?
    func request() async -> Bool {
        await withCheckedContinuation {
            continuation = $0
            requested.signal()
        }
    }
    func resolve(_ granted: Bool) {
        continuation?.resume(returning: granted); continuation = nil
    }
}
