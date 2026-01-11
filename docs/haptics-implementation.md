# Haptic Feedback Implementation

This document describes the haptic feedback system implemented in VivaDicta.

## Overview

VivaDicta uses a centralized `HapticManager` utility for all haptic feedback. This provides:
- Consistent haptic patterns across the app
- Global enable/disable toggle in Settings
- Direct access to UIKit feedback generators and CoreHaptics

## HapticManager API

Location: `VivaDicta/Utils/HapticManager.swift`

### CoreHaptics Support

HapticManager supports custom haptic patterns via AHAP (Apple Haptic Audio Pattern) files using CoreHaptics framework.

**AHAP Files Location:** `VivaDicta/Resources/Haptics/`

| File | Description | Used For |
|------|-------------|----------|
| `TranscriptionComplete.ahap` | Single heartbeat pulse | Transcription completion |

**Playing Custom Patterns:**
```swift
HapticManager.playPattern(named: "TranscriptionComplete")
```

### Settings

Haptics can be globally enabled/disabled via:
- **Settings > Feedback > Haptic Feedback** toggle
- Stored in `UserDefaults` with key `isHapticsEnabled`
- Enabled by default

### API Reference

Direct access to UIKit feedback generators:

| Method | UIKit Generator | Use Case |
|--------|-----------------|----------|
| `lightImpact()` | `UIImpactFeedbackGenerator(.light)` | Edit mode buttons, swipe actions, copy, play/pause, cancel |
| `mediumImpact()` | `UIImpactFeedbackGenerator(.medium)` | Start/stop recording, add items, save changes, save API key |
| `heavyImpact()` | `UIImpactFeedbackGenerator(.heavy)` | Significant completions (download, duplicate, delete after confirmation) |
| `selectionChanged()` | `UISelectionFeedbackGenerator` | Pickers, toggles, select all, item selection |
| `warning()` | `UINotificationFeedbackGenerator(.warning)` | Bulk delete operations |
| `error()` | `UINotificationFeedbackGenerator(.error)` | Failed operations |
| `playPattern(named:)` | CoreHaptics AHAP | Custom patterns (transcription complete) |

## Implementation by File

### Recording Flow

| File | Location | Method | Haptic Type | Trigger |
|------|----------|--------|-------------|---------|
| `RecordViewModel.swift` | Line ~139 | `mediumImpact()` | `UIImpactFeedbackGenerator(.medium)` | Prewarm recording start |
| `RecordViewModel.swift` | Line ~184 | `mediumImpact()` | `UIImpactFeedbackGenerator(.medium)` | Normal recording start |
| `RecordViewModel.swift` | Line ~244 | `mediumImpact()` | `UIImpactFeedbackGenerator(.medium)` | Stop recording |
| `RecordViewModel.swift` | Line ~525 | `lightImpact()` | `UIImpactFeedbackGenerator(.light)` | Cancel recording |
| `RecordViewModel.swift` | Line ~483 | `playPattern(named:)` | CoreHaptics AHAP | Transcription complete |
| `RecordViewModel.swift` | Line ~491 | `error()` | `UINotificationFeedbackGenerator(.error)` | Transcription error |

### Copy Actions

| File | Location | Method | Haptic Type | Trigger |
|------|----------|--------|-------------|---------|
| `AnimatedCopyButton.swift` | Line ~48 | `lightImpact()` | `UIImpactFeedbackGenerator(.light)` | Copy to clipboard |

### Delete Operations

