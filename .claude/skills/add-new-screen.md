---
name: add-new-screen
description: Add a new screen (View) to the VivaDicta iOS app with proper navigation and architecture patterns
---

# Add New Screen

Use this skill when adding a new screen (View) to the VivaDicta iOS app.

## Related Skills

- This skill covers the basic view structure - for SwiftData integration, refer to existing data models
- For navigation patterns, see how SettingsView uses NavigationStack with navigationPath

## Skill Flow

- Example queries:
  - "add a new screen for viewing statistics"
  - "create a new view for user profile"
  - "I need a new screen in the settings tab"
  - "add a detail view for this data"
- Notes:
  - VivaDicta uses SwiftUI with Swift 6 strict concurrency
  - All views use `@Environment(AppState.self)` and `@Environment(Router.self)` — NOT passing appState as a parameter
  - Follow the project's file organization: Views go in `VivaDicta/Views/`
  - Use NavigationStack (NOT deprecated NavigationView)
  - Use `foregroundStyle` instead of deprecated `foregroundColor`
  - Include #Preview for SwiftUI previews
  - The app uses a single NavigationStack in MainView — there is NO TabView

### 1. Determine Screen Type and Location

**Settings sub-screen** if:
- The screen is accessed through navigation from SettingsView
- It's a configuration, preferences, or management screen
- Examples: ModelsView, ModeEditView, AIProvidersView, DictionaryView

→ Continue with **Path A: Settings Sub-Screen** (steps 2A-5A)

**Detail/Push screen** if:
- The screen is accessed via NavigationLink from the main transcriptions list
- It shows detailed information about an item
- Examples: TranscriptionDetailView

→ Continue with **Path B: Detail Screen** (steps 2B-4B)

**Modal/Sheet screen** if:
- The screen should appear as a sheet or full-screen cover
- Temporary action, form input, or standalone flow
- Examples: RecordingSheetView, OnboardingView, WhatsNewView

→ Continue with **Path C: Modal Screen** (steps 2C-4C)

## Path A: Settings Sub-Screen

### 2A. Add SettingsDestination Case

Location: `VivaDicta/Views/SettingsScreen/SettingsDestination.swift`

Add new case to SettingsDestination enum:

```swift
enum SettingsDestination: Hashable {
    case aiProviders
    case promptsSettings
    case promptsTemplates
    case presetsSettings
    case transcriptionModels

    // Dictionary
    case correctSpelling
    case replacements

    case yourNewScreen  // Add your new case
}
```

### 3A. Create the View File

Location: `VivaDicta/Views/SettingsScreen/YourNewView.swift`

```swift
//
//  YourNewView.swift
//  VivaDicta
//
//  Created by [Author] on [Date]
//

import SwiftUI

struct YourNewView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        Form {
            Section("Main Section") {
                Text("Your content here")
            }
        }
        .navigationTitle("Your Title")
    }
}

#Preview {
    NavigationStack {
        YourNewView()
            .environment(AppState())
    }
}
```

### 4A. Add Navigation to SettingsView

Location: `VivaDicta/Views/SettingsScreen/SettingsView.swift`

Add NavigationLink in the appropriate section:

```swift
Section("Your Section") {
    NavigationLink(value: SettingsDestination.yourNewScreen) {
        Text("Your Screen Title")
    }
}
```

Then add to the existing `navigationDestination(for: SettingsDestination.self)` handler:

```swift
case .yourNewScreen:
    YourNewView()
```

### 5A. Test the New Screen

Build and run:

```bash
xcodebuild -scheme VivaDicta -configuration Debug \
  -workspace ./VivaDicta.xcodeproj/project.xcworkspace \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  build 2>&1 | xcsift
```

## Path B: Detail Screen

### 2B. Create the View File

Location: `VivaDicta/Views/YourNewDetailView.swift`

```swift
//
//  YourNewDetailView.swift
//  VivaDicta
//
//  Created by [Author] on [Date]
//

import SwiftUI

struct YourNewDetailView: View {
    @Environment(AppState.self) var appState
    let item: YourModel

    var body: some View {
        ScrollView {
            VStack {
                Text("Detail content here")
            }
        }
        .navigationTitle("Detail Title")
    }
}

#Preview {
    NavigationStack {
        YourNewDetailView(item: .preview)
            .environment(AppState())
    }
}
```

### 3B. Add navigationDestination to MainView

Location: `VivaDicta/Views/MainView.swift`

The main NavigationStack already has a destination for `Transcription`. Add additional destinations in `mainContentView`:

```swift
.navigationDestination(for: YourModel.self) { item in
    YourNewDetailView(item: item)
}
```

### 4B. Test Navigation

Build and navigate to the new screen:

```bash
xcodebuild -scheme VivaDicta -configuration Debug \
  -workspace ./VivaDicta.xcodeproj/project.xcworkspace \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  build 2>&1 | xcsift
```

## Path C: Modal Screen

### 2C. Create the View File

Location: `VivaDicta/Views/YourNewView.swift`

```swift
//
//  YourNewView.swift
//  VivaDicta
//
//  Created by [Author] on [Date]
//

import SwiftUI

struct YourNewView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                Text("Modal content here")
            }
            .navigationTitle("Your Title")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    YourNewView()
        .environment(AppState())
}
```

### 3C. Present from Parent View

Add a `@State` boolean and `.sheet` modifier in the parent view:

