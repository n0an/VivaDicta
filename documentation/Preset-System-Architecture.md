# Preset System Architecture

## Overview

The preset system manages AI text processing instructions in VivaDicta. Presets define how the AI processes transcription text — from simple cleanup to summarization, translation, or formatting as email. The system supports both built-in (editable, non-deletable) and custom (user-created, CloudKit-synced) presets.

## Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                            Preset System                                     │
│                                                                              │
│  ┌────────────────────┐    ┌────────────────────┐    ┌──────────────────┐  │
│  │   PresetCatalog     │    │   PresetManager     │    │ PresetSyncService│  │
│  │   (static catalog)  │───►│   (@Observable)     │◄──►│ (SwiftData ↔    │  │
│  │                      │    │                      │    │  UserDefaults)  │  │
│  │  • allBuiltIn       │    │  • presets: [Preset] │    │                  │  │
│  │  • categoryOrder    │    │  • CRUD operations   │    │  • CloudKit sync│  │
│  │  • builtInIds       │    │  • Favorites         │    │  • Built-in sync│  │
│  │  • defaultPreset()  │    │  • Sort/Search       │    │  • Custom sync  │  │
│  └────────────────────┘    └─────────┬──────────┘    └──────────────────┘  │
│                                       │                                      │
│                              ┌────────▼────────┐                            │
│                              │   UserDefaults    │                            │
│                              │  (App Group)      │                            │
│                              │  key: Presets_v1  │                            │
│                              │  JSON encoded     │                            │
│                              └──────────────────┘                            │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                         Preset (Codable struct)                      │   │
│  │                                                                      │   │
│  │  Identity:              Content:              Behavior:              │   │
│  │  • id (String)          • promptInstructions  • useSystemTemplate   │   │
│  │  • name                 • presetDescription   • wrapInTranscriptTags│   │
│  │  • icon                                                              │   │
│  │  • category             State:                                      │   │
│  │  • createdAt            • isBuiltIn                                 │   │
│  │                         • isEdited                                  │   │
│  │  ID Format:             • isFavorite                                │   │
│  │  Built-in: "regular",                                               │   │
│  │    "summary", "email"                                               │   │
│  │  Custom: "custom_<UUID>"                                            │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Two Behavioral Modes

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        Enhancement Mode vs Standalone Mode                   │
│                                                                              │
│  ┌─────────────────────────────────┐  ┌─────────────────────────────────┐  │
│  │  Enhancement Mode               │  │  Standalone Mode                │  │
│  │  useSystemTemplate = true       │  │  useSystemTemplate = false      │  │
│  │                                  │  │                                  │  │
│  │  promptInstructions injected    │  │  promptInstructions IS the      │  │
│  │  into TRANSCRIPTION ENHANCER    │  │  full system message.           │  │
│  │  system prompt wrapper.         │  │                                  │  │
│  │                                  │  │  Used for:                      │  │
│  │  Used for:                      │  │  • Summarization                │  │
│  │  • Regular cleanup              │  │  • Translation                  │  │
│  │  • Email formatting             │  │  • Action points extraction     │  │
│  │  • Chat formatting              │  │  • Professional rewriting       │  │
│  │  • Coding cleanup               │  │  • Assistant mode               │  │
│  │                                  │  │                                  │  │
│  │  System prompt:                 │  │  System prompt:                 │  │
│  │  PromptsTemplates.systemPrompt  │  │  preset.promptInstructions     │  │
│  │  (with: instructions)           │  │  (used directly)               │  │
│  │  + vocabulary + clipboard       │  │  + vocabulary + clipboard       │  │
│  │                                  │  │                                  │  │
│  │  wrapInTranscriptTags: true     │  │  wrapInTranscriptTags: varies  │  │
│  │  (input in <TRANSCRIPT> tags)   │  │                                  │  │
│  └─────────────────────────────────┘  └─────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Built-In Preset Categories

```
Category Order (from PresetCatalog.categoryOrder):

┌─────────────────┬──────────────────────────────────────────────────┐
│ Category        │ Presets                                           │
├─────────────────┼──────────────────────────────────────────────────┤
│ Rewrite         │ Regular, Rewrite, Professional, Casual           │
│ Format          │ Email, Chat, Coding                              │
│ Summarize       │ Summary, Action Points                           │
│ Translate       │ (translation presets)                            │
│ Assistant       │ Assistant                                        │
│ Other           │ Custom presets default here                      │
└─────────────────┴──────────────────────────────────────────────────┘

Each built-in preset has:
• Stable string ID (e.g., "regular", "summary", "email")
• Default instructions that can be reset
• Category and icon maintained by catalog updates
```

