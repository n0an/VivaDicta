# Haptic Feedback Implementation

This document describes the haptic feedback system implemented in VivaDicta.

## Overview

VivaDicta uses a centralized `HapticManager` utility for all haptic feedback. This provides:
- Consistent haptic patterns across the app
- Global enable/disable toggle in Settings
- Direct access to UIKit feedback generators and CoreHaptics

## HapticManager API

Location: `VivaDicta/Utils/HapticManager.swift`

### Settings

Haptics can be globally enabled/disabled via:
- **Settings > Feedback > Haptic Feedback** toggle
- Stored in `UserDefaultsStorage.appPrivate` with key `isHapticsEnabled`
- Enabled by default

### API Reference

| Method | Implementation | Use Case |
|--------|----------------|----------|
| `lightImpact()` | `UIImpactFeedbackGenerator(.light)` | Edit mode buttons, swipe actions, copy, play/pause, cancel, navigation buttons |
| `mediumImpact()` | `UIImpactFeedbackGenerator(.medium)` | Start/stop recording, add items, save changes, save API key |
| `heavyImpact()` | `UIImpactFeedbackGenerator(.heavy)` | Significant completions (download, duplicate, delete after confirmation) |
| `selectionChanged()` | `UISelectionFeedbackGenerator` | Pickers, toggles, select all, item selection |
| `warning()` | `UINotificationFeedbackGenerator(.warning)` | Show delete/destructive confirmation alerts |
| `error()` | `UINotificationFeedbackGenerator(.error)` | Failed operations |
| `transcriptionComplete()` | CoreHaptics (programmatic) | Transcription/enhancement completion |
| `playPattern(named:)` | CoreHaptics AHAP | Custom patterns from AHAP files |

### CoreHaptics Patterns

#### transcriptionComplete()

A celebratory haptic pattern built programmatically using CoreHaptics:
- **Continuous buzz**: 1.0s duration, soft sharpness (0), fades from full to zero intensity
- **Sparkles**: 4 random transient events with sharp feedback scattered across 0.1-1.0s
- **Fallback**: Uses `.success` notification if CoreHaptics unavailable

#### AHAP Files

Location: `VivaDicta/Resources/Haptics/`

| File | Description | Status |
|------|-------------|--------|
| `TranscriptionComplete.ahap` | Heartbeat pulse pattern | Legacy (replaced by programmatic `transcriptionComplete()`) |

## Implementation by File

### Recording Flow

| File | Line | Method | Trigger |
|------|------|--------|---------|
| `RecordViewModel.swift` | ~140 | `mediumImpact()` | Prewarm recording start |
| `RecordViewModel.swift` | ~185 | `mediumImpact()` | Normal recording start |
| `RecordViewModel.swift` | ~245 | `mediumImpact()` | Stop recording |
| `RecordViewModel.swift` | ~420 | `lightImpact()` | State transition to transcribing |
| `RecordViewModel.swift` | ~485 | `transcriptionComplete()` | Transcription complete |
| `RecordViewModel.swift` | ~493 | `error()` | Transcription error |
| `RecordViewModel.swift` | ~527 | `lightImpact()` | Cancel recording |

### Copy Actions

| File | Line | Method | Trigger |
|------|------|--------|---------|
| `AnimatedCopyButton.swift` | ~48 | `lightImpact()` | Copy to clipboard |

### Delete Operations

| File | Location | Method | Trigger |
|------|----------|--------|---------|
| `TranscriptionsContentView.swift` | ~187 | `heavyImpact()` | Delete transcription |
| `SettingsView.swift` | ~418 | `heavyImpact()` | Delete mode (after confirmation) |
| `ModeEditView.swift` | ~392 | `heavyImpact()` | Delete mode (after confirmation) |
| `LocalModelCard.swift` | ~143-149 | `lightImpact()` / `warning()` | Download/cancel/delete button tap |
| `LocalModelCard.swift` | ~218 | `warning()` | Show delete confirmation (context menu) |
| `LocalModelCard.swift` | ~252, ~279 | `heavyImpact()` | Delete local model (after confirmation) |
| `CloudModelCard.swift` | ~164 | `warning()` | Show delete confirmation |
| `CloudModelCard.swift` | ~182 | `heavyImpact()` | Delete API key (after confirmation) |
| `CloudModelConfigurationView.swift` | ~69 | `warning()` | Show delete confirmation |
| `CloudModelConfigurationView.swift` | ~133 | `heavyImpact()` | Delete API key (after confirmation) |
| `DictionaryView.swift` | ~135 | `mediumImpact()` | Delete word (swipe) |
| `DictionaryView.swift` | ~97 | `warning()` | Show bulk delete confirmation |
| `DictionaryView.swift` | ~165 | `heavyImpact()` | Bulk delete words (after confirmation) |
| `ReplacementsView.swift` | ~172 | `mediumImpact()` | Delete replacement (swipe) |
| `ReplacementsView.swift` | ~122 | `warning()` | Show bulk delete confirmation |
| `ReplacementsView.swift` | ~202 | `heavyImpact()` | Bulk delete replacements (after confirmation) |
| `PromptsSettings.swift` | ~79 | `mediumImpact()` | Delete prompt |

