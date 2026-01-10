# Haptic Feedback Implementation

This document describes the haptic feedback system implemented in VivaDicta.

## Overview

VivaDicta uses a centralized `HapticManager` utility for all haptic feedback. This provides:
- Consistent haptic patterns across the app
- Global enable/disable toggle in Settings
- Both low-level and semantic APIs for different use cases

## HapticManager API

Location: `VivaDicta/Utils/HapticManager.swift`

### Settings

Haptics can be globally enabled/disabled via:
- **Settings > Feedback > Haptic Feedback** toggle
- Stored in `UserDefaults` with key `isHapticsEnabled`
- Enabled by default

### Low-Level API

Direct access to UIKit feedback generators:

| Method | UIKit Generator | Use Case |
|--------|-----------------|----------|
| `lightImpact()` | `UIImpactFeedbackGenerator(.light)` | Subtle feedback |
| `mediumImpact()` | `UIImpactFeedbackGenerator(.medium)` | Standard taps |
| `heavyImpact()` | `UIImpactFeedbackGenerator(.heavy)` | Significant actions |
| `softImpact()` | `UIImpactFeedbackGenerator(.soft)` | Gentle, cushioned |
| `rigidImpact()` | `UIImpactFeedbackGenerator(.rigid)` | Crisp, sharp |
| `selectionChanged()` | `UISelectionFeedbackGenerator` | Pickers, toggles |
| `success()` | `UINotificationFeedbackGenerator(.success)` | Completed operations |
| `warning()` | `UINotificationFeedbackGenerator(.warning)` | Destructive actions |
| `error()` | `UINotificationFeedbackGenerator(.error)` | Failed operations |

### Semantic API (Recommended)

High-level methods that map to specific user actions:

| Method | Maps To | Description |
|--------|---------|-------------|
| `recordingStarted()` | `mediumImpact()` | Recording begins |
| `recordingStopped()` | `heavyImpact()` | Recording ends |
| `actionCancelled()` | `lightImpact()` | User cancels action |
| `processingCompleted()` | `success()` | Transcription/enhancement done |
| `copiedToClipboard()` | `success()` | Text copied |
| `itemDeleted()` | `warning()` | Delete operation |
| `downloadCompleted()` | `success()` | Model download finished |
| `toggleChanged()` | `selectionChanged()` | Toggle state change |
| `pickerSelectionChanged()` | `selectionChanged()` | Picker value change |
| `buttonToggled()` | `softImpact()` | Expand/collapse |
| `playbackToggled()` | `lightImpact()` | Play/pause audio |
| `errorOccurred()` | `error()` | Error state |

## Implementation by File

### Recording Flow

| File | Location | Haptic | Trigger |
|------|----------|--------|---------|
| `RecordViewModel.swift` | Line ~139 | `recordingStarted()` | Prewarm recording start |
| `RecordViewModel.swift` | Line ~184 | `recordingStarted()` | Normal recording start |
| `RecordViewModel.swift` | Line ~245 | `recordingStopped()` | Stop recording |
| `RecordViewModel.swift` | Line ~524 | `actionCancelled()` | Cancel recording |
| `RecordViewModel.swift` | Line ~484 | `processingCompleted()` | Transcription complete |
| `RecordViewModel.swift` | Line ~492 | `errorOccurred()` | Transcription error |

### Copy Actions

| File | Location | Haptic | Trigger |
|------|----------|--------|---------|
| `AnimatedCopyButton.swift` | Line ~48 | `copiedToClipboard()` | Copy to clipboard |

### Delete Operations

| File | Location | Haptic | Trigger |
|------|----------|--------|---------|
| `TranscriptionsContentView.swift` | `deleteTranscription()` | `itemDeleted()` | Delete transcription |
| `SettingsView.swift` | `deleteMode()` | `itemDeleted()` | Delete mode |
| `LocalModelCard.swift` | `deleteModel()` | `itemDeleted()` | Delete local model |
| `CloudModelCard.swift` | `deleteAPIKey()` | `itemDeleted()` | Delete API key |
| `DictionaryView.swift` | Swipe action | `itemDeleted()` | Delete word (swipe) |
| `DictionaryView.swift` | `deleteSelectedWords()` | `itemDeleted()` | Bulk delete words |
| `ReplacementsView.swift` | Swipe action | `itemDeleted()` | Delete replacement (swipe) |
| `ReplacementsView.swift` | `deleteSelectedReplacements()` | `itemDeleted()` | Bulk delete replacements |
| `PromptsSettings.swift` | `deletePrompt()` | `itemDeleted()` | Delete prompt |

### Model Downloads

| File | Location | Haptic | Trigger |
|------|----------|--------|---------|
| `LocalModelCard.swift` | Download/Delete button | `lightImpact()` | Button tap |
| `LocalModelCard.swift` | `downloadLocalModel()` | `downloadCompleted()` | Model download complete |

### Settings Toggles

| File | Toggle | Haptic |
|------|--------|--------|
| `SettingsView.swift` | Voice Activity Detection | `toggleChanged()` |
| `SettingsView.swift` | Automatic Text Formatting | `toggleChanged()` |
| `SettingsView.swift` | Smart Insert | `toggleChanged()` |
| `SettingsView.swift` | Copy to Clipboard | `toggleChanged()` |
| `SettingsView.swift` | Haptic Feedback (Keyboard) | `toggleChanged()` |
| `SettingsView.swift` | Sound | `toggleChanged()` |
| `SettingsView.swift` | Automatic Audio Cleanup | `toggleChanged()` |
| `ReplacementsView.swift` | Enable Replacements | `toggleChanged()` |

