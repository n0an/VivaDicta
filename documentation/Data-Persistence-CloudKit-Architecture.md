# Data Persistence & CloudKit Sync Architecture

## Overview

VivaDicta uses SwiftData as its persistence layer, with CloudKit providing transparent sync across iOS and macOS devices. All data lives in a single SQLite store located in the app's shared App Group container, giving the keyboard extension direct read access to the same records without any IPC overhead. CloudKit sync is opt-in and can be toggled by the user; when the container cannot be opened (e.g. on the first launch in a sandbox or after a schema mismatch), the app transparently falls back to an in-memory store so the rest of the stack keeps working.

Sensitive configuration—API keys—never enters SwiftData or CloudKit. They are stored in iCloud Keychain via `KeychainService`, using the same `kSecAttrService` as the macOS companion app so they arrive on every device without any custom sync code.

User-created and edited presets follow a hybrid path: they are stored in a `RewritePreset` SwiftData model (which CloudKit syncs automatically), and `PresetSyncService` bridges those records into the in-memory `PresetManager` that the rest of the UI reads.

## Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                          VivaDictaApp.init()                                 │
│                                                                              │
│  1. Resolve App Group URL (shared container for keyboard extension access)   │
│  2. Read isICloudSyncEnabled from UserDefaults                               │
│  3. Create ModelConfiguration:                                               │
│     url: <AppGroup>/VivaDicta.sqlite                                         │
│     cloudKitDatabase: .private("iCloud.com.antonnovoselov.VivaDicta")        │
│               — or —                                                         │
│     cloudKitDatabase: .none  (user disabled sync)                            │
│  4. ModelContainer(for: all models, configurations: config)                  │
│     └── On failure → in-memory fallback (isStoredInMemoryOnly: true)         │
└────────────────────────────┬─────────────────────────────────────────────────┘
                             │ modelContainer
              ┌──────────────▼──────────────────────┐
              │           ModelContainer              │
              │                                      │
              │  SwiftData models (CloudKit-synced): │
              │  • Transcription                     │
              │  • TranscriptionVariation            │
              │  • RewritePreset                     │
              │  • VocabularyWord                    │
              │  • WordReplacement                   │
              │                                      │
              │  Schema-present, not actively synced:│
              │  • CustomRewritePreset  (legacy)     │
              └──────┬───────────────┬───────────────┘
                     │               │
        ┌────────────▼───┐    ┌──────▼──────────────────────────────┐
        │ DataController │    │         CloudKit Private DB           │
        │                │    │   iCloud.com.antonnovoselov.VivaDicta │
        │  modelContext  │    │                                       │
        │  transcriptions│    │  iOS ↔ macOS (VivaDictaMac)          │
        │  (by predicate)│    │  Automatic conflict resolution        │
        │  transcription │    │  (last-write wins per field)          │
        │  (by id)       │    └──────────────────────────────────────┘
        │  count queries │
        └────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                         Credential Sync (separate path)                     │
