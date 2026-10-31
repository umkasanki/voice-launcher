import AppKit
import VoiceLauncherCore

/// Performs a command's action. Listening pause and resume are handled by
/// `AppState`, not here.
@MainActor
enum ActionRunner {
    struct Failure: LocalizedError {
        let errorDescription: String?
        init(_ message: String) { errorDescription = message }
    }

    static func run(_ command: Command) async throws {
        switch command.action {
        case .openApp:
            try await openApp(at: command.target)
        case .quitApp:
            try await quitApp(at: command.target)
        case .restartApp:
            try await quitApp(at: command.target)
            try await openApp(at: command.target)
        case .runShortcut:
            try await runShortcut(named: command.target)
        case .pauseListening, .resumeListening:
            break
        }
    }

    static func openApp(at path: String) async throws {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw Failure("No application at \(path)")
        }
        _ = try await NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    /// Asks the application to quit the normal way (a quit Apple Event, as the
    /// Dock does), and sends SIGTERM if it is still running five seconds later.
    /// Quitting an application that is not running is not an error.
    static func quitApp(at path: String) async throws {
        guard let bundleID = Bundle(url: URL(fileURLWithPath: path))?.bundleIdentifier else {
            throw Failure("No application at \(path)")
        }
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        guard !running.isEmpty else { return }

        running.forEach { $0.terminate() }
        if await waitForExit(running, seconds: 5) { return }

        running.filter { !$0.isTerminated }.forEach { kill($0.processIdentifier, SIGTERM) }
        if await waitForExit(running, seconds: 3) { return }
        throw Failure("\(bundleID) did not quit")
    }

    static func runShortcut(named name: String) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["run", name]
        let status: Int32 = try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { continuation.resume(returning: $0.terminationStatus) }
            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume(throwing: error)
            }
        }
        if status != 0 { throw Failure("Shortcut \"\(name)\" failed with status \(status)") }
    }

    private static func waitForExit(_ apps: [NSRunningApplication], seconds: Double) async -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if apps.allSatisfy(\.isTerminated) { return true }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return apps.allSatisfy(\.isTerminated)
    }
}