## PresetManager Operations

### CRUD

| Operation | Built-In | Custom |
|-----------|----------|--------|
| **Create** | N/A (populated from catalog) | `addPreset()` → save + CloudKit sync |
| **Read** | `preset(for: id)` | Same |
| **Update** | `updatePreset()` → marks `isEdited`, syncs edited fields | `updatePreset()` → full sync |
| **Delete** | Blocked (`isBuiltIn` guard) | `deletePreset()` → remove + CloudKit delete |
| **Reset** | `resetToDefault()` → restore catalog version | N/A |
| **Favorite** | `toggleFavorite()` → sync state | Same |

### Sorting

```
Preset order:
1. Built-in presets first (in PresetCatalog.allBuiltIn order)
2. Custom presets after (sorted by createdAt)
```

### Built-In Population

`populateBuiltInsIfNeeded()` runs at init:

```
For each built-in preset in catalog:
  If exists in stored presets:
    If isEdited:
      Only sync category + icon (preserve user edits)
    Else:
      Refresh from catalog (preserve isFavorite)
  Else:
    Append new built-in preset
```

## Sync Architecture

```
┌──────────────┐     ┌────────────────┐     ┌──────────────────────┐
│ PresetManager │     │PresetSyncService│     │ SwiftData/CloudKit   │
│ (UserDefaults)│◄───►│                │◄───►│                      │
│               │     │ Bridges UD ↔   │     │ RewritePreset model  │
│ Source of     │     │ SwiftData      │     │ (custom presets)     │
│ truth for     │     │                │     │                      │
│ in-app use    │     │ On preset      │     │ CustomRewritePreset  │
│               │     │ change:        │     │ (for CloudKit sync)  │
└──────────────┘     │ • create/update│     │                      │
                      │   SwiftData    │     │ Syncs across:        │
                      │   record       │     │ • iOS devices        │
                      │                │     │ • macOS companion    │
                      │ On CloudKit    │     │                      │
                      │ change:        │     └──────────────────────┘
                      │ • merge into   │
                      │   UserDefaults │
                      └────────────────┘
```

### Sync Rules

| Preset Type | Sync Direction | What's Synced |
|-------------|---------------|---------------|
| **Custom** | Bidirectional | Full preset data (name, instructions, icon, etc.) |
| **Built-in (edited)** | Bidirectional | Edited fields only (name, instructions) |
| **Built-in (not edited)** | None | Catalog is source of truth |
| **Favorite state** | Bidirectional | `isFavorite` flag for all presets |

## Integration with VivaMode

```
VivaMode.presetId ──► PresetManager.preset(for:) ──► Preset
                                                        │
                                                        ├── promptInstructions
                                                        ├── useSystemTemplate
                                                        ├── wrapInTranscriptTags
                                                        │
                                                        ▼
                                                   AIService.getSystemMessage()
                                                   AIService.formatTranscriptForLLM()
```

- Each VivaMode references a preset by string ID
- Editing a preset takes effect for ALL modes referencing that preset (no embedded copy)
- Deleting a preset auto-disables AI for modes using it (`disableAIEnhancementForModesUsingPreset`)

## Icon System

Presets support three icon types:

| Format | Example | Rendering |
|--------|---------|-----------|
| Emoji | `"📝"` | `Text(icon)` |
| SF Symbol | `"text.bubble"` | `Image(systemName:)` |
| Custom asset | `"asset:myicon"` | `Image("myicon")` |

Detection: emoji if first unicode scalar has `isEmoji` property and value > 0x238C.

## Duplicate Name Detection

`isPresetNameDuplicate(_:excludingId:)` normalizes names by:
1. Splitting on whitespace
2. Joining without spaces
3. Lowercasing

This prevents "My Preset" and "my preset" or "My  Preset" from coexisting.

## Legacy Migration

### From UserPrompt to Preset
- Old `VivaMode` format embedded a `UserPrompt` struct directly
- New format uses `presetId` string reference
- Backward-compatible decoding: if `presetId` missing, decode `userPrompt.title` as fallback
- `PresetMigrationService` handles one-time conversion on app update
