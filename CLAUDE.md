# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.
If you don't know answer - it's ok to say that you don't know. It's not necessary to please me and be very polite with me. I'm not pleased if you always agree with everything I'm saying. I'm pleased when you provide correct answers, even if I don't like these answers.

# VivaDicta iOS Codebase

VivaDicta is an iOS voice transcription app that uses local Whisper.cpp models and cloud-based transcription services. The app records audio, transcribes it using AI models, and stores transcriptions with SwiftData for persistent storage.

## Build Commands

Use the following commands to build, run and test the app:

- Build: `xcodebuild -scheme VivaDicta -configuration Debug -workspace ./VivaDicta.xcodeproj/project.xcworkspace -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' -allowProvisioningUpdates build | xcbeautify`
- Run tests: `xcodebuild -scheme VivaDicta -configuration Debug -workspace ./VivaDicta.xcodeproj/project.xcworkspace -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' -allowProvisioningUpdates test | xcbeautify`
- Run single test: `xcodebuild -scheme VivaDicta -configuration Debug -workspace ./VivaDicta.xcodeproj/project.xcworkspace -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' -allowProvisioningUpdates test -only-testing:VivaDictaTests/TestClassName/testMethodName | xcbeautify`

## Architecture

### Core Components

- **AppState**: Observable app-wide state management using Swift's `@Observable` macro. Manages selected transcription service, language, and Whisper model configuration.
- **Transcription Model**: SwiftData model for persistent storage of transcriptions with metadata including text, timestamps, enhanced text, audio file URL, duration, and transcription/enhancement model names.
- **TranscriptionService Protocol**: Abstraction for different transcription backends (local Whisper.cpp, OpenAI, etc.)

### App Structure

- **TabBarView**: Main navigation with tabs for recording, transcriptions, models, and settings
- **RecordView/RecordViewModel**: Audio recording interface with AVAudioRecorder integration and real-time audio level monitoring
- **ModelsView**: Management of local Whisper models with download/delete functionality
- **TranscriptionsView**: Display and management of saved transcriptions

### Transcription Services

- **LocalTranscriptionService/LocalWhisperTranscriptionService**: Uses the bundled whisper.xcframework for on-device transcription
- **CloudTranscriptionService**: Unified service managing multiple cloud providers:
  - **OpenAITranscriptionService**: OpenAI Whisper API
  - **ElevenLabsTranscriptionService**: ElevenLabs speech-to-text
  - **GroqTranscriptionService**: Groq API transcription
  - **DeepgramTranscriptionService**: Deepgram Nova API
  - **GeminiTranscriptionService**: Google Gemini API
- **WhisperContext**: Actor-based wrapper around whisper.cpp C library ensuring thread-safe access

### Key Technologies

- **Swift 6.0** with strict concurrency enabled
- **SwiftUI** for UI with SwiftData for persistence  
- **AVFoundation** for audio recording/playback
- **whisper.xcframework** - Local Whisper.cpp integration
- **SiriWaveView** package for audio visualization
- **TipKit** for user onboarding and feature discovery
- **iOS 18+ deployment target**

### Language Support

The app currently supports Auto Detect, English, and Russian languages. The codebase includes infrastructure for 20+ additional languages with localized prompts prepared for future expansion.

### Enhanced Transcription Features

- **Text Enhancement**: The app supports enhanced transcription processing with separate enhancement models
- **Audio Duration Tracking**: Transcriptions include audio duration metadata for better file management  
- **Multiple Transcription Providers**: Users can choose from various cloud providers based on their needs and preferences

## Documentation

The `/docs/` directory contains comprehensive reference documentation for Apple technologies:
- `swift6-migration.mdc` - Swift 6 migration guide and concurrency best practices
- `swift-concurrency.md` - Detailed Swift concurrency patterns and async/await usage
- `swift-observable.mdc` - Swift Observation framework (@Observable macro)
- `swift-testing-*.mdc` - Swift Testing framework API and best practices
- `swiftdata.md` - SwiftData persistence patterns and model definitions
- `swiftui.md` - SwiftUI patterns, view composition, and state management
- `uikit.md` - UIKit integration and interoperability

Refer to these docs when working with Apple frameworks or implementing new features.

## AI-Powered PR Review

The repository includes automated GitHub Actions workflow for AI-powered code review with iOS test execution. TypeScript scripts in `/lib/agents/` orchestrate code review generation and test running using either OpenAI or Anthropic APIs.

