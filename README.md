<p align="center">
  <img src="assets/readme/app-icon.png" width="100" alt="VivaDicta Icon">
</p>

<h1 align="center">VivaDicta</h1>

<p align="center">
  Transform your voice into polished text with AI
  <br>
  <a href="https://vivadicta.com/ios">Website</a> &bull;
  <a href="https://apps.apple.com/app/id6758147238">App Store</a> &bull;
  <a href="https://n0an.github.io/VivaDicta/">DocC Documentation</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Xcode-26%2B-blue?logo=xcode&logoColor=white" alt="Xcode 26+">
  <img src="https://img.shields.io/badge/iOS-18%2B-orange?logo=apple&logoColor=white" alt="iOS 18.0+">
  <img src="https://img.shields.io/badge/swift-6.0-orange" alt="Swift 6.0">
  <img src="https://img.shields.io/github/license/n0an/VivaDicta" alt="License">
</p>

---

VivaDicta records speech, transcribes it using on-device or cloud models, and optionally processes the text through an AI provider. It supports 10+ transcription providers, 15+ AI providers, a custom keyboard extension, and syncs across devices (iOS/iPadOS/macOS) via CloudKit.

## Screenshots

<p align="center">
  <img src="assets/readme/detail-screen.png" width="350" alt="Transcription Detail">
  &nbsp;&nbsp;
  <img src="assets/readme/mode-edit.png" width="350" alt="Mode Configuration">
  &nbsp;&nbsp;
</p>

<p align="center">
  <img src="assets/readme/ai-providers.png" width="350" alt="AI Providers">
  &nbsp;&nbsp;
  <img src="assets/readme/transcription-models.png" width="350" alt="Transcription Models">
</p>

## Features

**Transcription**
- On-device: WhisperKit (OpenAI Whisper), Parakeet (NVIDIA) — professional-grade models running entirely on your device
- Cloud: OpenAI, Groq, Deepgram, ElevenLabs, Gemini, Mistral, Soniox, or any OpenAI-compatible endpoint
- 100+ languages with automatic detection
- Filler word removal, paragraph formatting, custom word replacements

**AI Presets**
- 40+ built-in presets across categories: Rewrite, Style, Communication, Summarize, Social Media, Writing, Learn & Study, Translate
- **AI Assistant** — ask questions, fact-check, explain, reformat, or give instructions by voice
- **Auto-Translation** — speak in one language, get output in another
- Each result saved as a variation — compare different AI outputs side by side
- Create custom presets with full prompt control, mark favorites for quick access

**AI Providers**
- 15+ providers: Apple Foundation Model (on-device, free), Anthropic, OpenAI, Gemini, Groq, Mistral, Cerebras, Grok, OpenRouter, Vercel AI Gateway, HuggingFace, Ollama, and more
- Bring your own AI via any OpenAI-compatible API endpoint

**VivaModes**
- Configurable profiles combining transcription provider, AI provider, model, preset, and language
- Each mode remembers its settings — switch contexts with one tap
- Clipboard context — AI uses copied text as context when processing your dictation (e.g., copy a message, then dictate your reply)

**Custom Keyboard**
<p>
<img src="assets/readme/keyboard.png" width="220" alt="Custom Keyboard">
</p>

- System-wide voice keyboard — dictate into Messages, WhatsApp, Email, Notion, Slack, or any app
- Full transcription + AI processing pipeline right from the keyboard
- Swipe to switch between modes without leaving the app you're typing in

**Personalization**
- Custom dictionary for names and terms (OpenClaw, Dr. Johnson, etc.)
- Word replacements and shortcuts (e.g., "my email" → support@vivadicta.com)
- Audio recordings saved alongside transcriptions

**Sync & Extensions**
- iCloud sync across iPhone, iPad, and Mac — transcriptions, presets, custom dictionary, and API keys
- Home and Lock screen widgets and Control Center control to quickly record a note
- Live Activity for recording status
- Share Extension and Action Extension for importing audio files from other apps

## Platform & Tech

- Apple Foundation Model — free on-device AI processing, no API key needed
- Swift 6 with strict concurrency
- SwiftUI
- Liquid Glass
- SwiftData with CloudKit sync
- App Intents — Siri and Shortcuts integration
- CoreSpotlight — indexed transcriptions for iOS spotlight search
- Shortcuts — quickly record a note and more

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

Main app ↔ extensions IPC via `AppGroupCoordinator` (Darwin Notifications + Shared UserDefaults):

```
┌─────────────┐   Darwin Notifications   ┌───────────────────┐
│   Main App   │◄────────────────────────►│ Keyboard Extension │
│              │   Shared UserDefaults    │                   │
│ RecordView   │◄────────────────────────►│  Dictation State  │
│ Model        │                          └───────────────────┘
│              │◄──► Widget + Live Activity
│              │◄──► Share Extension
│              │◄──► Action Extension
└─────────────┘
```

Core components:

| Component | Role |
|-----------|------|
| `AppGroupCoordinator` | Cross-process communication using Darwin Notifications (custom keyboard, widgets, share, action extensions) |
| `RecordViewModel` | Recording lifecycle, dual audio paths (normal + keyboard prewarm) |
| `TranscriptionManager` | Routes to on-device or cloud STT, post-processing pipeline |
| `AIService` | AI text processing, 15+ providers, mode/API key management |
| `PresetManager` | Built-in + custom presets, CloudKit sync |
| `AudioPrewarmManager` | Continuous audio engine for keyboard extension low-latency recording |

See the [architecture documentation](documentation/) for detailed diagrams and flows.

## Building

**Requirements:**
- Xcode 26+
- iOS 18+ deployment target

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

---

<p align="center">
  Made with ❤️ by Anton Novoselov
  <br><br>
  <a href="https://twitter.com/vivadicta"><img src="https://img.shields.io/twitter/follow/vivadicta?style=flat" alt="X"></a>
  &nbsp;
  <a href="https://github.com/n0an"><img src="https://img.shields.io/github/followers/n0an?style=flat" alt="GitHub"></a>
  &nbsp;
  <a href="https://www.linkedin.com/in/anton-novoselov/"><img src="https://img.shields.io/badge/LinkedIn-anton--novoselov-blue?style=flat&logo=linkedin" alt="LinkedIn"></a>
</p>