│                                                                              │
│  KeychainService.save(key, forKey:, syncable: true)                         │
│       kSecAttrSynchronizable = true → iCloud Keychain                       │
│       kSecAttrService = "com.antonnovoselov.VivaDicta"  (matches macOS)     │
│                                                                              │
│  API keys NEVER enter SwiftData or CloudKit CKRecord                        │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                           PresetSyncService                                  │
│                                                                              │
│  CloudKit → PresetManager (inbound):                                        │
│  syncFromCloudKit()                                                          │
│     ├── fetch custom RewritePreset records (isPredefined == false)          │
│     ├── upsert into PresetManager as Preset structs                         │
│     ├── remove locally-deleted presets (post-migration)                     │
│     └── syncBuiltInPresetsFromCloudKit()                                    │
│         └── apply edits / resets / isFavorite to built-in presets          │
│                                                                              │
│  PresetManager → CloudKit (outbound):                                       │
│  createPresetRecord() / updatePresetRecord() / deletePresetRecord()         │
│  syncBuiltInPresetRecord() / syncFavoriteState()                            │
│     └── insert/update/delete RewritePreset in ModelContext → CloudKit       │
└─────────────────────────────────────────────────────────────────────────────┘
```

## ModelContainer Setup

```
VivaDictaApp.init()
    │
    ├── appGroupURL = FileManager containerURL(forSecurityApplicationGroupIdentifier:)
    ├── sharedStoreURL = appGroupURL / "VivaDicta.sqlite"
    │
    ├── ModelConfiguration(
    │       url: sharedStoreURL,
    │       cloudKitDatabase: isICloudSyncEnabled
    │           ? .private("iCloud.com.antonnovoselov.VivaDicta")
    │           : .none
    │   )
    │
    ├── ModelContainer(
    │       for: Transcription, VocabularyWord, WordReplacement,
    │            TranscriptionVariation, CustomRewritePreset, RewritePreset,
    │       configurations: config
    │   )
    │   ├── Success → use persistent store
    │   └── Failure → ModelConfiguration(isStoredInMemoryOnly: true)
    │               → ModelContainer(for: same models, configurations: fallback)
    │
    ├── CustomVocabulary.modelContainer = modelContainer   (static ref for services)
    ├── ReplacementsService.modelContainer = modelContainer
    │
    └── DataController(modelContainer: modelContainer)
        └── modelContext = ModelContext(modelContainer)
```

The store URL lives in the App Group container (`group.com.antonnovoselov.VivaDicta`) rather than the app's own Documents directory. This is required for the keyboard extension to open the same SQLite file for direct reads (custom vocabulary lookups, word replacement lookups) without going through the main app.

Two services receive a static reference to the container at launch time—`CustomVocabulary` and `ReplacementsService`—because they run during transcription processing on background contexts and cannot receive the container via SwiftUI environment injection.

## SwiftData Models

### Transcription

The primary user-facing record. Stores original transcribed text, the latest AI output as a cache field (`enhancedText`), audio file metadata, performance measurements, and a cascade relationship to its variations.

```
Transcription (@Model)
├── id: UUID                          — stable identifier for Spotlight / Shortcuts
├── text: String                      — raw speech-to-text output
├── enhancedText: String?             — latest AI output (cache/fallback for list preview)
├── timestamp: Date
├── audioDuration: TimeInterval
├── audioFileName: String?            — relative filename under Documents/Audio/
├── transcriptionModelName: String?
├── transcriptionProviderName: String?
├── aiEnhancementModelName: String?
├── aiProviderName: String?
├── promptName: String?
├── transcriptionDuration: TimeInterval?
├── enhancementDuration: TimeInterval?
├── aiRequestSystemMessage: String?   — stored for variation regeneration & macOS sync
├── aiRequestUserMessage: String?
├── powerModeName: String?            — synced from macOS
├── powerModeEmoji: String?
├── powerModeId: String?
├── transcriptionStatus: String?      — synced from macOS
└── @Relationship(deleteRule: .cascade)
    variations: [TranscriptionVariation]?
```

`enhancedText` is a denormalized cache. When AI processing completes, both `enhancedText` and a `TranscriptionVariation` record are written (dual-write pattern). `enhancedText` is read by: list row previews, the SwiftData search predicate, Spotlight indexing, App Intents, and clipboard operations. This field is intentionally redundant—it provides a fast single-field read path that does not require loading the variations relationship.

### TranscriptionVariation

Each AI-generated output stored as a separate record. Multiple variations may exist per transcription (one per preset applied). The relationship is declared on both sides—cascade delete on the parent's `variations` property, and an explicit `@Relationship(inverse:)` on the child's `transcription` property.

```
TranscriptionVariation (@Model)
├── id: UUID
├── presetId: String                  — e.g., "regular", "summary", "custom_<uuid>"
├── presetDisplayName: String         — display name at time of generation
├── text: String                      — the AI output
├── createdAt: Date
├── aiModelName: String?
├── aiProviderName: String?
├── processingDuration: TimeInterval?
├── aiRequestSystemMessage: String?
├── aiRequestUserMessage: String?
└── @Relationship(inverse: \Transcription.variations)
    transcription: Transcription?
