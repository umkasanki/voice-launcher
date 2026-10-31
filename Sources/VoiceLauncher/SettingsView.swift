import SwiftUI
import UniformTypeIdentifiers
import VoiceLauncherCore

struct SettingsView: View {
    @ObservedObject var state: AppState

    var body: some View {
        TabView {
            CommandsTab(state: state).tabItem { Text("Commands") }
            LogTab(state: state).tabItem { Text("Log") }
            OptionsTab(state: state).tabItem { Text("Options") }
        }
        .padding()
        .sheet(isPresented: Binding(
            get: { state.testingCommandID != nil },
            set: { if !$0 { state.stopTest() } }
        )) {
            TestSheet(state: state)
        }
    }
}

private struct CommandsTab: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading) {
            Text(state.status).foregroundStyle(.secondary)
            List {
                ForEach($state.commands) { $command in
                    CommandRow(command: $command, state: state)
                }
            }
            Button("Add Command") { state.addCommand() }
                .controlSize(.large)
        }
    }
}

private struct CommandRow: View {
    @Binding var command: Command
    @ObservedObject var state: AppState

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Toggle("", isOn: $command.enabled).labelsHidden()
            TextField("Phrase", text: $command.phrase)
                .frame(minWidth: 220)
            Picker("", selection: $command.action) {
                ForEach(ActionKind.allCases) { Text($0.title).tag($0) }
            }
            .labelsHidden()
            .frame(width: 150)
            target
            Button("Test") { state.startTest(command.id) }
            Button(role: .destructive) { state.deleteCommand(command.id) } label: {
                Image(systemName: "trash")
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder private var target: some View {
        if command.action.targetsApp {
            HStack {
                Text(command.target.isEmpty ? "No app" : appName)
                    .frame(minWidth: 120, alignment: .leading)
                Button("Choose…") { chooseApp() }
            }
        } else if command.action == .runShortcut {
            TextField("Shortcut name", text: $command.target)
                .frame(minWidth: 160)
        } else {
            Spacer().frame(minWidth: 160)
        }
    }

    private var appName: String {
        URL(fileURLWithPath: command.target).deletingPathExtension().lastPathComponent
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        if panel.runModal() == .OK, let url = panel.url {
            command.target = url.path
        }
    }
}

private struct TestSheet: View {
    @ObservedObject var state: AppState

    private var command: Command? {
        state.commands.first { $0.id == state.testingCommandID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Say the phrase now").font(.title2)
            Text("Expected: \(command?.phrase ?? "")")
            Text("Heard: \(state.lastHeard.isEmpty ? "…" : state.lastHeard)")
                .font(.title3)
                .textSelection(.enabled)
            let reached = state.testScore >= state.threshold
            Text("Best match: \(Int(state.testScore * 100))% (needs \(Int(state.threshold * 100))%)")
                .foregroundStyle(reached ? .green : .orange)
            Text("Nothing runs while this window is open.").foregroundStyle(.secondary)
            HStack {
                Button("Use What Was Heard") {
                    if let index = state.commands.firstIndex(where: { $0.id == state.testingCommandID }) {
                        state.commands[index].phrase = state.lastHeard
                    }
                }
                .disabled(state.lastHeard.isEmpty)
                Spacer()
                Button("Done") { state.stopTest() }
                    .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
        }
        .padding(24)
        .frame(width: 480)
    }
}

private struct LogTab: View {
    @ObservedObject var state: AppState

    var body: some View {
        List(state.log.reversed()) { entry in
            HStack(alignment: .firstTextBaseline) {
                Text(entry.date, style: .time).foregroundStyle(.secondary)
                Text(entry.text).textSelection(.enabled)
            }
        }
    }
}

private struct OptionsTab: View {
    @ObservedObject var state: AppState

    var body: some View {
        Form {
            Slider(value: $state.threshold, in: 0.6...1.0, step: 0.05) {
                Text("Match strictness: \(Int(state.threshold * 100))%")
            }
            Toggle("Play a sound when a command runs", isOn: $state.playsSound)
            Toggle("Launch at login", isOn: Binding(
                get: { state.launchesAtLogin },
                set: { state.launchesAtLogin = $0 }
            ))
        }
        .formStyle(.grouped)
    }
}
