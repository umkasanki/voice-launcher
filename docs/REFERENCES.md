# References

Projects studied before choosing the design (October 2026).

| Project | What it is | Engine | Text-defined phrases | Russian |
|---|---|---|---|---|
| [Jarvis](https://github.com/abdushsk/jarvis) | Voice AI desktop assistant (Python + Swift overlay), MIT | Porcupine wake word + local Whisper | No, fixed "Jarvis" | Not mentioned |
| [Wake Up](https://github.com/NallaSumang/wake-up-) | Offline launcher: wake word, then clap patterns open apps, MIT | Porcupine + amplitude threshold | No, built-in keywords | Not mentioned |
| [Porcupine](https://github.com/picovoice/porcupine) | On-device wake-word engine, Apache-2.0 SDK | Picovoice keyword spotting | No, custom words are trained in Picovoice Console (needs an AccessKey) | Not in the public language list |
| [openWakeWord](https://github.com/dscripka/openWakeWord) | Open-source wake-word framework | ONNX classifiers | No, each phrase needs a trained model | No, English only |
| [Samzee Voice](https://samplezero.pages.dev/products/samzee-voice) | Paid, offline custom triggers | — | — | Page could not be read |
| [Hermes Voice](https://alternativeto.net/software/hermes-voice/about) | — | — | — | Page could not be read |
| [OpenClaw voice wake](https://www.snaplama.com/blog/how-to-use-openclaw-on-mac-complete-setup-voice-wake-guide) | AI assistant with a menu-bar app and a local wake word | Not named | Custom wake word, method not described | Not mentioned |

A further reference mentioned as "EnglishKey" is still to be identified.

## Conclusions

- Dedicated wake-word engines need a trained model per phrase and do not
  support Russian well. Phrases here are typed as text, so they are matched
  against a speech-recognition transcript instead.
- Checked on macOS 26: `SFSpeechRecognizer` supports `ru-RU` with on-device
  recognition. The newer `SpeechAnalyzer` / `SpeechTranscriber` does not list
  Russian, and Apple's on-device language model (Foundation Models) neither
  supports Russian nor runs without Apple Intelligence.
- Ideas borrowed: a confirmation sound when a command fires (Jarvis,
  OpenClaw), gating to cut false triggers (Wake Up's time-boxed second stage,
  openWakeWord's speech-activity gate) — here a settle delay and a cooldown.

## Possible next stage: an AI model

An AI model that "understands from context" would hear all dictation too and
could mistake an ordinary sentence for a command. If added, it should run only
after a key phrase and choose only from the configured actions.