| File | Location | Method | Haptic Type | Trigger |
|------|----------|--------|-------------|---------|
| `TranscriptionsContentView.swift` | `deleteTranscription()` | `heavyImpact()` | `UIImpactFeedbackGenerator(.heavy)` | Delete transcription |
| `SettingsView.swift` | `deleteMode()` | `heavyImpact()` | `UIImpactFeedbackGenerator(.heavy)` | Delete mode |
| `LocalModelCard.swift` | Delete button/context menu | `warning()` | `UINotificationFeedbackGenerator(.warning)` | Show delete confirmation |
| `LocalModelCard.swift` | `deleteModel()` | `heavyImpact()` | `UIImpactFeedbackGenerator(.heavy)` | Delete local model (after confirmation) |
| `CloudModelCard.swift` | Context menu | `warning()` | `UINotificationFeedbackGenerator(.warning)` | Show delete confirmation |
| `CloudModelCard.swift` | `deleteAPIKey()` | `heavyImpact()` | `UIImpactFeedbackGenerator(.heavy)` | Delete API key (after confirmation) |
| `CloudModelConfigurationView.swift` | Delete button | `warning()` | `UINotificationFeedbackGenerator(.warning)` | Show delete confirmation |
| `CloudModelConfigurationView.swift` | `deleteAPIKey()` | `heavyImpact()` | `UIImpactFeedbackGenerator(.heavy)` | Delete API key (after confirmation) |
| `DictionaryView.swift` | Swipe action | `mediumImpact()` | `UIImpactFeedbackGenerator(.medium)` | Delete word (swipe) |
| `DictionaryView.swift` | Delete button | `warning()` | `UINotificationFeedbackGenerator(.warning)` | Show bulk delete confirmation |
| `DictionaryView.swift` | `deleteSelectedWords()` | `heavyImpact()` | `UIImpactFeedbackGenerator(.heavy)` | Bulk delete words (after confirmation) |
| `ReplacementsView.swift` | Swipe action | `mediumImpact()` | `UIImpactFeedbackGenerator(.medium)` | Delete replacement (swipe) |
| `ReplacementsView.swift` | Delete button | `warning()` | `UINotificationFeedbackGenerator(.warning)` | Show bulk delete confirmation |
| `ReplacementsView.swift` | `deleteSelectedReplacements()` | `heavyImpact()` | `UIImpactFeedbackGenerator(.heavy)` | Bulk delete replacements (after confirmation) |
| `PromptsSettings.swift` | `deletePrompt()` | `mediumImpact()` | `UIImpactFeedbackGenerator(.medium)` | Delete prompt |

### Duplicate Operations

| File | Location | Method | Haptic Type | Trigger |
|------|----------|--------|-------------|---------|
| `ModeEditView.swift` | `duplicateMode()` | `heavyImpact()` | `UIImpactFeedbackGenerator(.heavy)` | Duplicate mode button |
| `SettingsView.swift` | Context menu | `heavyImpact()` | `UIImpactFeedbackGenerator(.heavy)` | Duplicate mode (context menu) |
| `SettingsView.swift` | Swipe action | `heavyImpact()` | `UIImpactFeedbackGenerator(.heavy)` | Duplicate mode (swipe) |

### Model Downloads

| File | Location | Method | Haptic Type | Trigger |
|------|----------|--------|-------------|---------|
| `LocalModelCard.swift` | Download/Cancel button | `lightImpact()` | `UIImpactFeedbackGenerator(.light)` | Download or cancel tap |
| `LocalModelCard.swift` | `downloadLocalModel()` | `heavyImpact()` | `UIImpactFeedbackGenerator(.heavy)` | Model download complete |

### API Key Operations

| File | Location | Method | Haptic Type | Trigger |
|------|----------|--------|-------------|---------|
| `CloudModelConfigurationView.swift` | `saveAPIKey()` | `mediumImpact()` | `UIImpactFeedbackGenerator(.medium)` | Save API key |
| `AddAPIKeyView.swift` | `saveAPIKey()` | `mediumImpact()` | `UIImpactFeedbackGenerator(.medium)` | Save API key |

### Settings Toggles

| File | Toggle | Method | Haptic Type |
|------|--------|--------|-------------|
| `SettingsView.swift` | Voice Activity Detection | `selectionChanged()` | `UISelectionFeedbackGenerator` |
| `SettingsView.swift` | Automatic Text Formatting | `selectionChanged()` | `UISelectionFeedbackGenerator` |
| `SettingsView.swift` | Smart Insert | `selectionChanged()` | `UISelectionFeedbackGenerator` |
| `SettingsView.swift` | Copy to Clipboard | `selectionChanged()` | `UISelectionFeedbackGenerator` |
| `SettingsView.swift` | Haptic Feedback (Keyboard) | `selectionChanged()` | `UISelectionFeedbackGenerator` |
| `SettingsView.swift` | Sound | `selectionChanged()` | `UISelectionFeedbackGenerator` |
| `SettingsView.swift` | Automatic Audio Cleanup | `selectionChanged()` | `UISelectionFeedbackGenerator` |
| `ReplacementsView.swift` | Enable Replacements | `selectionChanged()` | `UISelectionFeedbackGenerator` |

### Pickers

