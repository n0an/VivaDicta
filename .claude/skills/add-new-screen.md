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
- Notes:
  - VivaDicta uses SwiftUI with Swift 6 strict concurrency
  - All views should use `@Observable` AppState, NOT @ObservableObject
  - Follow the project's file organization: Views go in `VivaDicta/Views/`
  - Use NavigationStack (NOT deprecated NavigationView)
  - Use `foregroundStyle` instead of deprecated `foregroundColor`
  - Include #Preview for SwiftUI previews

### 1. Determine Screen Type and Location

**Tab-level screen** if:
- The screen is a primary navigation destination
- It needs its own tab in TabBarView
- Examples: RecordView, TranscriptionsView, SettingsView

→ Continue with **Path A: Tab-Level Screen** (steps 2A-5A)

**Nested screen** if:
- The screen is accessed through navigation from an existing tab
- It's a detail view or sub-settings screen
- Examples: TranscriptionDetailView, ModelsView, ModeEditView

→ Continue with **Path B: Nested Screen** (steps 2B-5B)

## Path A: Tab-Level Screen

### 2A. Update TabTag Enum

Location: `VivaDicta/AppState.swift`

Add new case to TabTag enum:

```swift
enum TabTag {
    case record
    case transcriptions
    case settings
    case yourNewTab  // Add your new tab
}
```

### 3A. Create the View File

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
    var appState: AppState

    var body: some View {
        NavigationStack {
            VStack {
                Text("Your New View")
                // Add your UI here
            }
            .navigationTitle("Your Title")
        }
    }
}

#Preview {
    @Previewable @State var appState = AppState.forPreview()
    YourNewView(appState: appState)
}
```

### 4A. Add Tab to TabBarView

Location: `VivaDicta/Views/TabBarView.swift`

Add new Tab inside TabView:

```swift
TabView(selection: $appState.selectedTab) {

    Tab("Record", systemImage: "waveform.circle.fill", value: TabTag.record) {
        RecordView(appState: appState)
    }

    Tab("Notes", systemImage: "text.document", value: TabTag.transcriptions) {
        TranscriptionsView(appState: appState)
    }

    Tab("Your Tab", systemImage: "star.fill", value: TabTag.yourNewTab) {
        YourNewView(appState: appState)
    }

    Tab("Settings", systemImage: "gear", value: TabTag.settings) {
        SettingsView(appState: appState)
    }
}
```

### 5A. Test the New Tab

Build and run:

```bash
xcodebuild -scheme VivaDicta -configuration Debug \
  -workspace ./VivaDicta.xcodeproj/project.xcworkspace \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  build | xcbeautify
```

## Path B: Nested Screen

### 2B. Determine Navigation Pattern

**NavigationLink from List** if:
- Navigating to a detail view from a list item
- Example: TranscriptionsView → TranscriptionDetailView

**NavigationLink with Destination Enum** if:
- Multiple destination types from the same screen
- Example: SettingsView uses SettingsDestination enum

**Modal Presentation** if:
- The screen should appear as a sheet/modal
- Temporary action or form input

### 3B. Create the View File

Location: `VivaDicta/Views/[Category]/YourNewView.swift`

For settings-related screens, use `VivaDicta/Views/SettingsScreen/`

```swift
//
//  YourNewView.swift
//  VivaDicta
//
//  Created by [Author] on [Date]
//

import SwiftUI

struct YourNewView: View {
    // Add required state/bindings
    // Example: var appState: AppState
    // Example: @Binding var navigationPath: NavigationPath

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
    @Previewable @State var appState = AppState.forPreview()
    NavigationStack {
        YourNewView()
    }
}
```

### 4B. Add Navigation to Parent View

**Option 1: Simple NavigationLink**

Location: Parent view file (e.g., `SettingsView.swift`)

```swift
Section("Your Section") {
    NavigationLink(value: SettingsDestination.yourNewScreen) {
        Text("Your Screen Title")
    }
}
```

Then add to navigationDestination:

```swift
.navigationDestination(for: SettingsDestination.self) { destination in
    switch destination {
    case .promptsSettings:
        PromptsSettings(promptsManager: promptsManager)
    case .transcriptionModels:
        ModelsView(appState: appState)
    case .yourNewScreen:
        YourNewView()
    }
}
```

Don't forget to add case to SettingsDestination enum:

Location: `VivaDicta/Views/SettingsScreen/SettingsDestination.swift`

```swift
enum SettingsDestination: Hashable {
    case promptsSettings
    case transcriptionModels
    case yourNewScreen
}
```

**Option 2: Direct NavigationLink**

```swift
NavigationLink(destination: YourNewView()) {
    Text("Your Screen Title")
}
```

### 5B. Test Navigation

Build and navigate to the new screen:

```bash
xcodebuild -scheme VivaDicta -configuration Debug \
  -workspace ./VivaDicta.xcodeproj/project.xcworkspace \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  build | xcbeautify
```

## Common Patterns

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

### AppState Access

Pass AppState from parent:

```swift
struct YourNewView: View {
    var appState: AppState

    var body: some View {
        // Access app-wide state
        Text("Current mode: \(appState.selectedMode.name)")
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

## File Organization

```
VivaDicta/Views/
├── TabBarView.swift              # Main tab container
├── RecordView.swift              # Tab-level views
├── RecordViewModel.swift
├── TranscriptionsView.swift
├── TranscriptionDetailView.swift
├── TranscriptionRowView.swift
├── AudioPlayerView.swift
├── AnimatedCopyButton.swift
├── ModelsScreen/                 # Models-related screens
│   ├── CloudModelCard.swift
│   ├── CloudModelConfigurationView.swift
│   ├── LanguageSelectionMenu.swift
│   ├── ModelPerformanceStatsDots.swift
│   ├── ParakeetModelCard.swift
│   └── WhisperKitModelCard.swift
├── SettingsScreen/               # Settings-related screens
│   ├── SettingsView.swift
│   ├── SettingsDestination.swift
│   ├── ModelsView.swift
│   ├── ModeEditView.swift
│   ├── ModeEditViewModel.swift
│   ├── AddAPIKeyView.swift
│   └── Prompts/                  # Prompts sub-category
│       ├── PromptsSettings.swift
│       ├── PromptAddView.swift
│       ├── PromptEditingView.swift
│       ├── TemplateSectionView.swift
│       └── PromptsManager.swift
└── [YourCategory]/               # Create folders for related views
```

## Code Style Checklist

- ✅ Use `private` for internal functions/properties
- ✅ Use `public` for cross-entity access
- ✅ Include file header comment with creation date
- ✅ Add #Preview at end of file
- ✅ Use `NavigationStack`, not `NavigationView`
- ✅ Use `foregroundStyle`, not `foregroundColor`
- ✅ Use `@Observable` AppState pattern
- ✅ Follow Swift 6 strict concurrency (use @MainActor where needed)
