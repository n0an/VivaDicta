# AGENTS.md

This file provides guidance for coding agents working in this repository.
If you don't know answer - it's ok to say that you don't know. It's not necessary to please me and be very polite with me. I'm not pleased if you always agree with everything I'm saying. I'm pleased when you provide correct answers, even if I don't like these answers.

## Skills

Canonical custom skills live in `.agents/skills/` as directories containing `SKILL.md`. `.claude/skills/` mirrors only Claude-compatible skills for compatibility and should contain only symlinks to `.agents/skills/`. Codex-only skills do not need a `.claude` mirror.

## Git Commit & PR Guidelines
- NEVER commit and push without asking the user first - always ask "do we need to commit and push at the moment?" before executing git commit or git push commands, unless the user explicitly invokes `$pr` or `$prcdx`
- Treat `$pr` and `$prcdx` as explicit approval to create a branch if needed, commit, push, and open the PR without separate confirmation
- When user asks to commit/push, ALWAYS run `git status` first instead of relying on chat context — files may have been modified externally
- When opening a PR, use `$prcdx` in Codex. In Claude Code, use `/pr`.

## App Store Connect

- **App ID**: `6758147238`
- **App Name**: VivaDicta - Speech to Text
- **Bundle ID**: `com.antonnovoselov.VivaDicta`
- **Submission quirk**: `asc review submissions-create` creates an empty draft — it does NOT add the version item. Either use `asc submit create` for simple submissions, or follow `submissions-create` with `items-add` + `submissions-submit`. When in doubt, tell the user to submit via the "Add for Review" button in App Store Connect.

## Build Commands

- Build: `xcodebuild -scheme VivaDicta -configuration Debug -workspace ./VivaDicta.xcodeproj/project.xcworkspace -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.4' build 2>&1 | xcsift`
- Run tests: `xcodebuild -scheme VivaDicta -configuration Debug -workspace ./VivaDicta.xcodeproj/project.xcworkspace -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.4' test 2>&1 | xcsift`
- Run single test: `xcodebuild -scheme VivaDicta -configuration Debug -workspace ./VivaDicta.xcodeproj/project.xcworkspace -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.4' test -only-testing:VivaDictaTests/TestClassName/testMethodName 2>&1 | xcsift`

## Test Coverage

**Coverage is a runtime metric — you MUST run the tests to get it.** It measures which executable lines were actually *executed*, so it cannot be derived by reading the codebase. Do not confuse it with the test/prod **LOC ratio** (`test_loc ÷ prod_loc`), which is a static line count (a proxy for test *effort*, not *effectiveness*) — that one you compute without running anything via `python3 llmtemp/loc_history.py`.

### Per SPM module (fast — runs on the macOS host, no simulator)

```bash
cd Modules/<Module>
xcrun swift test --enable-code-coverage
BIN=$(find .build -name "<Module>PackageTests" -type f -path "*MacOS*" | head -1)
PROF=$(find .build -name "default.profdata" | head -1)
xcrun llvm-cov report "$BIN" -instr-profile="$PROF" -ignore-filename-regex='Tests|\.build|Mocks' Sources/<Module>/
# one file: end with Sources/<Module>/<File>.swift instead of the dir
# annotated source (which lines are uncovered): swap `report` -> `show --format=text`
```

`llvm-cov` needs both halves: the **test binary** (carries the counter→source-line mapping) and **`default.profdata`** (the runtime hit counts SPM merges under `.build/<arch>/debug/codecov/`).

Caveat: the macOS-host run **excludes iOS-only files**, so a module's total differs slightly from Xcode's simulator number (e.g. CloudTranscription reads ~2,231 lines here vs ~3,073 in Xcode). Use it for *relative* per-file progress; treat Xcode/`xccov` as the canonical total. After a toolchain bump, `rm -rf .build` once (stale `.swiftmodule` import error).

### Whole app / test plan (slow — simulator, canonical number)

```bash
xcodebuild test -scheme VivaDicta \
  -workspace ./VivaDicta.xcodeproj/project.xcworkspace \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.4' \
  -enableCodeCoverage YES -resultBundlePath /tmp/cov.xcresult
xcrun xccov view --report --only-targets /tmp/cov.xcresult   # one row per target
# variants: drop --only-targets for per-file; add --json for machine-readable; `--file <abs path>` for one file
```

`xccov` reads the `.xcresult` bundle directly (it finds the binaries + profile inside), so you don't pass them by hand. It respects the test plan's coverage-target list.

### Test plan coverage config — keep it first-party-only

