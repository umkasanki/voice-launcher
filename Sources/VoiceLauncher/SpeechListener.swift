import AVFoundation
import Speech

/// Listens to the default input device all the time and reports what it hears.
///
/// Recognition runs on the Mac (`requiresOnDeviceRecognition`): nothing leaves
/// the machine, and it keeps working offline. A recognition task is not meant
/// to run for ever, so the audio is cut into segments — a new task starts after
/// each command, after an error or a final result, and every `segmentLength`
/// seconds. Each segment's transcript starts empty, which is also what keeps an
/// old phrase from firing twice.
///
/// It only reads the microphone. Other applications — dictation included — keep
/// using it at the same time, and nothing here ever produces keystrokes.
@MainActor
final class SpeechListener {
    enum ListenerError: LocalizedError {
        case recognizerUnavailable

        var errorDescription: String? {
            "On-device speech recognition for Russian is not available."
        }
    }

    /// The running transcript of the current segment.
    var onTranscript: ((String) -> Void)?
    /// A segment ended with this text; used for the in-memory log.
    var onSegmentEnd: ((String) -> Void)?
    var onError: ((String) -> Void)?

    /// Phrases the recogniser should expect; improves their recognition.
    var contextualStrings: [String] = []

    private(set) var isRunning = false

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ru-RU"))
    private let engine = AVAudioEngine()
    private let sink = BufferSink()
    private var task: SFSpeechRecognitionTask?
    private var segmentID: UUID?
    private var segmentText = ""
    private var rotationTimer: Timer?
    private var configObserver: NSObjectProtocol?
    private let segmentLength: TimeInterval = 50

    static func requestPermissions() async -> Bool {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
        let microphone = await AVCaptureDevice.requestAccess(for: .audio)
        return speech && microphone
    }

    func start() throws {
        guard !isRunning else { return }
        guard let recognizer, recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else {
            throw ListenerError.recognizerUnavailable
        }
        try startEngine()
        isRunning = true
        beginSegment()

        // A microphone plugged in or out changes the input format, and the
        // engine stops. Start it again on whatever the input is now.
        configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.restartAfterDeviceChange() }
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        if let configObserver { NotificationCenter.default.removeObserver(configObserver) }
        configObserver = nil
        endSegment()
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }

    /// Drops what has been heard so far and starts listening afresh.
    func restartSegment() {
        endSegment()
        if isRunning { beginSegment() }
    }

    private func startEngine() throws {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        let sink = self.sink
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            sink.append(buffer)
        }
        engine.prepare()
        try engine.start()
    }

    private func restartAfterDeviceChange() {
        guard isRunning else { return }
        endSegment()
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        do {
            try startEngine()
            beginSegment()
        } catch {
            onError?("Microphone restart failed: \(error.localizedDescription)")
        }
    }

    private func beginSegment() {
        guard let recognizer else { return }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.addsPunctuation = false
        request.contextualStrings = contextualStrings
        sink.request = request

        let id = UUID()
        segmentID = id
        segmentText = ""
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let failed = error != nil
            DispatchQueue.main.async {
                guard let self, self.segmentID == id else { return }
                if let text {
                    self.segmentText = text
                    self.onTranscript?(text)
                }
                if isFinal {
                    self.restartSegment()
                } else if failed {
                    // Silence ends a task with an error too. Pause briefly so a
                    // recogniser that fails at once does not spin.
                    self.endSegment()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if self.isRunning && self.segmentID == nil { self.beginSegment() }
                    }
                }
            }
        }

        rotationTimer = Timer.scheduledTimer(withTimeInterval: segmentLength, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.restartSegment() }
        }
    }

    private func endSegment() {
        rotationTimer?.invalidate()
        rotationTimer = nil
        sink.request?.endAudio()
        sink.request = nil
        task?.cancel()
        task = nil
        segmentID = nil
        if !segmentText.isEmpty { onSegmentEnd?(segmentText) }
        segmentText = ""
    }
}

/// Hands audio buffers from the real-time tap thread to the current request.
private final class BufferSink: @unchecked Sendable {
    private let lock = NSLock()
    private var _request: SFSpeechAudioBufferRecognitionRequest?

    var request: SFSpeechAudioBufferRecognitionRequest? {
        get { lock.withLock { _request } }
        set { lock.withLock { _request = newValue } }
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        request?.append(buffer)
    }
}
