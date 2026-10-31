import Foundation

/// What a command does when its phrase is heard.
public enum ActionKind: String, Codable, CaseIterable, Identifiable {
    case openApp
    case quitApp
    case restartApp
    case runShortcut
    case pauseListening
    case resumeListening

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .openApp: return "Open app"
        case .quitApp: return "Quit app"
        case .restartApp: return "Restart app"
        case .runShortcut: return "Run Shortcut"
        case .pauseListening: return "Pause listening"
        case .resumeListening: return "Resume listening"
        }
    }

    /// Whether `Command.target` means an application bundle path.
    public var targetsApp: Bool {
        self == .openApp || self == .quitApp || self == .restartApp
    }

    public var needsTarget: Bool { targetsApp || self == .runShortcut }
}

/// One phrase and the action it triggers. The phrase is plain text — no audio
/// samples — and is compared with what the recogniser hears by `PhraseMatcher`.
public struct Command: Codable, Identifiable, Equatable {
    public var id: UUID
    public var phrase: String
    public var action: ActionKind
    /// The application bundle path for the app actions, the Shortcut name for
    /// `runShortcut`, unused otherwise.
    public var target: String
    public var enabled: Bool

    public init(id: UUID = UUID(), phrase: String, action: ActionKind, target: String = "", enabled: Bool = true) {
        self.id = id
        self.phrase = phrase
        self.action = action
        self.target = target
        self.enabled = enabled
    }
}
