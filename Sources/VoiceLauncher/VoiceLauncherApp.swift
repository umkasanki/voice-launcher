import SwiftUI

@main
struct VoiceLauncherApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(state: state)
        } label: {
            Image(systemName: state.isPaused ? "mic.slash" : "mic")
        }

        // An ordinary titled window, as in AllyClicker, rather than the
        // Settings scene: text tabs in the content and a Done button below.
        Window("Voice Launcher Settings", id: "settings") {
            SettingsView(state: state)
        }
        .windowResizability(.contentSize)
    }
}

private struct MenuContent: View {
    @ObservedObject var state: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(state.status)
        if !state.lastHeard.isEmpty {
            Text("Heard: \(state.lastHeard)")
        }
        Divider()
        Button(state.isPaused ? "Resume Listening" : "Pause Listening") { state.togglePause() }
        Button("Settings…") {
            // A menu-bar app is never frontmost by itself; without this the
            // settings window opens behind the current app.
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "settings")
        }
        Divider()
        Button("Quit Voice Launcher") { NSApp.terminate(nil) }
    }
}
