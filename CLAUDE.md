# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.
If you don't know answer - it's ok to say that you don't know. It's not necessary to please me and be very polite with me. I'm not pleased if you always agree with everything I'm saying. I'm pleased when you provide correct answers, even if I don't like these answers.

## Skills

All skills live in `.claude/skills/`. Use `/create-skill` to create new ones when you see repeated patterns.

## Git Commit & PR Guidelines
- NEVER commit and push without asking the user first - always ask "do we need to commit and push at the moment?" before executing git commit or git push commands
- When user asks to commit/push, ALWAYS run `git status` first instead of relying on chat context — files may have been modified externally
- When opening a PR, immediately post a comment with "@claude please review this PR" to request a review — do this by default. Skip only if the user explicitly says not to request a review. After requesting the review, start polling PR comments every 2 minutes (using `/loop 2m`) to fetch Claude's review. Stop polling once the full review is received and show it to the user.

## Build Commands

- Build: `xcodebuild -scheme VivaDicta -configuration Debug -workspace ./VivaDicta.xcodeproj/project.xcworkspace -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.4' build 2>&1 | xcsift`
- Run tests: `xcodebuild -scheme VivaDicta -configuration Debug -workspace ./VivaDicta.xcodeproj/project.xcworkspace -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.4' test 2>&1 | xcsift`
- Run single test: `xcodebuild -scheme VivaDicta -configuration Debug -workspace ./VivaDicta.xcodeproj/project.xcworkspace -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.4' test -only-testing:VivaDictaTests/TestClassName/testMethodName 2>&1 | xcsift`

## App Overview

VivaDicta is an iOS voice transcription app with on-device (WhisperKit, Parakeet) and cloud transcription, AI text processing via multiple providers, and CloudKit sync with a companion macOS app (VivaDictaMac).

## Architecture

### Core Flow: Recording → Transcription → AI Processing → Storage

1. **RecordView/RecordViewModel** — records audio via AVAudioRecorder
2. **TranscriptionManager** — routes to on-device (WhisperKit/Parakeet) or cloud provider
3. **AIService** — AI text processing using the mode's active preset. Builds system/user messages via `PromptsTemplates`, sends to cloud providers or Apple Foundation Model
4. **Text Processing Pipeline** — multi-stage: raw text → word replacements → custom vocabulary → AI processing → output filter → paragraph formatting → text insertion formatting. See `documentation/text-processing-pipeline.md`
5. **Transcription** (SwiftData) — persisted with `text`, `enhancedText`, audio file reference, and linked `TranscriptionVariation` records

### Data Model: Transcription + Variations (Dual-Write Pattern)

- **`Transcription`** — SwiftData model with `text` (original), `enhancedText` (latest AI output cache), and `@Relationship(deleteRule: .cascade) var variations: [TranscriptionVariation]?`
- **`TranscriptionVariation`** — each AI-generated output stored separately with `presetId`, `text`, `aiModelName`, `processingDuration`, etc.
- **Dual-write**: When AI processes text, both `transcription.enhancedText` and a `TranscriptionVariation` are written. When a new variation is generated from TranscriptionDetailView, `enhancedText` is updated to the latest result.
- **`enhancedText`** serves as a "latest AI output" cache read by: list row preview, search predicate, Spotlight indexing, Shortcuts/App Intents, clipboard operations
- **`VariationMigrationService`** — one-time migration of legacy `enhancedText` values to "regular" variations on first launch

### Preset System

- **`Preset`** — in-memory value type with `id`, `name`, `instructions`, `icon`
- **`PresetCatalog`** — static catalog of built-in presets (Regular, Summary, Action Points, Professional, Casual, Email, Chat, Coding, Rewrite, translations, Assistant) with stable UUIDs
- **`PresetManager`** — manages active presets, merges built-in + custom, handles mode-to-preset mapping
- **`CustomRewritePreset`** — SwiftData model for user-created presets, synced via CloudKit
- **`PresetSyncService`** — bridges UserDefaults-stored preset selections with SwiftData/CloudKit for cross-device sync of edited built-in presets

### AI Processing (AIService)

- **`AIService`** — central service for all AI text processing. Uses `VivaMode` for per-mode configuration (provider, model, preset)
- **`PromptsTemplates`** — unified system prompt template used by all providers (cloud and Apple FM)
- **Providers**: OpenAI, Anthropic, Google Gemini, Mistral, Groq, OpenRouter, xAI, Ollama, Custom OpenAI-compatible, Apple Foundation Model (iOS 26+)
- **`generateVariation(text:preset:)`** — generates AI output for a specific preset, returns `(text, duration)`
- **`makeRequest()`** — core method routing to the correct provider. Accepts optional `systemMessage`/`preFormattedUserMessage` for variation generation with custom presets