### Duplicate Operations

| File | Location | Method | Trigger |
|------|----------|--------|---------|
| `ModeEditView.swift` | ~384 | `heavyImpact()` | Duplicate mode button |
| `SettingsView.swift` | ~59 | `heavyImpact()` | Duplicate mode (context menu) |
| `SettingsView.swift` | ~84 | `heavyImpact()` | Duplicate mode (swipe) |

### Model Downloads

| File | Location | Method | Trigger |
|------|----------|--------|---------|
| `LocalModelCard.swift` | ~143, ~146 | `lightImpact()` | Download or cancel tap |
| `LocalModelCard.swift` | ~252, ~279 | `heavyImpact()` | Model download complete |

### API Key Operations

| File | Location | Method | Trigger |
|------|----------|--------|---------|
| `CloudModelConfigurationView.swift` | ~116 | `mediumImpact()` | Save API key |
| `AddAPIKeyView.swift` | ~104 | `mediumImpact()` | Save API key |
| `CloudModelCard.swift` | ~85 | `lightImpact()` | Open model configuration |
| `CloudModelCard.swift` | ~157 | `lightImpact()` | Edit API key (context menu) |

### Settings Toggles

| File | Toggle | Method |
|------|--------|--------|
| `SettingsView.swift` | Voice Activity Detection | `selectionChanged()` |
| `SettingsView.swift` | Automatic Text Formatting | `selectionChanged()` |
| `SettingsView.swift` | Smart Insert | `selectionChanged()` |
| `SettingsView.swift` | Copy to Clipboard | `selectionChanged()` |
| `SettingsView.swift` | Haptic Feedback (Keyboard) | `selectionChanged()` |
| `SettingsView.swift` | Sound | `selectionChanged()` |
| `SettingsView.swift` | Automatic Audio Cleanup | `selectionChanged()` |
| `ReplacementsView.swift` | Enable Replacements | `selectionChanged()` |

### Pickers

| File | Picker | Method |
|------|--------|--------|
| `SettingsView.swift` | Session Timeout | `selectionChanged()` |
| `SettingsView.swift` | Audio Retention Days | `selectionChanged()` |
| `RecordingSheetView.swift` | Mode Selector | `selectionChanged()` |
| `TranscriptionDetailView.swift` | Text Type (Original/Enhanced) | `selectionChanged()` |
| `ModelsView.swift` | Model Type (Local/Cloud) | `selectionChanged()` |
| `ModeEditView.swift` | All pickers (provider, model, language, prompt) | `selectionChanged()` |

### Audio Playback

| File | Location | Method | Trigger |
|------|----------|--------|---------|
| `AudioPlayerView.swift` | ~252 | `lightImpact()` | Play/pause |
| `AudioPlayerView.swift` | ~176 | `selectionChanged()` | Seek position (waveform tap) |

### UI Components

| File | Location | Method | Trigger |
|------|----------|--------|---------|
| `LiquidActionButtonView.swift` | ~84 | `mediumImpact()` | Expand/collapse |
| `ScrollToTopButton.swift` | ~16 | `lightImpact()` | Scroll to top |
| `MainView.swift` | ~54, ~71 | `lightImpact()` | Settings/file import toolbar buttons |
| `MainView.swift` | ~92, ~109 | `lightImpact()` | Additional toolbar buttons |
| `KeyboardFlowSheet.swift` | ~48 | `mediumImpact()` | Start keyboard session |
| `KeyboardFlowSheet.swift` | ~52 | `lightImpact()` | Stop keyboard session |

### Transcription Detail

| File | Function | Method | Trigger |
|------|----------|--------|---------|
| `TranscriptionDetailView.swift` | `retranscribe()` | `transcriptionComplete()` | Retranscribe success |
| `TranscriptionDetailView.swift` | `retranscribe()` | `error()` | Retranscribe error |
| `TranscriptionDetailView.swift` | `enhance()` | `transcriptionComplete()` | Enhancement success |
| `TranscriptionDetailView.swift` | `enhance()` | `error()` | Enhancement error |
| `TranscriptionDetailView.swift` | `retranscribeAndEnhance()` | `transcriptionComplete()` | Combined success |
| `TranscriptionDetailView.swift` | `retranscribeAndEnhance()` | `error()` | Combined error |

