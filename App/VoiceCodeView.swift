import SwiftUI
@preconcurrency import Speech
@preconcurrency import AVFoundation

struct SpeechRecognitionUpdate: Sendable {
    var text: String?
    var isFinal = false
    var error: String?
}

@MainActor
protocol SpeechCaptureSession: AnyObject {
    func start() throws
    func finish()
    func cancel()
}

@MainActor @Observable
final class SpeechRecorder {
    typealias ResultHandler = @MainActor @Sendable (SpeechRecognitionUpdate) -> Void
    typealias SessionFactory = (@escaping ResultHandler) throws -> any SpeechCaptureSession

    var transcript = ""
    private(set) var isRecording = false
    private(set) var isPreparing = false
    private(set) var isFinalizing = false
    var error: String?
    @ObservationIgnored private let authorizeSpeech: () async -> Bool
    @ObservationIgnored private let authorizeMicrophone: () async -> Bool
    @ObservationIgnored private let makeSession: SessionFactory
    @ObservationIgnored private let finalizationTimeout: Duration
    @ObservationIgnored private var session: (any SpeechCaptureSession)?
    @ObservationIgnored private var finalizationTask: Task<Void, Never>?
    @ObservationIgnored private var generation = 0

    init(
        authorizeSpeech: @escaping () async -> Bool = {
            await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
            }
        },
        authorizeMicrophone: @escaping () async -> Bool = { await AVAudioApplication.requestRecordPermission() },
        makeSession: @escaping SessionFactory = { try OnDeviceSpeechSession(onUpdate: $0) },
        finalizationTimeout: Duration = .seconds(8)
    ) {
        self.authorizeSpeech = authorizeSpeech
        self.authorizeMicrophone = authorizeMicrophone
        self.makeSession = makeSession
        self.finalizationTimeout = finalizationTimeout
    }

    func start() async {
        guard !isPreparing, !isRecording, !isFinalizing else { return }
        isPreparing = true; error = nil
        generation += 1
        let activeGeneration = generation
        defer { if generation == activeGeneration { isPreparing = false } }
        let speechAllowed = await authorizeSpeech()
        guard generation == activeGeneration, !Task.isCancelled else { return }
        guard speechAllowed else { error = "Enable Speech Recognition for TabForge in Settings to use voice input."; return }
        let micAllowed = await authorizeMicrophone()
        guard generation == activeGeneration, !Task.isCancelled else { return }
        guard micAllowed else { error = "Enable microphone access for TabForge in Settings to record speech."; return }
        do {
            session = try makeSession { [weak self] update in
                guard let self, self.generation == activeGeneration else { return }
                if let text = update.text { self.transcript = text }
                if update.isFinal { self.cancel() }
                else if let message = update.error { self.cancel(); self.error = message }
            }
            transcript = ""
            isRecording = true
            try session?.start()
        } catch {
            cancel()
            self.error = (error as? VoiceSetupError)?.errorDescription
                ?? "Couldn’t start the microphone. Check audio input and try again."
        }
    }

    func finishRecording() {
        guard isRecording else { return }
        isRecording = false
        isFinalizing = true
        let activeGeneration = generation
        let timeout = finalizationTimeout
        finalizationTask = Task { [weak self] in
            do { try await Task.sleep(for: timeout) }
            catch { return }
            guard let self, self.generation == activeGeneration, self.isFinalizing else { return }
            self.cancel()
            self.error = "Speech recognition didn’t finish in time. Review the partial transcript or record again."
        }
        // Keep the recognition task and generation alive for its final result.
        session?.finish()
    }

    func cancel() {
        generation += 1
        isPreparing = false
        isRecording = false
        isFinalizing = false
        finalizationTask?.cancel(); finalizationTask = nil
        session?.cancel(); session = nil
    }
}

private enum VoiceSetupError: LocalizedError {
    case unavailable, noAudio
    var errorDescription: String? {
        switch self {
        case .unavailable:
            "On-device English speech recognition isn’t available here. Try an iPhone or iPad with the speech language downloaded."
        case .noAudio:
            "No microphone input is available. Check audio input and try again."
        }
    }
}

@MainActor
private final class OnDeviceSpeechSession: SpeechCaptureSession {
    private let engine = AVAudioEngine()
    private let recognizer: SFSpeechRecognizer
    private let request = SFSpeechAudioBufferRecognitionRequest()
    private let onUpdate: SpeechRecorder.ResultHandler
    private var task: SFSpeechRecognitionTask?
    private var hasTap = false
    private var audioSessionActive = false

