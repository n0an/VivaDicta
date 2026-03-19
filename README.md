<p align="center">
  <img src="assets/readme/app-icon.png" width="100" alt="VivaDicta Icon">
</p>

<h1 align="center">VivaDicta</h1>

<p align="center">
  Open-source iOS voice transcription app with on-device and cloud AI processing.
  <br>
  <a href="https://vivadicta.com/ios">Website</a> &bull;
  <a href="https://apps.apple.com/app/id6758147238">App Store</a> &bull;
  <a href="https://n0an.github.io/VivaDicta/">Documentation</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Xcode-26%2B-blue?logo=xcode&logoColor=white" alt="Xcode 26+">
  <img src="https://img.shields.io/badge/iOS-18%2B-orange?logo=apple&logoColor=white" alt="iOS 26.0+">
  <img src="https://img.shields.io/badge/swift-6.0-orange" alt="Swift 6.0">
  <img src="https://img.shields.io/github/license/n0an/VivaDicta" alt="License">
</p>

---

VivaDicta records speech, transcribes it using on-device or cloud models, and optionally processes the text through an AI provider. It supports 10+ transcription providers, 17 AI providers, a custom keyboard extension, and syncs across devices via CloudKit.

## Screenshots

<p align="center">
  <img src="assets/readme/detail-screen.png" width="300" alt="Transcription Detail">
  &nbsp;&nbsp;
  <img src="assets/readme/mode-edit.png" width="300" alt="Mode Configuration">
  &nbsp;&nbsp;
</p>

<p align="center">
  <img src="assets/readme/ai-providers.png" width="300" alt="AI Providers">
  &nbsp;&nbsp;
  <img src="assets/readme/transcription-models.png" width="300" alt="AI Providers">
</p>

## Features

**Transcription**
- On-device: WhisperKit (OpenAI Whisper), Parakeet (NVIDIA)
- Cloud: OpenAI, Groq, Deepgram, ElevenLabs, Gemini, Mistral, Soniox, custom endpoint
- Automatic language detection or 99+ language selection
- Filler word removal, paragraph formatting, custom word replacements

**AI Processing**
- 17 providers: Apple Foundation Models (on-device), Anthropic, OpenAI, Gemini, Groq, Mistral, Cerebras, Grok, OpenRouter, Vercel AI Gateway, HuggingFace, Ollama, and more
- 15+ built-in presets: Regular cleanup, Summary, Email, Chat, Coding, Action Points, translations
- Custom presets with full prompt control
- Clipboard context awareness for smarter processing

**Architecture**
- VivaModes: configurable profiles combining transcription provider, AI provider, model, preset, and language
- Dual-write pattern: each AI output stored as a `TranscriptionVariation` for comparison
- Multi-stage text processing pipeline with toggleable stages

**Extensions**
- Custom keyboard with recording, transcription, and AI processing
- Home/Lock screen widgets + Live Activity
- Share Extension for audio files from other apps
- Action Extension for processing text from other apps

**Platform**
- Swift 6 with strict concurrency
- SwiftUI + SwiftData with CloudKit sync
- CoreSpotlight + App Intents for Siri/Shortcuts
- Companion macOS app sync via shared CloudKit container

## Architecture

```
Recording → Transcription → AI Processing → Storage
    │              │               │            │
    ▼              ▼               ▼            ▼
AVAudioRecorder  WhisperKit     AIService    SwiftData
  or             Parakeet       17 providers  + CloudKit
AVAudioEngine    Cloud STT      PromptsTemplates
(keyboard)       providers
```

Core components:

| Component | Role |
|-----------|------|
| `RecordViewModel` | Recording lifecycle, dual audio paths (normal + keyboard prewarm) |
| `TranscriptionManager` | Routes to on-device or cloud STT, post-processing pipeline |
| `AIService` | AI text processing, 17 providers, mode/API key management |
| `PresetManager` | Built-in + custom presets, CloudKit sync |
| `AppGroupCoordinator` | Cross-process communication (keyboard, widget, share, action extensions) |
| `AudioPrewarmManager` | Continuous audio engine for keyboard extension low-latency recording |

See the [architecture documentation](documentation/) for detailed diagrams and flows.

## Building

**Requirements:**
- Xcode 26+
- iOS 18+ deployment target
- macOS with Apple Silicon (for on-device models)

```bash
# Clone
git clone https://github.com/n0an/VivaDicta.git
cd VivaDicta

# Open in Xcode
open VivaDicta.xcodeproj

# Or build from command line
xcodebuild build \
  -scheme VivaDicta \
  -workspace ./VivaDicta.xcodeproj/project.xcworkspace \
  -destination generic/platform=iOS \
  CODE_SIGNING_ALLOWED=NO
```

> **Note:** On-device transcription models (WhisperKit, Parakeet) are downloaded on first use. Cloud providers require API keys configured in the app's settings.

## Project Structure

```
VivaDicta/
├── VivaDicta/              # Main app target
│   ├── Views/              # SwiftUI views + view models
│   ├── Models/             # SwiftData models (Transcription, Preset, etc.)
│   ├── Services/           # Core services
│   │   ├── AIEnhance/      # AIService, providers, prompts
│   │   └── Transcription/  # TranscriptionManager, STT providers
│   ├── Shared/             # AppGroupCoordinator, shared utilities
│   └── VivaDicta.docc/     # DocC documentation catalog
├── VivaDictaKeyboard/      # Custom keyboard extension
├── VivaDictaWidget/        # Widget + Live Activity
├── ShareExtension/         # Share extension
├── ActionExtension/        # Action extension
├── documentation/          # Architecture docs, references
└── .github/workflows/      # CI: build check, Claude review, GitGuardian
```

## Documentation

- **[DocC API Reference](https://n0an.github.io/VivaDicta/)** — generated API documentation
- **[Architecture Docs](documentation/)** — recording pipeline, transcription system, AI processing, text pipeline, preset system, AppGroupCoordinator
- **[Text Processing Pipeline](documentation/text-processing-pipeline.md)** — 7-stage pipeline from raw audio to formatted text

## Contributing

Contributions are welcome. Please open an issue first to discuss what you'd like to change.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes
4. Push to the branch (`git push origin feature/my-feature`)
5. Open a Pull Request

The CI will run a build check on your PR automatically.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
