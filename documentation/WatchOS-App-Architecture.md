# watchOS App Architecture

## Overview

VivaDicta includes a companion watchOS app for recording voice notes on Apple Watch. Audio is recorded on-device, transferred to the paired iPhone via WatchConnectivity, and transcribed using the existing pipeline. The watch app supports complications, Control Center integration, and Viva Mode selection.

## Targets

| Target | Description |
|--------|-------------|
| `VivaDictaWatch Watch App` | Main watch app - recording UI, WatchConnectivity, audio recorder |
| `VivaDictaWatchWidgetExtension` | Widget extension - complications and Control Center control |

Bundle ID: `com.antonnovoselov.VivaDicta.watchkitapp`

## Architecture

### Watch Side

```
VivaDictaWatchApp
  |
  +-- WatchRecordView (SwiftUI)
  |     +-- Record/Stop button (Liquid Glass, symbol effect transitions)
  |     +-- Duration timer
  |     +-- Transfer status (uploading/uploaded/error)
  |     +-- Mode picker (toolbar, NavigationLink to selection list)
  |
  +-- WatchRecordViewModel (@Observable)
  |     +-- Recording state management
  |     +-- Duration timer
  |     +-- Mode selection (persisted in UserDefaults)
  |     +-- Haptic feedback (start/stop/success/failure)
  |
  +-- WatchConnectivityService
  |     +-- transferFile() for audio
  |     +-- sendMessage() wake ping after transfer
  |     +-- Receives modes via applicationContext + transferUserInfo
  |     +-- Caches modes in UserDefaults
  |     +-- Transfer status tracking (manual count)
  |
  +-- WatchAudioRecorder
  |     +-- AVAudioRecorder wrapper
  |     +-- 16kHz mono M4A (AAC) format (~10x smaller than WAV)
  |     +-- Audio session: .playAndRecord (supports background recording)
  |     +-- Background Audio mode enabled (recording continues when wrist is lowered)
  |     +-- Records to temp directory
  |
  +-- WatchAppCoordinator
        +-- Darwin notifications for widget extension <-> app communication
        +-- Toggle recording from Control Center / Action Button
```

### iPhone Side

```
PhoneWatchConnectivityService
  |
  +-- Receives audio files via didReceive(file:)
  +-- Receives wake messages via didReceiveMessage
  +-- Sends modes via updateApplicationContext + transferUserInfo
  +-- Queues pending modes until session activates
  |
  +-- WatchAudioProcessor
        +-- Standalone transcription processor (no UI dependencies)
        +-- Temporarily switches to requested Viva Mode
        +-- Creates Transcription + TranscriptionVariation records
        +-- Orphan recovery on startup (scans for watch-*.wav and watch-*.m4a files)
```

## File Transfer Flow

```
Watch                              iPhone
  |                                  |
  | Record audio (16kHz mono M4A)    |
  | transferFile(url, metadata)      |
  | -------------------------------->|
  |   metadata:                      |
  |     sourceTag: "appleWatch"      |
  |     timestamp: recording time    |
  |     modeId: selected mode UUID   |
  |                                  |
  | sendMessage(["wake": true])      |
  | -------------------------------->|  Wakes app from suspended/terminated
  |                                  |
  |                                  |  didReceive(file:)
  |                                  |  Move to Documents/Audio/watch-*.<ext>
  |                                  |  WatchAudioProcessor.processAudioFile()
  |                                  |    - Switch to requested mode
  |                                  |    - Transcribe (Groq ~0.7s)
  |                                  |    - AI enhance (if configured)
  |                                  |    - Save Transcription to SwiftData
  |                                  |    - Restore original mode
  |                                  |
  | didFinish(fileTransfer:)         |
  | Update status -> .allUploaded    |
  | Play .success haptic             |
```

## Mode Syncing

Viva Modes are synced from iPhone to watch using two methods:

1. **`updateApplicationContext`** - persists, available via `receivedApplicationContext` on next launch
2. **`transferUserInfo`** - guaranteed delivery, queued

