# App Intents & Shortcuts Architecture

## Overview

VivaDicta integrates with Siri, Shortcuts, Spotlight, and Control Center through the App Intents framework. The system exposes five user-facing shortcuts, a control widget, and a Live Activity intent. Transcriptions are surfaced in Spotlight via `IndexedEntity` and Siri prediction via `NSUserActivity`. All intents that read or write transcription data resolve their SwiftData access through a registered `DataController` dependency, keeping them decoupled from the SwiftUI view hierarchy.

## Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        App Intents Surface                                   │
│                                                                              │
│  Siri / Spotlight          Shortcuts App           Control Center            │
│  ┌───────────────┐         ┌─────────────┐         ┌──────────────────────┐ │
│  │ Voice phrases │         │ Automations │         │ ControlWidgetButton  │ │
│  │ Predictions   │         │ App gallery │         │ (ToggleRecordIntent) │ │
│  └──────┬────────┘         └──────┬──────┘         └──────────┬───────────┘ │
│         │                        │                            │             │
│  ┌──────▼────────────────────────▼────────────────────────────▼───────────┐ │
│  │                        ShortcutsProvider                               │ │
│  │  (AppShortcutsProvider — declares 5 shortcuts + 16 voice phrases)      │ │
│  └──┬──────────────┬──────────────┬───────────────┬──────────────┬────────┘ │
│     │              │              │               │              │          │
│  ToggleRecord   CountRecent  TranscriptionReminder AddToRecent  OpenSnippet │
│  Intent         Intent       Intent                Intent        Intent     │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │              @Dependency injection (AppDependencyManager)               │ │
│  │              DataController  ←─────────────────────────────             │ │
│  │              Router          ←─────────── OpenTranscriptionIntent       │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                TranscriptionEntity (IndexedEntity)                   │   │
│  │  • @Property text, enhancedText, timestamp, audioDuration            │   │
│  │  • searchableAttributes → CSSearchableItemAttributeSet               │   │
│  │  • TranscriptionEntityDefaultQuery → EnumerableEntityQuery           │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  Spotlight                     Siri Predictions                             │
│  ┌─────────────────────────┐   ┌──────────────────────────────────────────┐ │
│  │ CSSearchableIndex        │   │ NSUserActivity                           │ │
│  │ .indexAppEntities()      │   │ isEligibleForSearch = true               │ │
│  │ .deleteAppEntities()     │   │ isEligibleForPrediction = true           │ │
│  │ (AppState calls)         │   │ donated via activity.becomeCurrent()     │ │
│  └─────────────────────────┘   └──────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────┘
```

## ShortcutsProvider

```
ShortcutsProvider (AppShortcutsProvider)
    │
    ├── shortcutTileColor = .lime
    │
    ├── ToggleRecordIntent
    │     phrases: "Record in VivaDicta", "Note in VivaDicta",
    │              "Transcribe in VivaDicta", "Dictate in VivaDicta",
    │              "Voice note in VivaDicta" ... (16 total)
    │
    ├── CountRecentTranscriptionsIntent
    │     phrases: "Count my recent notes in VivaDicta"
    │
    ├── TranscriptionReminderIntent
    │     phrases: "Remind me of a VivaDicta note"
    │
    ├── AddToRecentTranscriptionIntent
    │     phrases: "Add to my most recent note in VivaDicta"
    │
    └── OpenTranscriptionSnippetIntent
          phrases: "Open a note in VivaDicta"
```

`ShortcutsProvider.updateAppShortcutParameters()` is called once at app launch (in `VivaDictaApp.init()`) to register the phrase list with the system. All phrases use the `\(.applicationName)` token so the app's display name is interpolated automatically — this is required by the App Intents framework to prevent phrase collisions across apps.

## Intent Implementations

### ToggleRecordIntent

```
ToggleRecordIntent (AppIntent)
    │
    ├── openAppWhenRun = true           — brings app to foreground
    ├── supportedModes = .foreground(.immediate)  (iOS 26+)
    │
    └── perform()
          │
          ├── Read AppGroupCoordinator.shared.isRecording
          ├── If recording  → requestStopRecording()
          └── If idle       → requestStartRecordingFromControl()