### Add Operations

| File | Function | Method | Trigger |
|------|----------|--------|---------|
| `DictionaryView.swift` | `addWord()` | `mediumImpact()` | Word added |
| `ReplacementsView.swift` | `addReplacement()` | `mediumImpact()` | Replacement added |
| `PromptsSettings.swift` | FAB button | `lightImpact()` | Open add prompt |

### Edit Mode Operations (Dictionary & Replacements)

| File | Location | Method | Trigger |
|------|----------|--------|---------|
| `DictionaryView.swift` | Toolbar Done button | `lightImpact()` | Exit edit mode |
| `DictionaryView.swift` | Toolbar Edit button | `lightImpact()` | Enter edit mode |
| `DictionaryView.swift` | Select All/Deselect All | `selectionChanged()` | Toggle all selection |
| `DictionaryView.swift` | `toggleSelection()` | `selectionChanged()` | Toggle word selection |
| `DictionaryView.swift` | Edit swipe action | `lightImpact()` | Open edit sheet |
| `DictionaryView.swift` | EditVocabularySheet Save | `mediumImpact()` | Save word changes |
| `ReplacementsView.swift` | Toolbar Done button | `lightImpact()` | Exit edit mode |
| `ReplacementsView.swift` | Toolbar Edit button | `lightImpact()` | Enter edit mode |
| `ReplacementsView.swift` | Select All/Deselect All | `selectionChanged()` | Toggle all selection |
| `ReplacementsView.swift` | `toggleSelection()` | `selectionChanged()` | Toggle replacement selection |
| `ReplacementsView.swift` | Edit swipe action | `lightImpact()` | Open edit sheet |
| `ReplacementsView.swift` | EditReplacementSheet Save | `mediumImpact()` | Save replacement changes |

### Prompts

| File | Location | Method | Trigger |
|------|----------|--------|---------|
| `PromptsSettings.swift` | ~33 | `lightImpact()` | FAB button tap |
| `PromptFormView.swift` | ~142 | `lightImpact()` | Close button |
| `PromptInstructionsEditorView.swift` | ~25, ~31 | `lightImpact()` | Done/Cancel buttons |

### Onboarding

| File | Location | Method | Trigger |
|------|----------|--------|---------|
| `OnboardingView.swift` | ~58 | `lightImpact()` | Page navigation |
| `OnboardingView.swift` | ~187 | `lightImpact()` | Skip onboarding |
| `OnboardingView.swift` | ~202 | `lightImpact()` | Open keyboard settings |

### Error Alerts

| File | Location | Method | Trigger |
|------|----------|--------|---------|
| `MainView.swift` | ~317, ~331 | `warning()` | No model alert |
| `MainView.swift` | ~344, ~369, ~376 | `error()` | File access/copy/import error |
| `MainView.swift` | ~386 | `warning()` | No model alert (shared audio) |
| `MainView.swift` | ~404, ~438 | `error()` | File not found/copy error |
| `SettingsView.swift` | ~442 | `error()` | Prewarm session error |
| `ModeEditView.swift` | ~371, ~375 | `error()` | Duplicate name / unexpected error |

## Design Principles

### When to Use Each Type

| Haptic Type | Use For |
|-------------|---------|
| **Impact (Light)** | Minor UI feedback, edit mode buttons, swipe actions, copy, play/pause, cancel, navigation buttons |
| **Impact (Medium)** | Primary actions (start/stop recording, add items, expand/collapse, minor deletes, save changes, save API key) |
| **Impact (Heavy)** | Significant completions (download complete, duplicate, delete after confirmation) |
| **Selection** | Picker/toggle changes, select all/deselect all, item selection in edit mode |
| **Warning** | Show delete confirmation alerts |
| **Error** | Failed operations, validation errors |
| **transcriptionComplete()** | Successful transcription/enhancement completion |

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

// For edit mode buttons, swipe actions, copy, cancel, play/pause, navigation buttons
HapticManager.lightImpact()

// For toggles, pickers, select all/deselect all, item selection
HapticManager.selectionChanged()

// For showing delete confirmation alerts
HapticManager.warning()

// For errors
HapticManager.error()

// For transcription/enhancement completion
HapticManager.transcriptionComplete()

// For custom AHAP patterns (if needed)
HapticManager.playPattern(named: "PatternName")
```

## Related Files

- `VivaDicta/Utils/HapticManager.swift` - Main implementation
- `VivaDicta/Resources/Haptics/` - AHAP pattern files (legacy)
- `VivaDicta/Shared/UserDefaultsStorage.swift` - Settings key definition
- `VivaDicta/Views/SettingsScreen/SettingsView.swift` - Global toggle UI
