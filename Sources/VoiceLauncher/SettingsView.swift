import SwiftUI
import UniformTypeIdentifiers
import VoiceLauncherCore

/// The standard macOS settings window: one toolbar tab per pane, each pane its
/// own fixed size, as in Safari or Mail settings.
struct SettingsView: View {
    @ObservedObject var state: AppState

    var body: some View {
        TabView {
            CommandsPane(state: state)
                .tabItem { Label("Commands", systemImage: "mic") }
            LogPane(state: state)
                .tabItem { Label("Log", systemImage: "list.bullet.rectangle") }
            GeneralPane(state: state)
                .tabItem { Label("General", systemImage: "gearshape") }
        }
    }
}

// MARK: Commands

private struct CommandsPane: View {
    @ObservedObject var state: AppState
    @State private var selection: Command.ID?
    /// The command being edited in the sheet; a copy, saved only on "Save".
    @State private var draft: Command?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Table(state.commands, selection: $selection) {
                TableColumn("On") { command in
                    Toggle("", isOn: Binding(
                        get: { command.enabled },
                        set: { state.setEnabled($0, for: command.id) }
                    ))
                    .labelsHidden()
                }
                .width(min: 28, max: 32)
                TableColumn("Phrase", value: \.phrase)
                TableColumn("Action") { Text($0.action.title) }
                    .width(min: 100, max: 130)
                TableColumn("Target") { Text(targetDescription($0)).foregroundStyle(.secondary) }
                    .width(min: 100, max: 150)
            }
            .contextMenu(forSelectionType: Command.ID.self) { ids in
                if let id = ids.first {
                    Button("Edit…") { edit(id) }
                    Button("Delete") { state.deleteCommand(id) }
                }
            } primaryAction: { ids in
                if let id = ids.first { edit(id) }
            }

            Divider()
            HStack(spacing: 8) {
                Button { draft = Command(phrase: "", action: .openApp) } label: {
                    Image(systemName: "plus").frame(width: 16)
                }
                .help("Add a command")
                Button {
                    if let selection { state.deleteCommand(selection) }
                    selection = nil
                } label: {
                    Image(systemName: "minus").frame(width: 16)
                }
                .disabled(selection == nil)
                .help("Delete the selected command")
                Button("Edit…") { if let selection { edit(selection) } }
                    .disabled(selection == nil)
                Spacer()
                Label(state.status, systemImage: state.isPaused ? "mic.slash" : "waveform")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(10)
        }
        .frame(width: 680, height: 400)
        .sheet(item: $draft) { command in
            CommandEditor(state: state, draft: command) { saved in
                state.saveCommand(saved)
                selection = saved.id
            }
        }
    }

    private func edit(_ id: Command.ID) {
        draft = state.commands.first { $0.id == id }
    }

    private func targetDescription(_ command: Command) -> String {
        if command.action.targetsApp {
            return command.target.isEmpty
                ? "—" : URL(fileURLWithPath: command.target).deletingPathExtension().lastPathComponent
        }
        return command.action == .runShortcut ? command.target : "—"
    }
}

/// Add or edit one command, and test its phrase without running anything.
private struct CommandEditor: View {
    @ObservedObject var state: AppState
    @State var draft: Command
    let onSave: (Command) -> Void
    @Environment(\.dismiss) private var dismiss

    private var isTesting: Bool { state.testPhrase != nil }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("Phrase", text: $draft.phrase, prompt: Text("What you will say"))
                    Picker("Action", selection: $draft.action) {
                        ForEach(ActionKind.allCases) { Text($0.title).tag($0) }
                    }
                    if draft.action.targetsApp {
                        LabeledContent("Application") {
                            HStack {
                                Text(draft.target.isEmpty ? "None" : appName)
                                    .foregroundStyle(draft.target.isEmpty ? .secondary : .primary)
                                Button("Choose…") { chooseApp() }
                            }
                        }
                    } else if draft.action == .runShortcut {
                        TextField("Shortcut", text: $draft.target, prompt: Text("Name in the Shortcuts app"))
                    }
                    Toggle("Enabled", isOn: $draft.enabled)
                }

                Section {
                    LabeledContent("Heard") {
                        Text(isTesting ? (state.lastHeard.isEmpty ? "Listening…" : state.lastHeard) : "—")
                            .textSelection(.enabled)
                    }
                    LabeledContent("Match") {
                        Text(isTesting ? "\(Int(state.testScore * 100))% (needs \(Int(state.threshold * 100))%)" : "—")
                            .foregroundStyle(matchColor)
                    }
                    HStack {
                        Button(isTesting ? "Stop Test" : "Start Test") {
                            if isTesting { state.stopTest() } else { state.startTest(phrase: draft.phrase) }
                        }
                        .disabled(draft.phrase.isEmpty)
                        Button("Use Heard Text") { draft.phrase = state.lastHeard }
                            .disabled(!isTesting || state.lastHeard.isEmpty)
                    }
                } header: {
                    Text("Test")
                } footer: {
                    Text("Say the phrase. Nothing runs while testing.")
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .onChange(of: draft.phrase) { _, phrase in
                if isTesting { state.startTest(phrase: phrase) }
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { close() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    onSave(draft)
                    close()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(draft.phrase.trimmingCharacters(in: .whitespaces).isEmpty
                          || (draft.action.needsTarget && draft.target.isEmpty))
            }
            .padding([.horizontal, .bottom], 20)
        }
        .frame(width: 520)
        .onDisappear { state.stopTest() }
    }

    private var matchColor: Color {
        guard isTesting else { return .secondary }
        return state.testScore >= state.threshold ? .green : .orange
    }

    private var appName: String {
        URL(fileURLWithPath: draft.target).deletingPathExtension().lastPathComponent
    }

    private func close() {
        state.stopTest()
        dismiss()
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        if panel.runModal() == .OK, let url = panel.url {
            draft.target = url.path
        }
    }
}

// MARK: Log

private struct LogPane: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Table(state.log.reversed()) {
                TableColumn("Time") { Text($0.date, format: .dateTime.hour().minute().second()) }
                    .width(min: 64, max: 80)
                TableColumn("Event") { Text($0.text).textSelection(.enabled) }
            }
            Divider()
            HStack {
                Text("What was heard is kept in memory only and is gone when the app quits.")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Clear") { state.clearLog() }
                    .disabled(state.log.isEmpty)
            }
            .padding(10)
        }
        .frame(width: 680, height: 400)
    }
}

// MARK: General

private struct GeneralPane: View {
    @ObservedObject var state: AppState

    var body: some View {
        Form {
            Section {
                LabeledContent("Match strictness") {
                    VStack(alignment: .leading, spacing: 4) {
                        Slider(value: $state.threshold, in: 0.6...1.0, step: 0.05) {
                            EmptyView()
                        } minimumValueLabel: {
                            Text("Lenient")
                        } maximumValueLabel: {
                            Text("Strict")
                        }
                        Text("A phrase must match \(Int(state.threshold * 100))% of what is heard.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Recognition")
            }

            Section {
                Toggle("Play a sound when a command runs", isOn: $state.playsSound)
            } header: {
                Text("Feedback")
            }

            Section {
                Toggle("Launch at login", isOn: Binding(
                    get: { state.launchesAtLogin },
                    set: { state.launchesAtLogin = $0 }
                ))
            } header: {
                Text("Startup")
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 320)
    }
}