```

`AppGroupCoordinator` writes the recording toggle to shared App Group `UserDefaults`, which the main app's `RecordViewModel` observes via Darwin notifications. The intent does not directly call `RecordViewModel` — the coordinator acts as the communication bridge. This design works from Control Center, Siri, and Shortcuts without requiring the app to be foregrounded first (the coordinator write happens before app launch, the app picks it up on `applicationDidBecomeActive`).

On iOS 26+, `supportedModes = .foreground(.immediate)` causes Siri to transition immediately to the app's foreground UI rather than showing a Siri overlay, which is the correct UX for a recording-start action.

At app launch, `IntentDonationManager.shared.donate(intent: ToggleRecordIntent())` donates the intent to Siri so it appears as a suggested shortcut before the user has explicitly run it.

### CountRecentTranscriptionsIntent

```
CountRecentTranscriptionsIntent (AppIntent)
    │
    ├── @Dependency dataController: DataController
    │
    └── perform()
          │
          ├── Compute dateCutOff = .now minus 1 month
          ├── dataController.transcriptionCount(matching predicate)
          ├── Format with AttributedString inflection
          │   "You've had ^[N note](inflect: true)."
          └── Return .result(value: Int, dialog: String)
                     ↑ value is returned to Shortcuts for downstream use
```

The `ReturnsValue<Int>` conformance makes the count available as a variable in Shortcuts automations. The dialog uses `AttributedString` with `inflect: true` so "1 note" / "3 notes" grammatical agreement is handled automatically.

### TranscriptionReminderIntent

```
TranscriptionReminderIntent (AppIntent)
    │
    ├── @Dependency dataController: DataController
    ├── @Parameter transcription: TranscriptionEntity  — user picks via entity query
    │
    └── perform()
          │
          └── Return .result(dialog: transcription.text(withPrefix: 200))
                         Siri speaks the first 200 characters of the note
```

The `@Parameter` annotated with `TranscriptionEntity` causes Siri / Shortcuts to prompt the user to select a specific transcription. The entity picker is backed by `TranscriptionEntityDefaultQuery.allEntities()`, which returns the 100 most recent transcriptions for display.

### AddToRecentTranscriptionIntent

```
AddToRecentTranscriptionIntent (AppIntent)
    │
    ├── @Dependency dataController: DataController
    ├── @Parameter newText: String  — Siri asks the user for text to append
    │
    └── perform() @MainActor
          │
          ├── Fetch most recent transcription (limit: 1)
          ├── If found: append " {newText}" to transcription.text
          │            save modelContext
          │            return .result(dialog: "Done")
          └── If not found: return .result(dialog: "You haven't recorded any notes yet.")
```

This intent mutates SwiftData directly via `modelContext.save()`. It is marked `@MainActor` because `ModelContext` operations on the main context must run on the main actor in SwiftData with strict concurrency.

### OpenTranscriptionIntent

```
OpenTranscriptionIntent (OpenIntent)
    │
    ├── @Dependency dataController: DataController
    ├── @Dependency router: Router
    ├── @Parameter target: TranscriptionEntity
    │
    └── perform() @MainActor
          │
          ├── dataController.transcription(byId: target.id)
          └── router.select(transcription:)  — triggers NavigationStack push
```

`OpenIntent` is an App Intents protocol that signals to the system that this intent navigates to a specific piece of content. The `Router` dependency is registered in `VivaDictaApp.init()` via `AppDependencyManager.shared.add(dependency: router)` and resolves the navigation destination within the running app. `OpenTranscriptionIntent` is not listed in `ShortcutsProvider` — it is used as a system-facing navigation intent (e.g. from Spotlight search result taps).

### OpenTranscriptionSnippetIntent

```
OpenTranscriptionSnippetIntent (AppIntent)
    │
    ├── @Parameter target: TranscriptionEntity
    │
    └── perform()
          │
          └── Return .result(dialog: target.subtitle)
                   { snippet view: VStack { Text(target.text(withPrefix: 200)) } }
```

This intent conforms to `ProvidesDialog & ShowsSnippetView`, which causes Siri to display an inline SwiftUI snippet rather than opening the app. It is declared in `ShortcutsProvider` under the phrase "Open a note in VivaDicta". The snippet view shows up to 200 characters of the selected transcription's text (preferring `enhancedText` over raw `text`).

### Widget Intents

```
ToggleSessionIntent (LiveActivityIntent)     — VivaDictaWidget target
    │
    ├── @Parameter isSessionActive: Bool
    ├── isDiscoverable = false               — hidden from Shortcuts gallery
    │
    └── perform()
          │
          ├── If !isSessionActive:
          │   ├── AppGroupCoordinator.shared.requestTerminateSessionFromLiveActivity()
          │   └── End all VivaDictaLiveActivityAttributes activities immediately
          └── Return .result()

ConfigurationAppIntent (WidgetConfigurationIntent)   — VivaDictaWidget target
    │
    ├── @Parameter widgetColorString: String  (DynamicOptionsProvider → WidgetColor)
    └── Consumed by VivaDictaWidget to configure mesh gradient color