```

### RewritePreset

The active CloudKit sync model for user presets. Matches the macOS `RewritePreset` schema exactly so CloudKit can sync records between platforms without any field mapping. Custom presets use `isPredefined == false`; built-in preset edits use `isPredefined == true` with a UUID from `PresetCatalog.builtInUUIDs`.

```
RewritePreset (@Model)
├── id: UUID                          — stable UUID shared with macOS catalog
├── name: String
├── icon: String
├── category: String
├── systemPrompt: String
├── isPredefined: Bool                — true = edited built-in; false = custom
├── sortOrder: Int
├── createdAt: Date
├── isHidden: Bool                    — soft-delete; syncs deletion to other devices
├── isFavorite: Bool
├── useSystemTemplate: Bool           — wrap prompt in PromptsTemplates envelope
├── wrapInTranscriptTags: Bool
└── presetDescription: String
```

### CustomRewritePreset (legacy)

Kept in the model schema for migration purposes only. `PresetSyncService.migrateOldCustomRewritePresets()` copies these records into `RewritePreset` on first launch and deletes the originals. No new records are created in this model.

### VocabularyWord

User's custom vocabulary for AI processing hints. Words added here are injected into the AI system prompt as a `<CUSTOM_VOCABULARY>` section.

```
VocabularyWord (@Model)
├── word: String
└── dateAdded: Date
```

### WordReplacement

Text substitution rules applied during the text processing pipeline before AI enhancement. Replacements run on raw transcription output.

```
WordReplacement (@Model)
├── originalText: String
├── replacementText: String
├── dateAdded: Date
└── isEnabled: Bool
```

## CloudKit Configuration

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                  iCloud.com.antonnovoselov.VivaDicta                         │
│                     (CKContainer — private database)                         │
│                                                                              │
│  Shared between:                                                             │
│  • VivaDicta (iOS)                                                           │
│  • VivaDictaMac (macOS)                                                      │
│                                                                              │
│  Sync scope:                                                                 │
│  • All SwiftData models in the ModelContainer configuration                  │
│  • SwiftData uses NSPersistentCloudKitContainer internally                   │
│  • Conflict resolution: last-write-wins per property                         │
│  • Sync is asynchronous — UI does not wait for CloudKit confirmation         │
│                                                                              │
│  User toggle:                                                                │
│  UserDefaults.standard["isICloudSyncEnabled"] (default: true)               │
│  Requires app restart to take effect (container rebuilt at init time)        │
└──────────────────────────────────────────────────────────────────────────────┘
```

CloudKit sync is configured entirely via the `ModelConfiguration.cloudKitDatabase` parameter. SwiftData handles CKRecord schema generation, delta syncing, and conflict resolution without any manual `CKRecord` or `CKOperation` code. The private database ensures records are visible only to the authenticated iCloud account owner—there is no public or shared database in use.

The `assistant` preset is intentionally excluded from built-in preset sync (`PresetSyncService.syncBuiltInPresetRecord` guards on `preset.id != "assistant"`) because its prompt differs by design between iOS and macOS.

## DataController

`DataController` is an `@Observable` class that wraps `ModelContext` and exposes typed query methods. It is instantiated once in `VivaDictaApp.init()` and injected into the SwiftUI environment and `AppDependencyManager` for non-SwiftUI access points (App Intents, Spotlight).

```
DataController (@Observable)
│
├── transcriptions(matching:sortBy:limit:) → [Transcription]
│   └── FetchDescriptor with predicate, sort, and optional fetchLimit
│
├── transcription(byId:) → Transcription?
│   └── transcriptions(matching: id == x, limit: 1).first
│
├── transcriptionEntities(matching:sortBy:limit:) → [TranscriptionEntity]
│   └── maps results through Transcription.entity for Spotlight
│
└── transcriptionCount(matching:) → Int
    └── modelContext.fetchCount (no objects loaded into memory)
```

