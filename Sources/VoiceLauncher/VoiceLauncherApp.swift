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

        Window("Voice Launcher", id: "settings") {
            SettingsView(state: state)
                .frame(minWidth: 760, minHeight: 460)
        }
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
            openWindow(id: "settings")
            NSApp.activate(ignoringOtherApps: true)
        }
        Divider()
        Button("Quit Voice Launcher") { NSApp.terminate(nil) }
    }
}
