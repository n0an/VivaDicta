# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.
If you don't know answer - it's ok to say that you don't know. It's not necessary to please me and be very polite with me. I'm not pleased if you always agree with everything I'm saying. I'm pleased when you provide correct answers, even if I don't like these answers.

## Skills

When @.claude/skills is mentioned or when starting a task:

1. Read .claude/skills/CLAUDE.md
2. Scan the index for relevant skills
3. Mention which skills you're referencing
4. Note any deviations from the skill pattern and why
5. Suggest new skills when you see repeated patterns (use `.claude/commands/create-skill.md` to create a new skill)


## Git Commit & PR Guidelines
- NEVER commit and push without asking the user first - always ask "do we need to commit and push at the moment?" before executing git commit or git push commands
- NEVER commit and push without asking the user first - always ask "do we need to commit and push at the moment?" before executing git commit or git push commands
- NEVER commit and push without asking the user first - always ask "do we need to commit and push at the moment?" before executing git commit or git push commands

# VivaDicta iOS Codebase

VivaDicta is an iOS voice transcription app that uses on-device transcription (WhisperKit and Parakeet) and cloud-based transcription services. The app records audio, transcribes it using AI models, and stores transcriptions with SwiftData for persistent storage.

# Code style
Use private for functions and proverties that called only from the same entity (struct, enum, class). Use public for functions and properties that called from other entities.

## Build Commands

Use the following commands to build, run and test the app:

- Build: `xcodebuild -scheme VivaDicta -configuration Debug -workspace ./VivaDicta.xcodeproj/project.xcworkspace -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' build | xcbeautify`
- Run tests: `xcodebuild -scheme VivaDicta -configuration Debug -workspace ./VivaDicta.xcodeproj/project.xcworkspace -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' test | xcbeautify`
- Run single test: `xcodebuild -scheme VivaDicta -configuration Debug -workspace ./VivaDicta.xcodeproj/project.xcworkspace -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' test -only-testing:VivaDictaTests/TestClassName/testMethodName | xcbeautify`

## Architecture

### Core Components

- **AppState**: Observable app-wide state management using Swift's `@Observable` macro. Coordinates TranscriptionManager and AIService with mode-based configuration.
- **Transcription Model**: SwiftData model for persistent storage of transcriptions with metadata including text, timestamps, enhanced text, audio file URL, duration, and transcription/enhancement model names.
- **TranscriptionManager**: Central manager coordinating all transcription services (WhisperKit, Parakeet, and cloud providers) with mode-aware model selection.
- **TranscriptionService Protocol**: Abstraction for different transcription backends enabling unified interface across on-device and cloud services.

### App Structure

- **TabBarView**: Main navigation with tabs for recording, transcriptions, models, and settings
- **RecordView/RecordViewModel**: Audio recording interface with AVAudioRecorder integration and real-time audio level monitoring
- **ModelsView**: Management of on-device models (WhisperKit and Parakeet) with download/delete functionality and cloud API configuration
- **TranscriptionsView**: Display and management of saved transcriptions with search functionality and performance-optimized filtering
- **TranscriptionRowView**: Reusable component for transcription list items
- **TranscriptionDetailView**: Detailed view showing both original and AI-enhanced transcription text

### Transcription Services

- **WhisperKitTranscriptionService**: Uses WhisperKit package for on-device OpenAI Whisper model inference with performance metrics tracking
- **ParakeetTranscriptionService**: Uses FluidAudio framework for on-device NVIDIA Parakeet model transcription with VAD (Voice Activity Detection) support
- **CloudTranscriptionService**: Unified service managing multiple cloud providers:
  - **OpenAITranscriptionService**: OpenAI Whisper API
  - **ElevenLabsTranscriptionService**: ElevenLabs speech-to-text
  - **GroqTranscriptionService**: Groq API transcription
  - **DeepgramTranscriptionService**: Deepgram Nova API
  - **GeminiTranscriptionService**: Google Gemini API
- **TranscriptionManager**: Coordinates between on-device (WhisperKit/Parakeet) and cloud services with mode-aware model selection
- **AIService**: AI-powered text enhancement service for improving transcription quality using cloud AI models

### Key Technologies

- **Swift 6.0** with strict concurrency enabled
- **SwiftUI** for UI with SwiftData for persistence
- **AVFoundation** for audio recording/playback
- **WhisperKit** - On-device OpenAI Whisper model inference
- **FluidAudio** - On-device NVIDIA Parakeet model transcription with VAD
- **SiriWaveView** package for audio visualization
- **TipKit** for user onboarding and feature discovery
- **iOS 18+ deployment target**