```

`ToggleSessionIntent` is a `LiveActivityIntent` bound to the Dynamic Island / Lock Screen Live Activity stop button. It is marked `isDiscoverable = false` so it does not appear in the Shortcuts app gallery. `ConfigurationAppIntent` is the widget configuration intent shown when a user long-presses the home screen widget.

## TranscriptionEntity

```
TranscriptionEntity (IndexedEntity)
    │
    ├── Conforms to IndexedEntity (AppEntity + CSSearchableItem integration)
    ├── typeDisplayRepresentation = "Note"
    ├── defaultQuery = TranscriptionEntityDefaultQuery()
    │
    ├── Exposed to Shortcuts (@Property):
    │   • text: String
    │   • enhancedText: String?
    │   • timestamp: Date
    │   • audioDuration: TimeInterval (title: "Duration")
    │
    ├── Internal metadata (not exposed to Shortcuts):
    │   • audioFileName, transcriptionModelName, transcriptionProviderName
    │   • aiEnhancementModelName, aiProviderName, promptName
    │   • transcriptionDuration, enhancementDuration
    │
    ├── searchableAttributes: CSSearchableItemAttributeSet
    │   • title     → first 100 chars of enhancedText ?? text (or date fallback)
    │   • contentDescription → original text + "\n\n" + enhancedText (both searchable)
    │   • keywords  → [promptName, transcriptionModelName, aiEnhancementModelName]
    │   • duration  → audioDuration (NSNumber)
    │   • contentCreationDate / contentModificationDate → timestamp
    │   • kind      → "Voice Transcription"
    │   • identifier / relatedUniqueIdentifier → id.uuidString
    │
    └── displayRepresentation
          title    → first 50 chars of enhancedText ?? text
          subtitle → timestamp formatted as "Jan 1, 2026, 9:00 AM"
          image    → systemName "text.page"
```

`IndexedEntity` combines `AppEntity` with automatic `CSSearchableIndex` integration. When `CSSearchableIndex.indexAppEntities([entity])` is called, the framework uses `searchableAttributes` to generate the Spotlight item. The `relatedUniqueIdentifier` field links the Spotlight item back to the `AppEntity` so tapping a Spotlight result can resolve the entity for navigation.

`Transcription.entity` is a computed property that constructs a `TranscriptionEntity` from the `@Model` instance. It is used both for Spotlight indexing and as the parameter type passed to intents.

### TranscriptionEntityDefaultQuery

```
TranscriptionEntityDefaultQuery (EnumerableEntityQuery)
    │
    ├── @Dependency dataController: DataController
    │
    ├── allEntities()
    │   └── dataController.transcriptionEntities(limit: 100)
    │       — capped at 100 for picker performance
    │
    └── entities(for identifiers: [UUID])
        └── dataController.transcriptionEntities(matching: predicate)
            — resolves specific IDs for intent parameter re-hydration
```

`EnumerableEntityQuery` is the simplest query protocol — the system calls `allEntities()` to populate a picker when a user selects a `TranscriptionEntity` parameter in Shortcuts or Siri. The 100-item limit prevents slow picker loading on large libraries.

## Spotlight Indexing

Indexing is performed on-demand from `AppState`, not as a batch operation at startup.

```
Indexing triggers:
    │
    ├── New transcription saved (RecordViewModel)
    │   └── Task.detached { appState.indexTranscriptionEntityToSpotlight(entity) }
    │       (detached to avoid SwiftData actor isolation issues)
    │
    ├── Transcription updated (detail view, variation generated)
    │   └── appState.updateTranscriptionEntityInSpotlight(entity)
    │       (reindex with same identifier = update)
    │
    └── Transcription deleted
        └── appState.removeTranscriptionFromSpotlight(id)
            CSSearchableIndex.deleteAppEntities(identifiedBy:ofType:)

AppState Spotlight methods:
    indexTranscriptionToSpotlight(_ transcription: Transcription)
        — takes SwiftData model, converts to entity, then indexes entity

    indexTranscriptionEntityToSpotlight(_ entity: TranscriptionEntity)
        — takes pre-extracted entity (safe for detached tasks)

    updateTranscriptionInSpotlight(_ transcription: Transcription)
        — alias for indexTranscriptionToSpotlight (same ID = overwrite)

    removeTranscriptionFromSpotlight(_ id: UUID)
        — CSSearchableIndex.deleteAppEntities(identifiedBy: [id], ofType: TranscriptionEntity.self)
