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
| `lightImpact()` | `UIImpactFeedbackGenerator(.light)` | Subtle feedback, play/pause, cancel |
| `mediumImpact()` | `UIImpactFeedbackGenerator(.medium)` | Start recording, confirm actions |
| `heavyImpact()` | `UIImpactFeedbackGenerator(.heavy)` | Stop recording |
| `softImpact()` | `UIImpactFeedbackGenerator(.soft)` | Expand/collapse animations |
| `rigidImpact()` | `UIImpactFeedbackGenerator(.rigid)` | Crisp, sharp feedback |
| `selectionChanged()` | `UISelectionFeedbackGenerator` | Pickers, toggles, navigation |
| `success()` | `UINotificationFeedbackGenerator(.success)` | Completed operations, copy, add |
| `warning()` | `UINotificationFeedbackGenerator(.warning)` | Delete operations |
| `error()` | `UINotificationFeedbackGenerator(.error)` | Failed operations |
| `playPattern(named:)` | CoreHaptics AHAP | Custom patterns (transcription complete) |

## Implementation by File

### Recording Flow

| File | Location | Method | Haptic Type | Trigger |
|------|----------|--------|-------------|---------|
| `RecordViewModel.swift` | Line ~139 | `mediumImpact()` | `UIImpactFeedbackGenerator(.medium)` | Prewarm recording start |
| `RecordViewModel.swift` | Line ~184 | `mediumImpact()` | `UIImpactFeedbackGenerator(.medium)` | Normal recording start |
| `RecordViewModel.swift` | Line ~244 | `heavyImpact()` | `UIImpactFeedbackGenerator(.heavy)` | Stop recording |
| `RecordViewModel.swift` | Line ~525 | `lightImpact()` | `UIImpactFeedbackGenerator(.light)` | Cancel recording |
| `RecordViewModel.swift` | Line ~483 | `playPattern(named:)` | CoreHaptics AHAP | Transcription complete |
| `RecordViewModel.swift` | Line ~491 | `error()` | `UINotificationFeedbackGenerator(.error)` | Transcription error |

### Copy Actions

| File | Location | Method | Haptic Type | Trigger |
|------|----------|--------|-------------|---------|
| `AnimatedCopyButton.swift` | Line ~48 | `success()` | `UINotificationFeedbackGenerator(.success)` | Copy to clipboard |

### Delete Operations

| File | Location | Method | Haptic Type | Trigger |
|------|----------|--------|-------------|---------|
| `TranscriptionsContentView.swift` | `deleteTranscription()` | `warning()` | `UINotificationFeedbackGenerator(.warning)` | Delete transcription |
| `SettingsView.swift` | `deleteMode()` | `warning()` | `UINotificationFeedbackGenerator(.warning)` | Delete mode |
| `LocalModelCard.swift` | `deleteModel()` | `warning()` | `UINotificationFeedbackGenerator(.warning)` | Delete local model |
| `CloudModelCard.swift` | `deleteAPIKey()` | `warning()` | `UINotificationFeedbackGenerator(.warning)` | Delete API key |
| `DictionaryView.swift` | Swipe action | `warning()` | `UINotificationFeedbackGenerator(.warning)` | Delete word (swipe) |
| `DictionaryView.swift` | `deleteSelectedWords()` | `warning()` | `UINotificationFeedbackGenerator(.warning)` | Bulk delete words |
| `ReplacementsView.swift` | Swipe action | `warning()` | `UINotificationFeedbackGenerator(.warning)` | Delete replacement (swipe) |
| `ReplacementsView.swift` | `deleteSelectedReplacements()` | `warning()` | `UINotificationFeedbackGenerator(.warning)` | Bulk delete replacements |
| `PromptsSettings.swift` | `deletePrompt()` | `warning()` | `UINotificationFeedbackGenerator(.warning)` | Delete prompt |

### Duplicate Operations

| File | Location | Method | Haptic Type | Trigger |
|------|----------|--------|-------------|---------|
| `ModeEditView.swift` | `duplicateMode()` | `success()` | `UINotificationFeedbackGenerator(.success)` | Duplicate mode button |
| `SettingsView.swift` | Context menu | `success()` | `UINotificationFeedbackGenerator(.success)` | Duplicate mode (context menu) |
| `SettingsView.swift` | Swipe action | `success()` | `UINotificationFeedbackGenerator(.success)` | Duplicate mode (swipe) |

### Model Downloads

| File | Location | Method | Haptic Type | Trigger |
|------|----------|--------|-------------|---------|
| `LocalModelCard.swift` | Download/Delete button | `lightImpact()` | `UIImpactFeedbackGenerator(.light)` | Button tap |
| `LocalModelCard.swift` | Download alert "Continue" | `mediumImpact()` | `UIImpactFeedbackGenerator(.medium)` | Confirm download |
| `LocalModelCard.swift` | `downloadLocalModel()` | `success()` | `UINotificationFeedbackGenerator(.success)` | Model download complete |

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
| `LiquidActionButtonView.swift` | `onTapGesture` | `softImpact()` | `UIImpactFeedbackGenerator(.soft)` | Expand/collapse |
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
| `DictionaryView.swift` | `addWord()` | `success()` | `UINotificationFeedbackGenerator(.success)` | Word added |
| `ReplacementsView.swift` | `addReplacement()` | `success()` | `UINotificationFeedbackGenerator(.success)` | Replacement added |

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
| **Impact (Light)** | Minor UI feedback, subtle confirmations, play/pause |
| **Impact (Medium)** | Primary action initiation (start recording) |
| **Impact (Heavy)** | Significant state changes (stop recording) |
| **Impact (Soft)** | Smooth UI transitions (expand/collapse) |
| **Selection** | Picker/toggle changes, navigation |
| **Success** | Completed operations, copy, add, duplicate |
| **Warning** | Destructive actions (delete), caution states |
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
// For delete operations
HapticManager.warning()

// For success/completion
HapticManager.success()

// For toggles/pickers
HapticManager.selectionChanged()

// For subtle feedback
HapticManager.lightImpact()

// For custom patterns
HapticManager.playPattern(named: "PatternName")
```

## Related Files

- `VivaDicta/Utils/HapticManager.swift` - Main implementation
- `VivaDicta/Resources/Haptics/` - AHAP pattern files
- `VivaDicta/Shared/UserDefaultsStorage.swift` - Settings key definition
- `VivaDicta/Views/SettingsScreen/SettingsView.swift` - Global toggle UI
