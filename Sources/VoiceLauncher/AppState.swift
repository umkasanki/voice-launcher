import AppKit
import ServiceManagement
import VoiceLauncherCore

struct LogEntry: Identifiable {
    let id = UUID()
    let date = Date()
    let text: String
}

/// Everything the menu and the settings window show, and the glue between the
/// listener, the matcher and the actions.
@MainActor
final class AppState: ObservableObject {
    @Published var commands: [Command] = [] {
        didSet {
            guard commands != oldValue else { return }
            saveCommands()
            listener.contextualStrings = commands.map(\.phrase)
        }
    }
    @Published private(set) var isPaused = false
    @Published private(set) var isListening = false
    @Published private(set) var status = "Starting…"
    @Published private(set) var lastHeard = ""
    @Published private(set) var log: [LogEntry] = []

    /// The phrase being tested in the command editor; actions do not run meanwhile.
    @Published private(set) var testPhrase: String?
    @Published private(set) var testScore = 0.0

    @Published var threshold: Double {
        didSet { UserDefaults.standard.set(threshold, forKey: "threshold") }
    }
    /// Said before every command, e.g. a greeting; empty means no key phrase.
    @Published var keyPhrase: String {
        didSet { UserDefaults.standard.set(keyPhrase, forKey: "keyPhrase") }
    }
    @Published var playsSound: Bool {
        didSet { UserDefaults.standard.set(playsSound, forKey: "playsSound") }
    }

    private let listener = SpeechListener()
    private var pending: PhraseMatcher.Match?
    private var pendingWork: DispatchWorkItem?
    private var ignoreUntil = Date.distantPast

    /// How long speech must stop before a matched phrase fires. Without it a
    /// half-heard "re…start" could fire the shorter "start" phrase first.
    private let settleDelay: TimeInterval = 0.7
    private let cooldown: TimeInterval = 1.5
    private let maxLogEntries = 300

    private static let commandsURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("VoiceLauncher/commands.json")
    }()
    private static let logFileURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/VoiceLauncher.log")

    init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: ["threshold": 0.9, "playsSound": true, "keyPhrase": ""])
        threshold = defaults.double(forKey: "threshold")
        keyPhrase = defaults.string(forKey: "keyPhrase") ?? ""
        playsSound = defaults.bool(forKey: "playsSound")
        commands = Self.loadCommands()
        listener.contextualStrings = commands.map(\.phrase)

        listener.onTranscript = { [weak self] in self?.heard($0) }
        listener.onSegmentEnd = { [weak self] in self?.addLog("Heard: \($0)", toFile: false) }
        listener.onError = { [weak self] in self?.report($0) }

        Task { await startListening() }
    }

    // MARK: Listening

    func startListening() async {
        guard await SpeechListener.requestPermissions() else {
            report("No access to the microphone or speech recognition. Allow both in System Settings → Privacy & Security.")
            return
        }
        do {
            try listener.start()
            isListening = true
            updateStatus()
            addLog("Listening started")
        } catch {
            report(error.localizedDescription)
        }
    }

    func togglePause() {
        setPaused(!isPaused)
    }

    private func setPaused(_ paused: Bool) {
        isPaused = paused
        updateStatus()
        addLog(paused ? "Paused" : "Resumed")
        if playsSound { NSSound(named: paused ? "Bottle" : "Pop")?.play() }
    }

    private func updateStatus() {
        status = !isListening ? status : isPaused ? "Paused — only resume phrases work" : "Listening"
    }

    private func heard(_ text: String) {
        lastHeard = text
        if let testPhrase {
            let score = PhraseMatcher.score(command: testPhrase, keyPhrase: keyPhrase, in: text)
            testScore = max(testScore, score)
            return
        }
        guard Date() >= ignoreUntil else { return }

        // While paused, only a resume phrase is listened for.
        let candidates = isPaused ? commands.filter { $0.action == .resumeListening } : commands
        pendingWork?.cancel()
        pending = PhraseMatcher.bestMatch(in: text, commands: candidates, threshold: threshold, keyPhrase: keyPhrase)
        guard pending != nil else { return }

        let work = DispatchWorkItem { [weak self] in
            guard let self, let match = self.pending else { return }
            self.pending = nil
            self.fire(match, heard: text)
        }
        pendingWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + settleDelay, execute: work)
    }

    private func fire(_ match: PhraseMatcher.Match, heard text: String) {
        ignoreUntil = Date().addingTimeInterval(cooldown)
        listener.restartSegment()
        let command = match.command
        addLog("“\(text)” → \(command.action.title) \(command.target) (\(Int(match.score * 100))%)")

        switch command.action {
        case .pauseListening:
            setPaused(true)
            return
        case .resumeListening:
            setPaused(false)
            return
        default:
            if playsSound { NSSound(named: "Glass")?.play() }
        }
        Task {
            do {
                try await ActionRunner.run(command)
            } catch {
                report("\(command.action.title) failed: \(error.localizedDescription)")
                if playsSound { NSSound(named: "Basso")?.play() }
            }
        }
    }

    // MARK: Testing a phrase

    func startTest(phrase: String) {
        testScore = 0
        lastHeard = ""
        testPhrase = phrase
        listener.restartSegment()
    }

    func stopTest() {
        guard testPhrase != nil else { return }
        testPhrase = nil
        listener.restartSegment()
    }

    // MARK: Commands

    /// Replaces the command with the same id, or adds it as a new one.
    func saveCommand(_ command: Command) {
        if let index = commands.firstIndex(where: { $0.id == command.id }) {
            commands[index] = command
        } else {
            commands.append(command)
        }
    }

    func setEnabled(_ enabled: Bool, for id: UUID) {
        guard let index = commands.firstIndex(where: { $0.id == id }) else { return }
        commands[index].enabled = enabled
    }

    func deleteCommand(_ id: UUID) {
        commands.removeAll { $0.id == id }
    }

    private static func loadCommands() -> [Command] {
        guard let data = try? Data(contentsOf: commandsURL) else { return [] }
        return (try? JSONDecoder().decode([Command].self, from: data)) ?? []
    }

    private func saveCommands() {
        do {
            try FileManager.default.createDirectory(
                at: Self.commandsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(commands).write(to: Self.commandsURL, options: .atomic)
        } catch {
            report("Could not save commands: \(error.localizedDescription)")
        }
    }

    // MARK: Launch at login

    var launchesAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                report("Launch at login: \(error.localizedDescription)")
            }
            objectWillChange.send()
        }
    }

    // MARK: Log

    func clearLog() {
        log.removeAll()
    }

    private func report(_ message: String) {
        status = message
        addLog("Error: \(message)")
    }

    /// Everything goes to the window's log; only commands, state changes and
    /// errors go to the file. What was merely heard stays in memory, because it
    /// is everything said near the microphone, dictation included.
    private func addLog(_ text: String, toFile: Bool = true) {
        log.append(LogEntry(text: text))
        if log.count > maxLogEntries { log.removeFirst(log.count - maxLogEntries) }
        guard toFile else { return }
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(text)\n"
        guard let data = line.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: Self.logFileURL) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: Self.logFileURL)
        }
    }
}
