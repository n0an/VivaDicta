# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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
- **Transcription Model**: SwiftData model for persistent storage of transcriptions with metadata including title, text, timestamps, and model information.
- **TranscriptionService Protocol**: Abstraction for different transcription backends (local Whisper.cpp, OpenAI, etc.)

### App Structure

- **TabBarView**: Main navigation with tabs for recording, transcriptions, models, and settings
- **RecordView/RecordViewModel**: Audio recording interface with AVAudioRecorder integration and real-time audio level monitoring
- **ModelsView**: Management of local Whisper models with download/delete functionality
- **TranscriptionsView**: Display and management of saved transcriptions

### Transcription Services

- **LocalWhisperTranscriptionService**: Uses the bundled whisper.xcframework for on-device transcription
- **OpenAITranscriptionService**: Cloud-based transcription via OpenAI API
- **WhisperContext**: Actor-based wrapper around whisper.cpp C library ensuring thread-safe access

### Key Technologies

- **Swift 6.0** with strict concurrency enabled
- **SwiftUI** for UI with SwiftData for persistence  
- **AVFoundation** for audio recording/playback
- **whisper.xcframework** - Local Whisper.cpp integration
- **SiriWaveView** package for audio visualization
- **iOS 18+ deployment target**

### Language Support

The app currently supports Auto Detect, English, and Russian languages. The codebase includes infrastructure for 20+ additional languages with localized prompts prepared for future expansion.

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