### Pickers

| File | Picker | Haptic |
|------|--------|--------|
| `SettingsView.swift` | Session Timeout | `pickerSelectionChanged()` |
| `SettingsView.swift` | Audio Retention Days | `pickerSelectionChanged()` |
| `RecordingSheetView.swift` | Mode Selector | `pickerSelectionChanged()` |
| `TranscriptionDetailView.swift` | Text Type (Original/Enhanced) | `selectionChanged()` |
| `ModelsView.swift` | Model Type (Local/Cloud) | `selectionChanged()` |

### Audio Playback

| File | Location | Haptic | Trigger |
|------|----------|--------|---------|
| `AudioPlayerView.swift` | `togglePlayback()` | `playbackToggled()` | Play/pause |
| `AudioPlayerView.swift` | Waveform tap gesture | `selectionChanged()` | Seek position |

### UI Components

| File | Location | Haptic | Trigger |
|------|----------|--------|---------|
| `LiquidActionButtonView.swift` | `onTapGesture` | `buttonToggled()` | Expand/collapse |
| `ScrollToTopButton.swift` | Button action | `lightImpact()` | Scroll to top |

### Transcription Detail

| File | Function | Haptic | Trigger |
|------|----------|--------|---------|
| `TranscriptionDetailView.swift` | `retranscribe()` | `processingCompleted()` | Retranscribe success |
| `TranscriptionDetailView.swift` | `retranscribe()` | `errorOccurred()` | Retranscribe error |
| `TranscriptionDetailView.swift` | `enhance()` | `processingCompleted()` | Enhancement success |
| `TranscriptionDetailView.swift` | `enhance()` | `errorOccurred()` | Enhancement error |
| `TranscriptionDetailView.swift` | `retranscribeAndEnhance()` | `processingCompleted()` | Combined success |
| `TranscriptionDetailView.swift` | `retranscribeAndEnhance()` | `errorOccurred()` | Combined error |

### Add Operations

| File | Function | Haptic | Trigger |
|------|----------|--------|---------|
| `DictionaryView.swift` | `addWord()` | `success()` | Word added |
| `ReplacementsView.swift` | `addReplacement()` | `success()` | Replacement added |

### Onboarding

| File | Location | Haptic | Trigger |
|------|----------|--------|---------|
| `OnboardingView.swift` | `navigateTo()` | `selectionChanged()` | Page navigation |

### Error Alerts

| File | Location | Haptic | Trigger |
|------|----------|--------|---------|
| `MainView.swift` | `startRecording()` | `warning()` | No model alert |
| `MainView.swift` | `handleFileImport()` | `warning()` | No model alert |
| `MainView.swift` | `handleFileImport()` | `errorOccurred()` | File access error |
| `MainView.swift` | `handleFileImport()` | `errorOccurred()` | File copy error |
| `MainView.swift` | `handleFileImport()` | `errorOccurred()` | Import failure |
| `MainView.swift` | `handleSharedAudioTranscription()` | `warning()` | No model alert |
| `MainView.swift` | `handleSharedAudioTranscription()` | `errorOccurred()` | File not found |
| `MainView.swift` | `handleSharedAudioTranscription()` | `errorOccurred()` | Copy error |
| `SettingsView.swift` | `activateKeyboardRecordingSession()` | `errorOccurred()` | Prewarm error |
| `ModeEditView.swift` | `saveMode()` | `errorOccurred()` | Duplicate name |
| `ModeEditView.swift` | `saveMode()` | `errorOccurred()` | Unexpected error |

## Design Principles

### When to Use Each Type

| Haptic Type | Use For |
|-------------|---------|
| **Impact (Light)** | Minor UI feedback, subtle confirmations |
| **Impact (Medium)** | Primary action initiation |
| **Impact (Heavy)** | Significant state changes |
| **Impact (Soft)** | Smooth UI transitions |
| **Selection** | Picker/toggle changes, navigation |
| **Success** | Completed operations, positive outcomes |
| **Warning** | Destructive actions (delete), caution states |
| **Error** | Failed operations, validation errors |

### Best Practices

1. **Use semantic API when possible** - `recordingStarted()` is clearer than `mediumImpact()`
2. **Don't overuse haptics** - Reserve for meaningful interactions
3. **Match intensity to importance** - Heavy for significant actions, light for minor ones
4. **Be consistent** - Same action should produce same haptic throughout app
5. **Test on device** - Simulator doesn't provide haptic feedback

## Adding New Haptics

1. **For common patterns**, use existing semantic methods:
   ```swift
   HapticManager.itemDeleted()
   ```

2. **For new semantic actions**, add a method to `HapticManager`:
   ```swift
   static func newAction() {
       mediumImpact()
   }
   ```

3. **For one-off cases**, use low-level API:
   ```swift
   HapticManager.lightImpact()
   ```

## Related Files

- `VivaDicta/Utils/HapticManager.swift` - Main implementation
- `VivaDicta/Shared/UserDefaultsStorage.swift` - Settings key definition
- `VivaDicta/Views/SettingsScreen/SettingsView.swift` - Global toggle UI
