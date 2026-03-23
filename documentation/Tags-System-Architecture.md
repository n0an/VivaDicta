# Tags System Architecture

## Overview

The tags system allows users to organize and filter transcriptions. It has two layers:

1. **Source Tags** — automatically set at creation time, identifying where a transcription originated (in-app, keyboard extension, share/action extension, macOS app)
2. **User Tags** — manually created and assigned by the user for custom organization (e.g., "Meeting", "Personal", "Work")

## Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────────────┐
│                            Tags System                                    │
│                                                                          │
│  ┌─────────────────────┐     ┌──────────────────────────────────────┐  │
│  │    Source Tags        │     │           User Tags                   │  │
│  │    (automatic)        │     │           (manual)                    │  │
│  │                       │     │                                      │  │
│  │  Transcription        │     │  TranscriptionTag ◄──► TagAssignment │  │
│  │    .sourceTag: String?│     │    .name             .tagId          │  │
│  │                       │     │    .colorHex         .transcription  │  │
│  │  Values:              │     │    .icon                             │  │
│  │  • "app"              │     │    .sortOrder                        │  │
│  │  • "keyboard"         │     │    .createdAt                        │  │
│  │  • "shareExtension"   │     │                                      │  │
│  │  • "actionExtension"  │     │  Junction model pattern for          │  │
│  │  • "macApp"           │     │  CloudKit-safe many-to-many          │  │
│  └─────────────────────┘     └──────────────────────────────────────┘  │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │                        Filtering                                    │  │
│  │                                                                    │  │
│  │  TagFilterBar (horizontal chip bar above transcription list)       │  │
│  │  • Source tag chips + User tag chips + "All" reset                 │  │
│  │  • Multi-select with OR-within-group, AND-between-groups           │  │
│  └────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────┘
```

## Data Models

### Source Tag (property on Transcription)

A simple `String?` property on the `Transcription` model. Set once at creation time, never changed.

| Value | Origin | Icon |
|-------|--------|------|
| `"app"` | In-app recording | `mic.fill` |
| `"keyboard"` | Keyboard extension | `keyboard` |
| `"shareExtension"` | Share extension | `square.and.arrow.down` |
| `"actionExtension"` | Action extension | `bolt.fill` |
| `"macApp"` | macOS companion app | `desktopcomputer` |
| `nil` | Created before source tracking | No badge shown |

Constants and display helpers are in `SourceTag.swift`.

### TranscriptionTag (SwiftData model)

User-created tag with visual customization. Syncs via CloudKit.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `id` | `UUID` | `UUID()` | Unique identifier |
| `name` | `String` | `""` | Display name |
| `colorHex` | `String` | `"#007AFF"` | Hex color (preset or custom via ColorPicker) |
| `icon` | `String` | `"tag"` | SF Symbol name |
| `sortOrder` | `Int` | `0` | Display ordering |
| `createdAt` | `Date` | `Date()` | Creation timestamp |

### TranscriptionTagAssignment (SwiftData junction model)

Links tags to transcriptions. Uses a junction model instead of a direct many-to-many relationship for reliable CloudKit sync.

| Property | Type | Description |
|----------|------|-------------|
| `id` | `UUID` | Unique identifier |
| `tagId` | `UUID` | References `TranscriptionTag.id` |
| `createdAt` | `Date` | Assignment timestamp |
| `transcription` | `Transcription?` | Inverse relationship (cascade delete) |

**Why junction model?** SwiftData's direct many-to-many relationships are unreliable with CloudKit sync. The junction model pattern is explicit and predictable — each assignment is its own record that syncs independently.

## Source Tag Assignment

Source tags are set automatically at transcription creation time:

| Creation Path | How Source Is Determined |
|---------------|------------------------|
| In-app recording | `prewarmManager.isSessionActive` → `"keyboard"`, else `"app"` |
| Share extension | `AppGroupCoordinator.setPendingSourceTag("shareExtension")` |
| Action extension | `AppGroupCoordinator.setPendingSourceTag("actionExtension")` |
| macOS app | Hardcoded `sourceTag: "macApp"` at all creation sites |

For shared audio (share/action extensions), the source tag is stored in `AppGroupCoordinator` shared UserDefaults and consumed by `MainView.handleSharedAudioTranscription()` when the main app processes the audio.

## Filtering Logic

The filter bar appears above the transcription list when source tags or user tags exist.

### Filter Groups

Filters are organized into two groups:

1. **Source tags** — filter by transcription origin
2. **User tags** — filter by assigned tags

### Combination Logic

```
Result = (source filter) AND (user tag filter)
```

**Within each group: OR logic**
- Selecting "Keyboard" + "In-App" shows transcriptions from Keyboard OR In-App
- Selecting "Meeting" + "Work" shows transcriptions tagged Meeting OR Work

**Between groups: AND logic**
- Selecting "Keyboard" + "Meeting" shows transcriptions from Keyboard that also have the Meeting tag

**Rationale for OR within groups:**
- Source tags are mutually exclusive (a transcription has exactly one source), so AND would always return empty
- User tags are typically non-overlapping categories ("Meeting", "Personal", "Work"). AND between non-overlapping tags would return nothing. OR is what users intuitively expect — "show me Meeting or Work items"
- This matches the filter pattern used by Gmail labels, Apple Notes, Bear, Notion, and Things

### "All" Chip

Tapping "All" clears all active filters, returning to the unfiltered view.

## UI Components

### Tag Management (Settings > Organization > Tags)

- **TagManagementView** — list of user tags with swipe-to-delete, tap to edit
- **TagEditorSheet** — create/edit with name, 10-color preset palette + native ColorPicker, 25 SF Symbol icon picker, live preview

### Tag Assignment (Transcription Detail View)

- **Tag chips row** — horizontal scrollable row above the bottom action bar showing source badge, assigned user tags, and "+" button
- **Tag button in action bar** — tag icon in the bottom bar (alongside retranscribe, AI, edit, copy) opens the tag picker
- **TagPickerSheet** — toggle tags on/off with checkmarks, create new tags inline

### Tag Display (Main List)

- **Source badge** — colored SF Symbol icon next to timestamp in each row
- **User tag icons** — colored circles with SF Symbol icons below the text (max 5 visible, "+N" overflow)

### Tag Filter Bar (Main List)

- **TagFilterBar** — horizontal scrollable chips above the list: "All" + source tags + user tags
- Shows only when tags or source tags exist
- Multi-select toggle (tap to activate/deactivate)

## CloudKit Sync

All tag models sync via the `iCloud.com.antonnovoselov.VivaDicta` private CloudKit container:

- `TranscriptionTag` records sync between iOS and macOS
- `TranscriptionTagAssignment` records sync independently (junction model)
- `Transcription.sourceTag` syncs as a regular string property
- Both iOS and macOS must register `TranscriptionTag.self` and `TranscriptionTagAssignment.self` in their `ModelContainer`

**No migration needed** — all new properties are optional with defaults. SwiftData lightweight migration handles schema evolution automatically.

## Key Files

| File | Purpose |
|------|---------|
| `Models/SourceTag.swift` | Source tag constants and display helpers |
| `Models/TranscriptionTag.swift` | User tag SwiftData model |
| `Models/TranscriptionTagAssignment.swift` | Junction model for tag assignments |
| `Utilities/ColorHex.swift` | `Color(hex:)` and `.hexString` extensions |
| `Views/SettingsScreen/Tags/TagManagementView.swift` | Tag list in Settings |
| `Views/SettingsScreen/Tags/TagEditorSheet.swift` | Create/edit tag form |
| `Views/SettingsScreen/Tags/TagPickerSheet.swift` | Assign tags to transcription |
| `Views/SettingsScreen/Tags/TranscriptionTagChipsView.swift` | Tag chips in detail view |
| `Views/SettingsScreen/Tags/TagFilterBar.swift` | Filter bar in main list |
