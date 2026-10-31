import SwiftUI

@main
struct VoiceLauncherApp: App {
    @StateObject private var state = AppState()
    private let settingsWindow = SettingsWindowController()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(state: state, openSettings: { settingsWindow.show(state: state) })
        } label: {
            Image(systemName: state.isPaused ? "mic.slash" : "mic")
        }
    }
}

private struct MenuContent: View {
    @ObservedObject var state: AppState
    let openSettings: () -> Void

    var body: some View {
        Text(state.status)
        if !state.lastHeard.isEmpty {
            Text("Heard: \(state.lastHeard)")
        }
        Divider()
        Button(state.isPaused ? "Resume Listening" : "Pause Listening") { state.togglePause() }
        Button("Settings…") { openSettings() }
        Divider()
        Button("Quit Voice Launcher") { NSApp.terminate(nil) }
    }
}