### Language Support

The app currently supports Auto Detect, English, and Russian languages. The codebase includes infrastructure for 20+ additional languages with localized prompts prepared for future expansion.

### Enhanced Transcription Features

- **AI Text Enhancement**: Dedicated AIService for improving transcription quality using cloud AI models
- **Audio Duration Tracking**: Transcriptions include audio duration metadata for better file management  
- **Search Functionality**: Full-text search across both original and enhanced transcription text
- **Multiple Transcription Providers**: Users can choose from various cloud providers based on their needs and preferences

## Documentation

The `/docs/` directory contains comprehensive reference documentation for Apple technologies:
- `swift.md` - Complete Swift language reference and patterns
- `swift6-migration.mdc` - Swift 6 migration guide and concurrency best practices
- `swift-concurrency.md` - Detailed Swift concurrency patterns and async/await usage
- `swift-observable.mdc` - Swift Observation framework (@Observable macro)
- `swift-argument-parser.mdc` - Swift Argument Parser for command-line tools
- `swift-testing-api.mdc` - Swift Testing framework API reference
- `swift-testing-playbook.mdc` - Swift Testing best practices and patterns
- `swiftdata.md` - SwiftData persistence patterns and model definitions
- `swiftui.md` - SwiftUI patterns, view composition, and state management
- `uikit.md` - UIKit integration and interoperability
- `xcode.md` - Xcode development environment and tools
- `xcode26docs.mdc` - Xcode 26 specific features and documentation

Additional Xcode documentation is available at:
- `/Applications/Xcode.app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/AdditionalDocumentation/` - Latest iOS/Swift development documentation and updates

Refer to these docs when working with Apple frameworks or implementing new features.

There are transcripts of relevand WWDC sessions in the `/docs/wwdc-transcripts`. Use them to find relevant info.
You can find all WWDC transcripts here - https://gist.github.com/auramagi/9c040c2233dfe71c24c76942e186f788

## Performance & Best Practices

- **State Management**: Use `@State` with `onChange` modifiers instead of computed properties for expensive filtering operations
- **Component Extraction**: Extract reusable UI components for better code organization and maintainability
- **Concurrency**: All UI updates properly isolated to `@MainActor` with Swift 6 strict concurrency
- **Memory Management**: Efficient model loading and unloading patterns for on-device transcription models (WhisperKit/Parakeet)


- **Xcode Target Management**: When an EXISTING file needs to be added to ADDITIONAL targets (e.g., adding an existing model file to both widget and keyboard extension targets), notify the user to manually add it in Xcode. This is a simple one-click operation for the user but complex to do programmatically via .xcodeproj file manipulation. NEW files are automatically added to the main app target by default and don't require manual intervention unless they specifically need to be in multiple targets.

## Code Review Guidelines

When reviewing code for this project, keep in mind:
- Use Swift's **@Observable** macro, NOT @ObservableObject/@Published/Combine patterns
- SwiftUI Views are implicitly @MainActor in Swift 6 - explicit annotation usually not needed
- Use **SwiftData @Model**, NOT Core Data NSManagedObject
- Prefer **async/await** over completion handlers
- Use **@State/@Binding** for SwiftUI state, NOT @StateObject
- Extract reusable components for better code organization
- Optimize performance by using @State with onChange for expensive operations instead of computed properties

## SwiftData #Predicate Best Practices

When filtering optional fields in SwiftData predicates, use this proven pattern:

```swift
#Predicate<Model> { item in
    if searchText.isEmpty {
        true
    } else {
        item.requiredField.localizedStandardContains(searchText) ||
        (item.optionalField?.localizedStandardContains(searchText) ?? false)
    }
}
```

**✅ WORKS:**
- Optional chaining with nil coalescing: `optionalField?.method() ?? false`
- Simple boolean logic with `||` and `&&`
- Basic comparisons: `==`, `!=`, `<`, `>`
- `localizedStandardContains()` for text search

**❌ AVOID (causes crashes or failures):**
- Force unwrapping: `optionalField!.method()`
- Explicit nil checking: `optionalField != nil && optionalField!.method()`
- Ternary operators: `(optionalField ?? "").method()`
- Complex Swift expressions that don't translate to SQL