For SwiftUI views that use `@Query`, no `DataController` involvement is needed—views bind directly to the SwiftData store through the `.modelContainer` environment. `DataController` is used by non-SwiftUI callers: `SpotlightIndexer`, `TranscriptionEntityQuery` (App Intents), and anywhere a synchronous fetch is needed outside the SwiftUI view hierarchy.

## API Key Sync via iCloud Keychain

```
KeychainService.save(value, forKey:, syncable: true)
    │
    ├── kSecClass: kSecClassGenericPassword
    ├── kSecAttrService: "com.antonnovoselov.VivaDicta"   — shared with macOS
    ├── kSecAttrAccount: provider.keychainKey
    ├── kSecAttrSynchronizable: kCFBooleanTrue            — opt-in iCloud Keychain sync
    └── kSecUseDataProtectionKeychain: true
```

All API keys are stored with `kSecAttrSynchronizable = true`. The iOS app and macOS VivaDictaMac app use identical `kSecAttrService` values, so a key saved on one platform appears on the other without any custom sync logic. Keys can also be stored non-syncably (`syncable: false` parameter) for test or ephemeral use, though the app always uses the default `syncable: true` path for production AI provider keys.

`AIProvider.apiKey` is a computed property that calls `KeychainService.shared.getString(forKey: keychainKey)` inline; there is no in-memory cache, so key reads always reflect the current Keychain state.

### API Key Migration

`APIKeyMigrationService` is a one-time migration that runs on first launch after the Keychain storage change was introduced. It reads each provider's key from the old App Group UserDefaults location and writes it to Keychain, then sets a `HasMigratedAPIKeysToKeychain` flag in `UserDefaults.standard` to prevent re-running.

## PresetSyncService

`PresetSyncService` is the bridge between the CloudKit-backed `RewritePreset` SwiftData records and the in-memory `PresetManager` that the rest of the app reads.

```
┌────────────────────────────────────────────────────────────────────────────┐
│  Sources of truth:                                                          │
│                                                                             │
│  PresetManager (UserDefaults, in-memory)                                   │
│  • Built-in presets seeded from PresetCatalog at launch                    │
│  • Custom presets loaded from UserDefaults                                  │
│  • Active preset selections per VivaMode                                   │
│                                                                             │
│  RewritePreset (SwiftData → CloudKit)                                      │
│  • Custom preset records (isPredefined == false)                            │
│  • Edited built-in preset records (isPredefined == true, stable UUID)      │
│  • isFavorite state for all presets                                         │
└────────────────────────────────────────────────────────────────────────────┘
```

### Inbound Sync (CloudKit → PresetManager)

`syncFromCloudKit(presetManager:)` is called at app launch and whenever CloudKit delivers a notification that the store changed. It fetches all `RewritePreset` records, converts them to `Preset` value types, and upserts them into `PresetManager`. Hidden records (`isHidden == true`) are treated as deletions—any matching local preset is removed.

After the initial migration has run (guarded by `HasMigratedPresetsToRewritePreset_v1`), local custom presets with no corresponding CloudKit record are removed. This propagates deletions made on another device.

Built-in preset sync reads `isPredefined == true` records, maps each UUID back to a string preset ID via `PresetCatalog.presetId(for:)`, compares the stored `systemPrompt` to catalog defaults to detect edits, and applies any changes locally.

### Outbound Sync (PresetManager → CloudKit)

Every mutation in `PresetManager` that affects a syncable preset calls the corresponding `PresetSyncService` method:

| PresetManager mutation | PresetSyncService method |
|---|---|
| Create custom preset | `createPresetRecord(from:)` |
| Update custom preset | `updatePresetRecord(from:)` |
| Delete custom preset | `deletePresetRecord(presetId:)` |
| Edit built-in preset | `syncBuiltInPresetRecord(from:)` |
| Reset built-in preset | `resetBuiltInPresetRecord(presetId:)` |
| Toggle isFavorite | `syncFavoriteState(presetId:isFavorite:)` |

Each method inserts, updates, or deletes a `RewritePreset` record in `ModelContext`. SwiftData then propagates the change to CloudKit asynchronously.

### Preset Migration Chain

On first launch after schema introduction, three one-time migrations run in order:

