# Voice Launcher

A small macOS menu-bar app that listens to the microphone all the time and,
when it hears one of your phrases, runs the action set for it: open, quit or
restart an app, or run a Shortcut. It never types text anywhere, so it can run
alongside any dictation tool without doubling what you say.

- Phrases are plain text; matching is fuzzy, so small recognition differences
  still trigger the command. The "Test" button shows what was heard and the
  match score, and can copy the heard text into the phrase.
- Speech is recognised on this Mac (`SFSpeechRecognizer`, Russian,
  `requiresOnDeviceRecognition`). Nothing is sent anywhere.
- Pause and resume by voice (commands with the "Pause listening" / "Resume
  listening" actions) or from the menu bar. While paused, only resume phrases
  are acted on.
- A sound plays when a command runs. The Log tab shows what was heard and what
  ran; commands, state changes and errors also go to
  `~/Library/Logs/VoiceLauncher.log`. What was merely heard is never written to disk.
- Commands are stored in `~/Library/Application Support/VoiceLauncher/commands.json`.

## Build

Requires macOS 14+ and the Swift toolchain (Xcode or Command Line Tools).

```bash
./App/setup-signing.sh        # once: stable signature, so permissions survive rebuilds
./App/build-app.sh --install  # build, copy to /Applications, launch
swift test                    # matcher tests
```

On first launch macOS asks for microphone and speech-recognition access.

## How it decides

The recogniser streams a transcript. Each update is compared with every enabled
phrase (edit distance over runs of words, see `PhraseMatcher`). A match fires
only after speech has paused for 0.7 s, so a longer phrase that begins like a
shorter one ("restart" vs "start") is not cut short. After a command the
transcript is reset and further matches are ignored for 1.5 s.

See [docs/REFERENCES.md](docs/REFERENCES.md) for the projects studied and why
there is no wake-word engine.