    init(onUpdate: @escaping SpeechRecorder.ResultHandler) throws {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")), recognizer.isAvailable,
              recognizer.supportsOnDeviceRecognition else { throw VoiceSetupError.unavailable }
        self.recognizer = recognizer
        self.onUpdate = onUpdate
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
    }

    func start() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true)
        audioSessionActive = true
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw VoiceSetupError.noAudio }
        let request = request
        try input.installAudioTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(AVAudioPCMBuffer(copying: buffer))
        }
        hasTap = true
        let onUpdate = onUpdate
        task = recognizer.recognitionTask(with: request) { result, error in
            let update = SpeechRecognitionUpdate(text: result?.bestTranscription.formattedString,
                                                 isFinal: result?.isFinal == true,
                                                 error: error?.localizedDescription)
            Task { @MainActor in onUpdate(update) }
        }
        engine.prepare()
        try engine.start()
    }

    func finish() {
        stopAudio()
        request.endAudio()
    }

    func cancel() {
        stopAudio()
        request.endAudio()
        task?.cancel(); task = nil
    }

    private func stopAudio() {
        engine.stop()
        if hasTap { engine.inputNode.removeTap(onBus: 0); hasTap = false }
        if audioSessionActive {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            audioSessionActive = false
        }
    }
}

struct VoiceCodeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var recorder = SpeechRecorder()
    @State private var convertSymbols = true
    var insert: (String) -> Void
    private var result: String { convertSymbols ? SpokenCode.convert(recorder.transcript) : recorder.transcript }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("Say it. Review it. Insert it.", systemImage: "waveform").font(.headline)
                    Text("English speech is transcribed on device. Try “open brace”, “new line”, “tab”, or “semicolon”.").font(.subheadline).foregroundStyle(.secondary)
                    Button {
                        if recorder.isRecording { recorder.finishRecording() }
                        else { Task { await recorder.start() } }
                    } label: {
                        Label(recorder.isRecording ? "Stop recording" : recorder.isPreparing ? "Preparing…" : recorder.isFinalizing ? "Finishing transcription…" : "Start recording", systemImage: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent).disabled(recorder.isPreparing || recorder.isFinalizing)
                    .accessibilityIdentifier("voice.record")
                    if let error = recorder.error { Text(error).font(.footnote).foregroundStyle(.red) }
                }
                Section("Transcript") {
                    TextEditor(text: $recorder.transcript).frame(minHeight: 120)
                        .autocorrectionDisabled().textInputAutocapitalization(.never)
                        .accessibilityLabel("Transcript")
                        .disabled(recorder.isPreparing || recorder.isRecording || recorder.isFinalizing)
                    Toggle("Convert spoken punctuation", isOn: $convertSymbols)
                }
                Section("Code preview") {
                    Text(result.isEmpty ? "Your code will appear here." : result)
                        .font(.system(.body, design: .monospaced)).textSelection(.enabled)
                        .foregroundStyle(result.isEmpty ? .secondary : .primary)
                }
            }
            .navigationTitle("Voice to code").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { recorder.cancel(); dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Insert") { recorder.cancel(); insert(result); dismiss() }
                        .disabled(result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || recorder.isRecording || recorder.isPreparing || recorder.isFinalizing)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.didBecomeInactiveNotification)) { notification in
                if let context = notification.userInfo?[AVAudioSession.deactivationContextKey] as? AVAudioSession.DeactivationContext,
                   context.source == .system { recorder.cancel() }
            }
            .onDisappear { recorder.cancel() }
            .onChange(of: scenePhase) { _, phase in if phase != .active { recorder.cancel() } }
        }
    }
}

enum SpokenCode {
    static func convert(_ text: String) -> String {
        let symbols: [(String, String)] = [
            ("open angle bracket", "<"), ("close angle bracket", ">"),
            ("open square bracket", "["), ("close square bracket", "]"),
            ("open parenthesis", "("), ("close parenthesis", ")"),
            ("open bracket", "["), ("close bracket", "]"),
            ("open brace", "{"), ("close brace", "}"),
            ("double quote", "\""), ("single quote", "'"),
            ("new line", "\n"), ("semicolon", ";"), ("colon", ":"),
            ("underscore", "_"), ("backtick", "`"), ("equals", "="),
            ("ampersand", "&"), ("pipe", "|"), ("tab", "\t")
        ]
        return symbols.reduce(text) { result, entry in
            result.replacingOccurrences(of: "\\b" + entry.0 + "\\b", with: entry.1, options: [.regularExpression, .caseInsensitive])
        }.replacingOccurrences(of: " *\n *", with: "\n", options: .regularExpression)
    }
}