```
1. DictionaryMigrationService.migrateIfNeeded(context:)
   └── Moves VocabularyWord / WordReplacement from UserDefaults to SwiftData

2. APIKeyMigrationService.migrateIfNeeded()
   └── Moves API keys from App Group UserDefaults to iCloud Keychain

3. VariationMigrationService.migrateIfNeeded(context:)
   └── Creates TranscriptionVariation(presetId: "regular") for each
       Transcription.enhancedText, preserving model/provider/duration

4. PresetSyncService.migrateExistingCustomPresets(presetManager:)
   └── Writes existing UserDefaults custom presets to RewritePreset

5. PresetSyncService.migrateOldCustomRewritePresets()
   └── Copies CustomRewritePreset records → RewritePreset, deletes originals
```

Each migration is gated by a `UserDefaults.standard.bool(forKey: migrationKey)` flag so it runs exactly once regardless of how many times the app is launched.

## In-Memory Fallback

If the `ModelContainer` initializer throws—most commonly due to a CloudKit entitlement issue in a simulator, a schema incompatibility, or a corrupted store file—the app catches the error and constructs a second container with `isStoredInMemoryOnly: true`:

```swift
} catch {
    print("Error loading ModelContainer; switching to in-memory storage. \(error)")
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    modelContainer = try! ModelContainer(
        for: Transcription.self, VocabularyWord.self, WordReplacement.self,
             TranscriptionVariation.self, CustomRewritePreset.self, RewritePreset.self,
        configurations: config
    )
}
```

With an in-memory container, all features work for the current session but no data is persisted and CloudKit sync is disabled. The `force-try` on the fallback path is intentional—if even an in-memory container cannot be created, the model types themselves are broken and a crash is the correct signal.

## CloudKit + SwiftData Rules

These rules apply to every model in the container and must not be violated when adding new models or properties:

| Rule | Reason |
|---|---|
| No `@Attribute(.unique)` | CloudKit does not support unique constraints; adding one will crash the container init |
| All model properties must have default values or be optional | Required for CloudKit schema evolution and new-record deserialization |
| All `@Relationship` properties must be optional | CloudKit cannot guarantee referential integrity across sync |
| No inheritance between `@Model` classes | SwiftData CloudKit sync does not support polymorphic queries across inherited types |
| `@Relationship(deleteRule: .cascade)` only on the owning side | Cascade deletes are applied locally; the inverse side uses `.nullify` implicitly |

## Key Files

| File | Role |
|---|---|
| `VivaDicta/VivaDictaApp.swift` | `ModelContainer` construction, CloudKit config, fallback, static service injection |
| `VivaDicta/DataController.swift` | `@Observable` query wrapper over `ModelContext` |
| `VivaDicta/Models/Transcription.swift` | Primary user record with Spotlight and App Intents integration |
| `VivaDicta/Models/TranscriptionVariation.swift` | Per-preset AI output record |
| `VivaDicta/Models/RewritePreset.swift` | CloudKit sync model for user-created and edited presets |
| `VivaDicta/Models/CustomRewritePreset.swift` | Legacy preset model, migration source only |
| `VivaDicta/Models/VocabularyWord.swift` | Custom vocabulary words synced via CloudKit |
| `VivaDicta/Models/WordReplacement.swift` | Text substitution rules synced via CloudKit |
| `VivaDicta/Services/KeychainService.swift` | iCloud Keychain storage for API keys |
| `VivaDicta/Services/PresetSyncService.swift` | Bridge between `RewritePreset` (CloudKit) and `PresetManager` (in-memory) |
| `VivaDicta/Services/APIKeyMigrationService.swift` | One-time UserDefaults → Keychain migration |
| `VivaDicta/Services/VariationMigrationService.swift` | One-time `enhancedText` → `TranscriptionVariation` migration |
| `VivaDicta/Services/DictionaryMigrationService.swift` | One-time UserDefaults → SwiftData migration for vocabulary and replacements |
| `VivaDicta/Services/PresetMigrationService.swift` | Additional preset migration utilities |
