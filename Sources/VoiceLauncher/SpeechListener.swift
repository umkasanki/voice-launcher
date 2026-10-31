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
        case noMicrophone

        var errorDescription: String? {
            switch self {
            case .recognizerUnavailable: return "On-device speech recognition for Russian is not available."
            case .noMicrophone: return "No microphone is connected."
            }
        }
    }

    /// The running transcript of the current segment.
    var onTranscript: ((String) -> Void)?
    /// A segment ended with this text; used for the in-memory log.
    var onSegmentEnd: ((String) -> Void)?
    var onError: ((String) -> Void)?
    /// Audio is flowing again after `onError` reported a problem.
    var onRecovered: (() -> Void)?

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
    private var retryTimer: Timer?
    private var microphoneObserver: NSObjectProtocol?
    private var microphoneAttempts = 0
    private var segmentStart = Date()
    private var quickFailures = 0
    private var hasProblem = false
    private let segmentLength: TimeInterval = 50
    /// A task that fails this soon after starting is a failure, not silence.
    private let quickFailureWindow: TimeInterval = 1
    private let microphoneRetryInterval: TimeInterval = 3
    /// Tries this many times, then waits for macOS to report a new microphone
    /// instead of polling for ever.
    private let microphoneRetryLimit = 5

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
        isRunning = true
        startAudio()

        // A microphone plugged in or out changes the input format, and the
        // engine stops. Start it again on whatever the input is now.
        configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.restartAfterDeviceChange() }
        }
        // Wakes the listener after it has given up waiting for a microphone.
        microphoneObserver = NotificationCenter.default.addObserver(
            forName: AVCaptureDevice.wasConnectedNotification, object: nil, queue: .main
        ) { [weak self] notification in
            guard (notification.object as? AVCaptureDevice)?.hasMediaType(.audio) == true else { return }
            MainActor.assumeIsolated { self?.microphoneConnected() }
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        if let configObserver { NotificationCenter.default.removeObserver(configObserver) }
        if let microphoneObserver { NotificationCenter.default.removeObserver(microphoneObserver) }
        configObserver = nil
        microphoneObserver = nil
        retryTimer?.invalidate()
        retryTimer = nil
        endSegment()
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }

    /// Drops what has been heard so far and starts listening afresh.
    func restartSegment() {
        endSegment()
        if isRunning { beginSegment() }
    }

    /// Starts the engine and a segment, or reports the problem and tries again
    /// shortly. The Mac may have no microphone at all until a USB one appears.
    private func startAudio() {
        retryTimer?.invalidate()
        retryTimer = nil
        do {
            try startEngine()
            microphoneAttempts = 0
            beginSegment()
        } catch {
            microphoneAttempts += 1
            guard microphoneAttempts < microphoneRetryLimit else {
                report("\(error.localizedDescription) Waiting until one is connected.")
                return
            }
            // Said once, not on every retry, so the log is not flooded.
            if microphoneAttempts == 1 { report("\(error.localizedDescription) Retrying.") }
            retryTimer = Timer.scheduledTimer(withTimeInterval: microphoneRetryInterval, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, self.isRunning else { return }
                    self.startAudio()
                }
            }
        }
    }

    private func microphoneConnected() {
        guard isRunning, !engine.isRunning else { return }
        microphoneAttempts = 0
        startAudio()
    }

    private func startEngine() throws {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        // With no input device the format is empty, and installTap would raise
        // an Objective-C exception that ends the process.
        guard format.sampleRate > 0, format.channelCount > 0 else { throw ListenerError.noMicrophone }
        let sink = self.sink
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            sink.append(buffer)
        }
        engine.prepare()
        try engine.start()
        if hasProblem {
            hasProblem = false
            onRecovered?()
        }
    }

    private func restartAfterDeviceChange() {
        guard isRunning else { return }
        endSegment()
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        // A device change is news, so it earns a fresh round of attempts.
        microphoneAttempts = 0
        startAudio()
    }

    private func report(_ message: String) {
        hasProblem = true
        onError?(message)
    }

    private func beginSegment() {
        guard let recognizer, engine.isRunning else { return }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.addsPunctuation = false
        request.contextualStrings = contextualStrings
        sink.request = request

        let id = UUID()
        segmentID = id
        segmentText = ""
        segmentStart = Date()
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            DispatchQueue.main.async {
                guard let self, self.segmentID == id else { return }
                if let text {
                    self.segmentText = text
                    self.quickFailures = 0
                    if self.hasProblem {
                        self.hasProblem = false
                        self.onRecovered?()
                    }
                    self.onTranscript?(text)
                }
                if isFinal {
                    self.restartSegment()
                } else if let error {
                    self.segmentFailed(error)
                }
            }
        }

        rotationTimer = Timer.scheduledTimer(withTimeInterval: segmentLength, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.restartSegment() }
        }
    }

    /// Silence ends a task with an error too, so one failure is normal. Tasks
    /// that keep failing at once are not: say so, and retry less often.
    private func segmentFailed(_ error: Error) {
        let quick = Date().timeIntervalSince(segmentStart) < quickFailureWindow
        quickFailures = quick ? quickFailures + 1 : 0
        if quickFailures == 3 { report("Speech recognition keeps failing: \(error.localizedDescription)") }
        endSegment()
        let delay: TimeInterval = quickFailures >= 3 ? 5 : 0.3
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if self.isRunning && self.segmentID == nil { self.beginSegment() }
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