```

All methods guard on `CSSearchableIndex.isIndexingAvailable()` before proceeding. The `Task.detached` pattern for post-recording indexing exists because `Transcription` is a `@Model` class with `@MainActor` isolation, but `TranscriptionEntity` is a plain struct — extracting the entity on MainActor and passing the struct to a detached task is the safe pattern here.

## Siri Predictions (NSUserActivity)

After every successful transcription, `RecordViewModel` donates an `NSUserActivity` to promote the app in Siri suggestions:

```
RecordViewModel (post-transcription):
    │
    └── appState.userActivity(for: transcription)
          │
          ├── activityType = "com.antonnovoselov.VivaDicta.viewTranscription"
          ├── title        = attributes.title (first 100 chars or date string)
          ├── userInfo     = ["id": transcription.id.uuidString]
          ├── persistentIdentifier = transcription.id.uuidString
          ├── isEligibleForSearch     = true
          ├── isEligibleForPrediction = true
          ├── keywords     = Set(attributes.keywords)  (model/prompt names)
          ├── contentAttributeSet = Transcription.searchableAttributes()
          └── activity.becomeCurrent()   — donates to Siri
```

`Transcription.searchableAttributes()` (on the `@Model`) differs from `TranscriptionEntity.searchableAttributes` (on the entity) in one respect: the model version also concatenates all `TranscriptionVariation` texts into `contentDescription`, making all variation content searchable in Spotlight alongside the primary text.

The `persistentIdentifier` is matched by `handleTranscriptionActivity(_:)` in `VivaDictaApp` to restore navigation when the user opens the app from a Siri suggestion or Spotlight result.

## Dependency Injection

All intents that access SwiftData use `@Dependency` rather than singletons:

```
VivaDictaApp.init():
    AppDependencyManager.shared.add(dependency: dataController)  // DataController
    AppDependencyManager.shared.add(dependency: router)          // Router

Intent usage:
    @Dependency var dataController: DataController
    @Dependency var router: Router
```

`AppDependencyManager` is the App Intents framework's built-in dependency container. Dependencies registered at app launch are resolved by the framework when an intent's `perform()` is called, even if the intent runs in a background extension process. `DataController` wraps a `ModelContext` for safe, actor-isolated SwiftData access from intent `perform()` bodies.

## Intent Registration Flow

```
App launch (VivaDictaApp.init()):
    │
    ├── 1. ShortcutsProvider.updateAppShortcutParameters()
    │      Registers all 5 shortcuts and their voice phrases with the system
    │
    └── 2. IntentDonationManager.shared.donate(intent: ToggleRecordIntent())
           Proactively donates ToggleRecordIntent for Siri suggestion
           (appears before user has manually run the shortcut)

Post-transcription (RecordViewModel):
    ├── 3. CSSearchableIndex.indexAppEntities([entity])
    │      Adds / updates Spotlight entry for the new transcription
    └── 4. NSUserActivity.becomeCurrent()
           Donates prediction signal to Siri for future suggestions
```

## Key Files

| File | Purpose |
|------|---------|
| `VivaDicta/AppIntents/ShortcutsProvider.swift` | `AppShortcutsProvider` — declares all voice phrases |
| `VivaDicta/AppIntents/ToggleRecordIntent.swift` | Start/stop recording via coordinator |
| `VivaDicta/AppIntents/CountRecentTranscriptionsIntent.swift` | Count transcriptions in last month |
| `VivaDicta/AppIntents/TranscriptionReminderIntent.swift` | Siri reads a note aloud |
| `VivaDicta/AppIntents/AddToRecentTranscriptionIntent.swift` | Append text to most recent note |
| `VivaDicta/AppIntents/OpenTranscriptionIntent.swift` | Navigate to a specific note (`OpenIntent`) |
| `VivaDicta/AppIntents/OpenTranscriptionSnippetIntent.swift` | Inline snippet view without opening app |
| `VivaDicta/AppIntents/ToggleKeyboardFlowIntent.swift` | Keyboard extension session toggle (stub) |
| `VivaDicta/Models/TranscriptionEntity.swift` | `IndexedEntity` + `TranscriptionEntityDefaultQuery` |
| `VivaDicta/Models/Transcription.swift` | `entity` computed property, `searchableAttributes()` |
| `VivaDicta/DataController.swift` | SwiftData access layer, registered as `@Dependency` |
| `VivaDicta/AppState.swift` | Spotlight index/remove/update methods, `userActivity(for:)` |
| `VivaDicta/Views/RecordViewModel.swift` | Post-transcription Spotlight index + activity donation |
| `VivaDicta/VivaDictaApp.swift` | `ShortcutsProvider.updateAppShortcutParameters()` + intent donation at launch |
| `VivaDictaWidget/ToggleSessionIntent.swift` | `LiveActivityIntent` for Dynamic Island stop button |
| `VivaDictaWidget/AppIntent.swift` | `ConfigurationAppIntent` for widget color picker |
| `VivaDictaWidget/VivaDictaWidgetControl.swift` | Control Center `ControlWidgetButton` |