### App Extensions & Targets

- **VivaDictaKeyboard** — custom keyboard extension with recording/transcription. Communicates with main app via `AppGroupCoordinator` and shared UserDefaults
- **VivaDictaWidget** — home/lock screen widgets + Live Activity for recording status
- **ActionExtension** — action extension for receiving audio from other apps
- **ShareExtension** — share extension for receiving audio from other apps

### Cross-Platform Sync

- CloudKit container `iCloud.com.antonnovoselov.VivaDicta` shared with macOS VivaDictaMac app
- SwiftData models (`Transcription`, `TranscriptionVariation`, `CustomRewritePreset`, `VocabularyWord`, `WordReplacement`) sync automatically
- API keys stored in iCloud Keychain via `KeychainService` for cross-device access
- Preset ID compatibility: iOS uses string aliases ("regular", "summary") that map to stable UUIDs on both platforms

### Spotlight & App Intents

- **`TranscriptionEntity`** — `@AppEntity` for Shortcuts/Siri integration. Created from `Transcription.entity` computed property. Has its own `searchableAttributes` for Spotlight indexing
- **`Transcription.searchableAttributes()`** — generates `CSSearchableItemAttributeSet` for `NSUserActivity` (Siri predictions). Includes all variation text
- Spotlight must be re-indexed after any data change (transcription creation, variation generation, retranscription)

## Code Style

- Use `private` for functions/properties called only within the same type. Use `public` for cross-type access.
- Use "AI Processing" terminology (not "AI Enhancement") in UI-facing text and status labels

## Key Technologies

- **Swift 6.0** with strict concurrency
- **SwiftUI** + **SwiftData** with CloudKit
- **iOS 18+ deployment target**
- **AVFoundation** for audio recording/playback
- **WhisperKit** / **FluidAudio** (Parakeet) for on-device transcription
- **CoreSpotlight** + **App Intents** for system integration

## SwiftData #Predicate Best Practices

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

**Works:** Optional chaining with `?? false`, simple boolean logic, basic comparisons, `localizedStandardContains()`

**Avoid (crashes):** Force unwrapping, explicit nil checks with `&&`, ternary operators, complex Swift expressions that don't translate to SQL

## SwiftData + CloudKit Rules

- Never use `@Attribute(.unique)`
- Model properties must have default values or be optional
- All relationships must be optional

## Xcode Target Management

When an EXISTING file needs to be added to ADDITIONAL targets, notify the user to manually add it in Xcode. NEW files are automatically added to the main app target.

## Documentation

- **Architecture docs**: `/documentation/` — covers all major subsystems:
  - Recording pipeline, Transcription system, AI processing, Text processing pipeline
  - Preset system, AppGroupCoordinator
  - Data persistence & CloudKit sync, Deep linking & URL routing
  - Keyboard extension, App Intents & Shortcuts
  - Widget & Live Activity, Hot Mic / Audio Prewarm
- **Text processing pipeline**: `/documentation/text-processing-pipeline.md`
- **DocC site**: https://n0an.github.io/VivaDicta/ — built via `./build-docc.sh`, hosted on `gh-pages` branch
- **Additional Xcode docs**: `/Applications/Xcode.app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/AdditionalDocumentation/`
- **All WWDC transcripts index**: https://gist.github.com/auramagi/9c040c2233dfe71c24c76942e186f788

### Building DocC Documentation

Run `./build-docc.sh` from the project root on the `main` branch. The script builds the DocC archive, transforms it for static hosting, and deploys to the `gh-pages` branch automatically.

## Debugging & Logs

- **Simulator logs**: `/start-logs` + `/stop-logs`
- **Device logs (main app only, real-time)**: `/start-logs-device` + `/stop-logs-device` — launches app via `devicectl` with `ENABLE_PRINT_LOGS=1`
- **Device logs (all processes, post-hoc)**: `/start-logs-device-structured` + `/stop-logs-device-structured` — uses `sudo log collect` to capture OSLog from main app AND extensions (keyboard, widget, share). Use this when debugging interaction between main app and extensions.
- All logging uses `Logger` from `os` framework via `LoggerExtension.swift`. Use `logger.logInfo()`, `logger.logError()` etc. — never raw `print()`.

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
- Use `@State` with `onChange` modifiers instead of computed properties for expensive filtering operations.
- SwiftUI Views are implicitly @MainActor in Swift 6 — explicit annotation usually not needed.
- Use **@State/@Binding** for SwiftUI state, NOT @StateObject.
