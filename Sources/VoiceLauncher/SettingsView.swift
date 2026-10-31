import SwiftUI
import UniformTypeIdentifiers
import VoiceLauncherCore

/// The settings window, laid out like AllyClicker's: text tabs at the top, the
/// pane below, and a footer with Done. Changes save as they are made.
struct SettingsView: View {
    @ObservedObject var state: AppState
    let onDone: () -> Void
    /// Room between the tabs and the pane, about one line of text.
    private let paneTopGap: CGFloat = 16

    var body: some View {
        VStack(spacing: 0) {
            TabView {
                GeneralPane(state: state)
                    .padding(.top, paneTopGap)
                    .tabItem { Text("General") }
                CommandsPane(state: state)
                    .padding(.top, paneTopGap)
                    .tabItem { Text("Commands") }
                LogPane(state: state)
                    .padding(.top, paneTopGap)
                    .tabItem { Text("Log") }
            }
            .padding(.top, 8)
            Divider()
            HStack {
                Spacer()
                Button("Done") { onDone() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .frame(width: 720, height: 520)
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
            // Said before every command, so it sits above them.
            VStack(alignment: .leading, spacing: 6) {
                Text("Key Phrase").font(.headline)
                TextField("Key phrase", text: $state.keyPhrase, prompt: Text("Optional, e.g. a greeting"))
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                Text("When set, a command runs only if this is said first and the command follows right after it.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)

            Text("Commands")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.top, 24)
                .padding(.bottom, 8)

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
                    Button("Delete") {
                        state.deleteCommand(id)
                        if selection == id { selection = nil }
                    }
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
                        Text(isTesting ? "\(Int((state.testScore * 100).rounded()))% (needs \(Int((state.threshold * 100).rounded()))%)" : "—")
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
                        Text("A phrase must match \(Int((state.threshold * 100).rounded()))% of what is heard.")
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
    }
}