Modes sync on:
- iPhone app startup
- Mode add/edit/delete (via `AIService.saveModes()` -> `onModesListChanged`)

Watch caches modes in `UserDefaults` for instant availability on next launch.

The selected mode ID travels with each audio file as transfer metadata (`modeId`). The iPhone's `WatchAudioProcessor` temporarily switches `AIService` and `TranscriptionManager` to the requested mode for processing.

## Complications

Implemented in `VivaDictaWatchWidgetExtension`:

| Family | Content | Tap Action |
|--------|---------|------------|
| Circular | Custom app icon (tinted mode: luminanceToAlpha) | Opens app, starts recording |
| Corner | SF Symbol mic.fill (orange) with "Record" label | Opens app, starts recording |
| Rectangular | App icon + "VivaDicta" / "Tap to record" (tinted mode supported) | Opens app, starts recording |
| Inline | "VivaDicta" with mic icon | Opens app, starts recording |

Deep link: `vivadicta-watch://record` via `widgetURL`.

## Control Center / Action Button

`VivaDictaWatchWidgetControl` provides a "Quick Record" button for Control Center.

Communication flow:
1. `OpenRecorderIntent.perform()` posts Darwin notification `toggleRecording`
2. `WatchAppCoordinator` receives notification, calls `onToggleRecordingRequested`
3. `WatchRecordViewModel.toggleRecording()` starts or stops recording

This enables start/stop toggle via the Action Button when the control is assigned to it.

The intent file (`AppIntent.swift`) must be in **both** the widget extension and watch app targets for `openAppWhenRun` to work.

## Background Transcription

When the watch sends audio via `transferFile()`, followed by a `sendMessage()` wake ping:
- If iPhone is **suspended**: `sendMessage` wakes it, files are received and transcribed in background
- If iPhone is **terminated**: `sendMessage` launches it in background state, files are processed before the user opens the app
- If iPhone is **unreachable**: files queue in WatchConnectivity and deliver when reconnected

Each received file is protected by a two-layer background task system (see [Background-Task-Architecture.md](Background-Task-Architecture.md)):
1. **`beginBackgroundTask`** - immediate ~30s execution per file
2. **`BGProcessingTask` fallback** - if time expires, unfinished work is enqueued and retried when iOS wakes the app

Startup recovery runs in order: queued items first (with full metadata), then orphan scan as catch-all.

Orphan recovery: on app startup, `WatchAudioProcessor.processOrphanedFiles()` scans `Documents/Audio/` for `watch-*.wav` and `watch-*.m4a` files without matching Transcription records.

## Key Files

### Watch App
- `VivaDictaWatchApp.swift` - App entry point, deep link handling, coordinator setup
- `Views/WatchRecordView.swift` - Main UI with Liquid Glass buttons
- `ViewModels/WatchRecordViewModel.swift` - Recording state, mode selection
- `Services/WatchConnectivityService.swift` - File transfer, mode receiving
- `Services/WatchAudioRecorder.swift` - AVAudioRecorder wrapper
- `Services/WatchAppCoordinator.swift` - Darwin notifications for widget communication
- `Models/WatchModeInfo.swift` - Lightweight mode representation for watch
- `Models/WatchTransferStatus.swift` - Transfer status enum

### Widget Extension
- `VivaDictaWatchWidget.swift` - Complications for all families
- `VivaDictaWatchWidgetControl.swift` - Control Center button
- `VivaDictaWatchWidgetBundle.swift` - Widget bundle registration
- `AppIntent.swift` - OpenRecorderIntent (must be in both targets)

### iPhone (modified)
- `Services/PhoneWatchConnectivityService.swift` - Receives files, syncs modes
- `Services/WatchAudioProcessor.swift` - Background transcription processor
- `AppState.swift` - Wires watch connectivity and mode sync
- `AppDelegate.swift` - Lifecycle logging
- `Models/SourceTag.swift` - `appleWatch` source tag
- `Utilities/LoggerExtension.swift` - `watchConnectivity` log category