```swift
@State private var showingYourView = false

// In body:
.sheet(isPresented: $showingYourView) {
    YourNewView()
}

// Or for full-screen cover (like SettingsView):
.fullScreenCover(isPresented: $showingYourView) {
    YourNewView()
        .interactiveDismissDisabled(true)
}
```

### 4C. Test the Modal

Build and trigger the modal:

```bash
xcodebuild -scheme VivaDicta -configuration Debug \
  -workspace ./VivaDicta.xcodeproj/project.xcworkspace \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  build 2>&1 | xcsift
```

## Common Patterns

### Environment-Based AppState Access

All views access AppState and Router via `@Environment`:

```swift
struct YourNewView: View {
    @Environment(AppState.self) var appState
    @Environment(Router.self) var router  // Only if navigation needed

    var body: some View {
        @Bindable var appState = appState  // Only if two-way binding needed
        Text("Current mode: \(appState.aiService.selectedModeName)")
    }
}
```

### SwiftData Integration

If the view needs to access persisted data:

```swift
struct YourNewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \YourModel.timestamp, order: .reverse)
    private var items: [YourModel]

    var body: some View {
        List(items) { item in
            Text(item.name)
        }
    }
}
```

### State Management

Use `@State` for local view state:

```swift
struct YourNewView: View {
    @State private var searchText = ""
    @State private var isShowingAlert = false

    var body: some View {
        // Use state in view
    }
}
```

### Form-based Settings Screen

```swift
struct YourNewView: View {
    @AppStorage("yourSetting") private var setting = true

    var body: some View {
        Form {
            Section("Settings") {
                Toggle("Enable Feature", isOn: $setting)
            }

            Section {
                Text("Description text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Your Settings")
    }
}
```

## App Navigation Architecture

The app uses a single-screen architecture with `MainView` as the root:

- **MainView** — Root view with NavigationStack, toolbar, overlays
  - Uses `@Environment(Router.self)` for programmatic navigation
  - `NavigationStack(path: $router.path)` with `Transcription` path type
  - Settings presented as `.fullScreenCover`
  - Recording presented as `.sheet`
- **Router** — `@Observable` class with `path: [Transcription]` for navigation state
- **SettingsView** — Presented modally, has its own `NavigationStack(path: $navigationPath)` with `SettingsDestination` enum and `VivaMode` for navigation

## File Organization

```
VivaDicta/Views/
├── MainView.swift                  # Root view (NavigationStack + toolbars)
├── RecordViewModel.swift
├── RecordingSheetView.swift        # Recording sheet
├── TranscriptionsContentView.swift # Transcription list content
├── TranscriptionDetailView.swift   # Transcription detail (push)
├── TranscriptionRowView.swift
├── AudioPlayerView.swift
├── AnimatedCopyButton.swift
├── HudView.swift
├── ScrollToTopButton.swift
├── ShimmerView.swift
├── KeyboardFlowToast.swift
├── Components/                     # Reusable UI components
│   ├── CategoryChipsView.swift
│   ├── LiquidActionButtonView.swift
│   └── StrokeAnimatableShape.swift
├── ModelsScreen/                   # Transcription models
│   ├── AddCustomTranscriptionModelView.swift
│   ├── CloudModelCard.swift
│   ├── CloudModelConfigurationView.swift
│   ├── CustomTranscriptionModelCard.swift
│   ├── LanguageSelectionMenu.swift
│   ├── LocalModelCard.swift
│   ├── ModelPerformanceStatsDots.swift
│   ├── ModelProgressBars.swift
│   ├── ParakeetModelCard.swift
│   └── WhisperKitModelCard.swift
├── SettingsScreen/                 # Settings-related screens
│   ├── SettingsView.swift
│   ├── SettingsDestination.swift
│   ├── ModelsView.swift
│   ├── ModeEditView.swift
│   ├── ModeEditViewModel.swift
│   ├── AIProvidersView.swift
│   ├── AddAPIKeyView.swift
│   ├── CustomOpenAIConfigurationView.swift
│   ├── OllamaConfigurationView.swift
│   ├── DictionaryView.swift
│   ├── ReplacementsView.swift
│   ├── Presets/
│   │   ├── PresetFormView.swift
│   │   └── PresetSettings.swift
│   └── Prompts/
│       ├── PromptsSettings.swift
│       ├── PromptFormView.swift
│       ├── PromptInstructionsEditorView.swift
│       ├── TemplateSectionView.swift
│       └── PromptsManager.swift
├── Onboarding/                     # Onboarding flow
│   ├── OnboardingView.swift
│   ├── OnboardingWelcomePage.swift
│   ├── OnboardingMicrophonePage.swift
│   ├── OnboardingKeyboardPage.swift
│   ├── OnboardingComponents.swift
│   └── KeyboardIllustration.swift
└── WhatsNew/                       # What's New screens
    ├── WhatsNewView.swift
    ├── WhatsNewContent.swift
    └── WhatsNewFeatureRow.swift
```

## Code Style Checklist

- Use `private` for internal functions/properties
- Use `public` for cross-entity access
- Include file header comment with creation date
- Add #Preview at end of file
- Use `NavigationStack`, not `NavigationView`
- Use `foregroundStyle`, not `foregroundColor`
- Use `@Environment(AppState.self)` pattern — NOT passing appState as parameter
- Follow Swift 6 strict concurrency (use @MainActor where needed)