| File | Picker | Method | Haptic Type |
|------|--------|--------|-------------|
| `SettingsView.swift` | Session Timeout | `selectionChanged()` | `UISelectionFeedbackGenerator` |
| `SettingsView.swift` | Audio Retention Days | `selectionChanged()` | `UISelectionFeedbackGenerator` |
| `RecordingSheetView.swift` | Mode Selector | `selectionChanged()` | `UISelectionFeedbackGenerator` |
| `TranscriptionDetailView.swift` | Text Type (Original/Enhanced) | `selectionChanged()` | `UISelectionFeedbackGenerator` |
| `ModelsView.swift` | Model Type (Local/Cloud) | `selectionChanged()` | `UISelectionFeedbackGenerator` |
| `ModeEditView.swift` | All pickers | `selectionChanged()` | `UISelectionFeedbackGenerator` |

### Audio Playback

| File | Location | Method | Haptic Type | Trigger |
|------|----------|--------|-------------|---------|
| `AudioPlayerView.swift` | `togglePlayback()` | `lightImpact()` | `UIImpactFeedbackGenerator(.light)` | Play/pause |
| `AudioPlayerView.swift` | Waveform tap gesture | `selectionChanged()` | `UISelectionFeedbackGenerator` | Seek position |

### UI Components

| File | Location | Method | Haptic Type | Trigger |
|------|----------|--------|-------------|---------|
| `LiquidActionButtonView.swift` | `onTapGesture` | `mediumImpact()` | `UIImpactFeedbackGenerator(.medium)` | Expand/collapse |
| `ScrollToTopButton.swift` | Button action | `lightImpact()` | `UIImpactFeedbackGenerator(.light)` | Scroll to top |
| `MainView.swift` | Settings toolbar button | `lightImpact()` | `UIImpactFeedbackGenerator(.light)` | Open settings |
| `MainView.swift` | File import toolbar button | `lightImpact()` | `UIImpactFeedbackGenerator(.light)` | Open file import |

### Transcription Detail

| File | Function | Method | Haptic Type | Trigger |
|------|----------|--------|-------------|---------|
| `TranscriptionDetailView.swift` | `retranscribe()` | `playPattern(named:)` | CoreHaptics AHAP | Retranscribe success |
| `TranscriptionDetailView.swift` | `retranscribe()` | `error()` | `UINotificationFeedbackGenerator(.error)` | Retranscribe error |
| `TranscriptionDetailView.swift` | `enhance()` | `playPattern(named:)` | CoreHaptics AHAP | Enhancement success |
| `TranscriptionDetailView.swift` | `enhance()` | `error()` | `UINotificationFeedbackGenerator(.error)` | Enhancement error |
| `TranscriptionDetailView.swift` | `retranscribeAndEnhance()` | `playPattern(named:)` | CoreHaptics AHAP | Combined success |
| `TranscriptionDetailView.swift` | `retranscribeAndEnhance()` | `error()` | `UINotificationFeedbackGenerator(.error)` | Combined error |

### Add Operations

| File | Function | Method | Haptic Type | Trigger |
|------|----------|--------|-------------|---------|
| `DictionaryView.swift` | `addWord()` | `mediumImpact()` | `UIImpactFeedbackGenerator(.medium)` | Word added |
| `ReplacementsView.swift` | `addReplacement()` | `mediumImpact()` | `UIImpactFeedbackGenerator(.medium)` | Replacement added |

### Edit Mode Operations (Dictionary & Replacements)

| File | Location | Method | Haptic Type | Trigger |
|------|----------|--------|-------------|---------|
| `DictionaryView.swift` | Toolbar Done button | `lightImpact()` | `UIImpactFeedbackGenerator(.light)` | Exit edit mode |
| `DictionaryView.swift` | Toolbar Edit button | `lightImpact()` | `UIImpactFeedbackGenerator(.light)` | Enter edit mode |
| `DictionaryView.swift` | Select All/Deselect All | `selectionChanged()` | `UISelectionFeedbackGenerator` | Toggle all selection |
| `DictionaryView.swift` | `toggleSelection()` | `selectionChanged()` | `UISelectionFeedbackGenerator` | Toggle word selection |
| `DictionaryView.swift` | Edit swipe action | `lightImpact()` | `UIImpactFeedbackGenerator(.light)` | Open edit sheet |
| `DictionaryView.swift` | EditVocabularySheet Save | `mediumImpact()` | `UIImpactFeedbackGenerator(.medium)` | Save word changes |
| `ReplacementsView.swift` | Toolbar Done button | `lightImpact()` | `UIImpactFeedbackGenerator(.light)` | Exit edit mode |
| `ReplacementsView.swift` | Toolbar Edit button | `lightImpact()` | `UIImpactFeedbackGenerator(.light)` | Enter edit mode |
| `ReplacementsView.swift` | Enable toggle | `selectionChanged()` | `UISelectionFeedbackGenerator` | Toggle replacements |
| `ReplacementsView.swift` | Select All/Deselect All | `selectionChanged()` | `UISelectionFeedbackGenerator` | Toggle all selection |
| `ReplacementsView.swift` | `toggleSelection()` | `selectionChanged()` | `UISelectionFeedbackGenerator` | Toggle replacement selection |
| `ReplacementsView.swift` | Edit swipe action | `lightImpact()` | `UIImpactFeedbackGenerator(.light)` | Open edit sheet |
| `ReplacementsView.swift` | EditReplacementSheet Save | `mediumImpact()` | `UIImpactFeedbackGenerator(.medium)` | Save replacement changes |