**Key principles:**
- Keep predicates simple - SwiftData has limited Swift-to-SQL translation
- Use `localizedStandardContains` for text search (handles case, diacritics)
- Follow patterns from working examples (VoiceInk, FaceFacts, iExpense)
- Test thoroughly - predicate errors often appear at runtime, not compile time

## SwiftUI
- Don't use NavigationView {}, use modern NavigationStack instead
- Use `foregroundStyle` instead of deprecated `foregroundColor` (iOS 17+)


## AI-Powered PR Review

The repository includes automated GitHub Actions workflow for AI-powered code review with iOS test execution. TypeScript scripts in `/lib/agents/` orchestrate code review generation and test running using either OpenAI or Anthropic APIs.


## Swift Instructions

- Assume strict Swift concurrency rules are being applied.
- Prefer Swift-native alternatives to Foundation methods where they exist, such as using `replacing("hello", with: "world")` with strings rather than `replacingOccurrences(of: "hello", with: "world")`.
- Prefer modern Foundation API, for example `URL.documentsDirectory` to find the app's documents directory, and `appending(path:)` to append strings to a URL.
- Never use C-style number formatting such as `Text(String(format: "%.2f", abs(myNumber)))`; always use `Text(abs(change), format: .number.precision(.fractionLength(2)))` instead.
- Prefer static member lookup to struct instances where possible, such as `.circle` rather than `Circle()`, and `.borderedProminent` rather than `BorderedProminentButtonStyle()`.
- Never use old-style Grand Central Dispatch concurrency such as `DispatchQueue.main.async()`. If behavior like this is needed, always use modern Swift concurrency.
- Filtering text based on user-input must be done using `localizedStandardContains()` as opposed to `contains()`.
- Avoid force unwraps and force `try` unless it is unrecoverable.


## SwiftUI Instructions

- Always use `foregroundStyle()` instead of `foregroundColor()`.
- Always use `clipShape(.rect(cornerRadius:))` instead of `cornerRadius()`.
- Always use the `Tab` API instead of `tabItem()`.
- Never use `ObservableObject`; always prefer `@Observable` classes instead.
- Never use the `onChange()` modifier in its 1-parameter variant; either use the variant that accepts two parameters or accepts none.
- Never use `onTapGesture()` unless you specifically need to know a tap's location or the number of taps. All other usages should use `Button`.
- Never use `Task.sleep(nanoseconds:)`; always use `Task.sleep(for:)` instead.
- Never use `UIScreen.main.bounds` to read the size of the available space.
- Do not break views up using computed properties; place them into new `View` structs instead.
- Do not force specific font sizes; prefer using Dynamic Type instead.
- Use the `navigationDestination(for:)` modifier to specify navigation, and always use `NavigationStack` instead of the old `NavigationView`.
- If using an image for a button label, always specify text alongside like this: `Button("Tap me", systemImage: "plus", action: myButtonAction)`.
- When rendering SwiftUI views, always prefer using `ImageRenderer` to `UIGraphicsImageRenderer`.
- Don't apply the `fontWeight()` modifier unless there is good reason. If you want to make some text bold, always use `bold()` instead of `fontWeight(.bold)`.
- Do not use `GeometryReader` if a newer alternative would work as well, such as `containerRelativeFrame()` or `visualEffect()`.
- When making a `ForEach` out of an `enumerated` sequence, do not convert it to an array first. So, prefer `ForEach(x.enumerated(), id: \.element.id)` instead of `ForEach(Array(x.enumerated()), id: \.element.id)`.
- When hiding scroll view indicators, use the `.scrollIndicators(.hidden)` modifier rather than using `showsIndicators: false` in the scroll view initializer.
- Place view logic into view models or similar, so it can be tested.
- Avoid `AnyView` unless it is absolutely required.
- Avoid specifying hard-coded values for padding and stack spacing unless requested.
- Avoid using UIKit colors in SwiftUI code.


## SwiftData Instructions (CloudKit)

If SwiftData is configured to use CloudKit:

- Never use `@Attribute(.unique)`.
- Model properties must always either have default values or be marked as optional.
- All relationships must be marked optional.


## Project Structure

- Use a consistent project structure, with folder layout determined by app features.
- Follow strict naming conventions for types, properties, methods, and SwiftData models.
- Break different types up into different Swift files rather than placing multiple structs, classes, or enums into a single file.
- Write unit tests for core application logic.
- Only write UI tests if unit tests are not possible.
- Add code comments and documentation comments as needed.
- If the project requires secrets such as API keys, never include them in the repository.