`VivaDicta/VivaDictaTestPlan.xctestplan` must pin `defaultOptions.codeCoverage` to an explicit **`targets` list of only first-party targets** (the 16 SPM modules + `VivaDicta` app + the 4 extensions = 21 targets). **If that key is absent, Xcode gathers coverage for ALL targets** — Firebase / Google / GUL\* / KeyboardKit / LumoKit / Transformers get swept in and the headline % is meaningless (e.g. FirebaseCrashlytics alone is ~10,653 lines). Exclude all `*Mocks` and `*Tests` targets too — only production targets belong in the list. The file is JSON; validate edits with `python3 -c "import json; json.load(open('VivaDicta/VivaDictaTestPlan.xctestplan'))"` (`plutil -lint` rejects the `.xctestplan` extension even when the JSON is valid).

### Whole-number reality

The overall app coverage is dominated by the **~73k-line `VivaDicta.app` target (~7%)**, so module-level test work barely moves the global %. Judge progress by **per-logic-module coverage**, not the headline number. UI/Views are covered by acceptance + snapshot tests, never unit line-coverage.

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
- **Providers** (16 LLM/text providers, see `AIProvider.generalProviders`): OpenAI, Anthropic, Google Gemini, Groq, Cerebras, Mistral, xAI (Grok), OpenRouter, Z.AI, Kimi (Moonshot), Vercel AI Gateway, HuggingFace, GitHub Copilot, Ollama, Custom OpenAI-compatible, Apple Foundation Model (iOS 26+). Speech-only providers (ElevenLabs, Deepgram, Soniox, Gladia, Speechmatics, Cohere, Cartesia) also live in the `AIProvider` enum but are not used for text processing.
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

## Key Technologies

- **Swift 6.2** with strict concurrency
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
- **Schema deployment**: When SwiftData models change (new models, fields, or relationships), the CloudKit schema must be deployed from Development to Production via the CloudKit Dashboard **before** submitting the app update. Otherwise iCloud sync silently fails for App Store users. See `$release-prepare` skill Step 8.

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
- **All WWDC 2025 transcripts index**: https://gist.github.com/auramagi/9c040c2233dfe71c24c76942e186f788

### Building DocC Documentation

Run `./build-docc.sh` from the project root on the `main` branch. The script builds the DocC archive, transforms it for static hosting, and deploys to the `gh-pages` branch automatically.

## Debugging & Logs

- Use `$start-logs` + `$stop-logs` (simulator), `$start-logs-device` + `$stop-logs-device` (device real-time), or `$start-logs-device-structured` + `$stop-logs-device-structured` (device with extensions).
- All logging uses `Logger` from `os` framework via `LoggerExtension.swift`. Use `logger.logInfo()`, `logger.logError()` etc. — never raw `print()`.

## Swift Instructions

- Assume strict Swift concurrency rules are being applied.
- Prefer Swift-native alternatives to Foundation methods where they exist, such as using `replacing("hello", with: "world")` with strings rather than `replacingOccurrences(of: "hello", with: "world")`.
- Prefer modern Foundation API, for example `URL.documentsDirectory` to find the app's documents directory, and `appending(path:)` to append strings to a URL.
- Never use C-style number formatting such as `Text(String(format: "%.2f", abs(myNumber)))`; always use `Text(abs(change), format: .number.precision(.fractionLength(2)))` instead. Use skill swift-format-style to use proper number and date format.
- Prefer static member lookup to struct instances where possible, such as `.circle` rather than `Circle()`, and `.borderedProminent` rather than `BorderedProminentButtonStyle()`.
- Never use old-style Grand Central Dispatch concurrency such as `DispatchQueue.main.async()`. If behavior like this is needed, always use modern Swift concurrency.
- Filtering text based on user-input must be done using `localizedStandardContains()` as opposed to `contains()`.
- Avoid force unwraps and force `try` unless it is unrecoverable.
- Never use legacy `Formatter` subclasses (`DateFormatter`, `NumberFormatter`); always use `FormatStyle` API instead. Use skill swift-format-style to use proper number and date format.

## SwiftUI Instructions

- Always use `foregroundStyle()` instead of `foregroundColor()`.
- Always use `clipShape(.rect(cornerRadius:))` instead of `cornerRadius()`.
- Always use the `Tab` API instead of `tabItem()`.
- Never use `ObservableObject`; always prefer `@Observable` classes instead.
- Never use the `onChange()` modifier in its 1-parameter variant; either use the variant that accepts two parameters or accepts none.
- Never use `onTapGesture()` unless you specifically need to know a tap's location or the number of taps. All other usages should use `Button`.
- Don't add `.pickerStyle(.menu)` or `.tint(.primary)` to a `Picker` inside a `Form` (or `List`). A `Form` `Picker` already defaults to a menu where the entire row is tappable; adding those modifiers is redundant and makes only part of the row tappable. Leave them off so the whole row stays tappable.
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
- Prefer newest ScrollView APIs (`ScrollPosition`, `defaultScrollAnchor`) over older scroll management approaches.