### Onboarding

| File | Location | Method | Haptic Type | Trigger |
|------|----------|--------|-------------|---------|
| `OnboardingView.swift` | `navigateTo()` | `selectionChanged()` | `UISelectionFeedbackGenerator` | Page navigation |

### Error Alerts

| File | Location | Method | Haptic Type | Trigger |
|------|----------|--------|-------------|---------|
| `MainView.swift` | `startRecording()` | `warning()` | `UINotificationFeedbackGenerator(.warning)` | No model alert |
| `MainView.swift` | `handleFileImport()` | `warning()` | `UINotificationFeedbackGenerator(.warning)` | No model alert |
| `MainView.swift` | `handleFileImport()` | `error()` | `UINotificationFeedbackGenerator(.error)` | File access error |
| `MainView.swift` | `handleFileImport()` | `error()` | `UINotificationFeedbackGenerator(.error)` | File copy error |
| `MainView.swift` | `handleFileImport()` | `error()` | `UINotificationFeedbackGenerator(.error)` | Import failure |
| `MainView.swift` | `handleSharedAudioTranscription()` | `warning()` | `UINotificationFeedbackGenerator(.warning)` | No model alert |
| `MainView.swift` | `handleSharedAudioTranscription()` | `error()` | `UINotificationFeedbackGenerator(.error)` | File not found |
| `MainView.swift` | `handleSharedAudioTranscription()` | `error()` | `UINotificationFeedbackGenerator(.error)` | Copy error |
| `SettingsView.swift` | `activateKeyboardRecordingSession()` | `error()` | `UINotificationFeedbackGenerator(.error)` | Prewarm error |
| `ModeEditView.swift` | `saveMode()` | `error()` | `UINotificationFeedbackGenerator(.error)` | Duplicate name |
| `ModeEditView.swift` | `saveMode()` | `error()` | `UINotificationFeedbackGenerator(.error)` | Unexpected error |

## Design Principles

### When to Use Each Type

| Haptic Type | Use For |
|-------------|---------|
| **Impact (Light)** | Minor UI feedback, edit mode buttons, swipe actions, copy, play/pause, cancel |
| **Impact (Medium)** | Primary actions (start/stop recording, add items, expand/collapse, minor deletes, save changes, save API key) |
| **Impact (Heavy)** | Significant completions (download complete, duplicate, delete after confirmation) |
| **Selection** | Picker/toggle changes, select all/deselect all, item selection, navigation |
| **Warning** | Show delete confirmation alerts |
| **Error** | Failed operations, validation errors |
| **Custom AHAP** | Distinctive feedback (transcription complete) |

### Best Practices

1. **Don't overuse haptics** - Reserve for meaningful interactions
2. **Match intensity to importance** - Heavy for significant actions, light for minor ones
3. **Be consistent** - Same action should produce same haptic throughout app
4. **Test on device** - Simulator doesn't provide haptic feedback

## Adding New Haptics

Use the appropriate method directly:

```swift
// For primary actions (add items, start/stop recording, save changes, save API key, minor deletes)
HapticManager.mediumImpact()

// For significant completions (download, duplicate, delete after confirmation)
HapticManager.heavyImpact()

// For edit mode buttons, swipe actions, copy, cancel, play/pause
HapticManager.lightImpact()

// For toggles, pickers, select all/deselect all, item selection
HapticManager.selectionChanged()

// For showing delete confirmation alerts
HapticManager.warning()

// For errors
HapticManager.error()

// For custom patterns
HapticManager.playPattern(named: "PatternName")
```

## Related Files

- `VivaDicta/Utils/HapticManager.swift` - Main implementation
- `VivaDicta/Resources/Haptics/` - AHAP pattern files
- `VivaDicta/Shared/UserDefaultsStorage.swift` - Settings key definition
- `VivaDicta/Views/SettingsScreen/SettingsView.swift` - Global toggle UI
