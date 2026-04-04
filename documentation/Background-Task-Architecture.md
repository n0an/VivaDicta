# Background Task Architecture

## Overview

VivaDicta uses iOS background task APIs to protect transcription and AI processing from being killed when the app moves to background. This is critical for two scenarios:

1. **Watch audio processing (primary)** - When Apple Watch sends audio files via WatchConnectivity, the iPhone app processes them entirely in background
2. **Main app transcription** - When the user switches apps during an active transcription

## iOS Background Task APIs

| API | What it does | SwiftUI modifier? |
|-----|-------------|-------------------|
| `UIApplication.beginBackgroundTask` | Immediate ~30s execution time | No |
| `BGProcessingTask` | Longer deferred work (minutes) | No |
| `BGAppRefreshTask` | Periodic data refresh | Yes (`.appRefresh`) |
| Background `URLSession` | Background downloads | Yes (`.urlSession`) |

We use `beginBackgroundTask` and `BGProcessingTask`. SwiftUI's `.backgroundTask` modifier does not support `BGProcessingTask` - only `.appRefresh` and `.urlSession`.

## Two-Layer Protection

### Layer 1: `UIApplication.beginBackgroundTask` (Immediate)

Requests ~30 seconds of continued execution when the app enters background. Each processing task gets its own background task identifier, supporting concurrent Watch file processing.

- **Watch path**: Each `didReceive(file:)` call creates its own background task via `BackgroundTaskService.beginBackgroundTask(name:onExpiration:)`
- **Main app path**: `RecordViewModel.transcribeSpeechTask()` wraps itself in a background task

The expiration handler ends the UIKit background task immediately (iOS requirement) and enqueues the work for Layer 2.

### Layer 2: `BGProcessingTask` via `BGTaskScheduler` (Deferred Fallback)

If Layer 1's time expires before Watch audio processing finishes, the expiration handler:
1. Saves the unfinished work to a persistent `BackgroundTaskQueue` (UserDefaults-backed)
2. Schedules a `BGProcessingTask` with `earliestBeginDate` of 1 second ("as soon as possible")

iOS will wake the app later (when device is idle) to drain the queue.

**Note**: The main app transcription path does not use the queue fallback because RecordViewModel has UI dependencies (state updates, haptics, Spotlight indexing) that can't run headlessly.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   BackgroundTaskService                  │
│                                                         │
│  beginBackgroundTask(name:onExpiration:)                 │
│    -> Returns UIBackgroundTaskIdentifier per caller      │
│    -> Expiration handler ends task + calls callback      │
│                                                         │
│  endBackgroundTask(_ identifier:)                        │
│    -> Ends a specific background task                    │
│                                                         │
│  scheduleBGProcessingTask()                              │
│    -> Submits BGProcessingTaskRequest to iOS             │
│                                                         │
│  enqueueForLaterProcessing(audioURL:sourceTag:modeId:)   │
│    -> Saves work item to BackgroundTaskQueue             │
│                                                         │
│  processQueue()                                          │
│    -> Peeks items, checks for duplicates, processes,     │
│       removes only after success                         │
├─────────────────────────────────────────────────────────┤
│                   BackgroundTaskQueue                    │
│                                                         │
│  Persistent queue of BackgroundWorkItem (Codable)        │
│  Stored in UserDefaults, survives app termination        │
│  peek() -> does not remove (safe against crashes)        │
│  remove(id:) -> only after successful processing         │
│  Max 3 retries per item, 24-hour age limit               │
│  Duplicate check: skips files with existing Transcription│
└─────────────────────────────────────────────────────────┘
```

## Watch Audio Flow

```
Watch                              iPhone
  |                                  |
  | transferFile(audio, metadata)    |
  | -------------------------------->|
  |                                  |
  | sendMessage(["wake": true])      |
  | -------------------------------->|  Wakes app
  |                                  |
  |                                  |  didReceive(file:)
  |                                  |    |
  |                                  |    +-- Move file to Documents/Audio/
  |                                  |    +-- beginBackgroundTask ----------+
  |                                  |    |                                |
  |                                  |    +-- WatchAudioProcessor          |
  |                                  |    |   .processAudioFile()          |
  |                                  |    |   (transcribe + enhance        |
  |                                  |    |    + save to SwiftData)        |
  |                                  |    |                                |
  |                                  |    +-- Success?                     |
  |                                  |    |   +-- YES -> endBGTask --------+
  |                                  |    |   |
  |                                  |    |   +-- TIME EXPIRED ->
  |                                  |    |       +-- endBGTask (required by iOS)
  |                                  |    |       +-- Enqueue to BackgroundTaskQueue
  |                                  |    |       +-- Schedule BGProcessingTask
  |                                  |    |
  |                                  |    |  ... later, iOS wakes app ...
  |                                  |    |
  |                                  |    +-- handleBGProcessingTask()
  |                                  |        +-- processQueue()
  |                                  |            +-- Check for existing Transcription
  |                                  |            +-- WatchAudioProcessor (if no dupe)
```

## Main App Transcription Flow

```
RecordViewModel.transcribeSpeechTask()
  |
  +-- beginBackgroundTask("transcription")
  |   (no queue fallback - UI-dependent code)
  |
  +-- Transcribe audio
  +-- AI enhance text
  +-- Save to SwiftData
  +-- Spotlight indexing
  +-- Clipboard, haptics, etc.
  |
  +-- endBackgroundTask (via defer)
```

If the 30-second background time expires for the main app path, the transcription is interrupted. The audio file remains on disk and can be manually retranscribed by the user.

## Startup Recovery

On every app launch, `AppState.init()` runs recovery sequentially in a single Task (order matters to prevent duplicates):

1. **Queued items first** - `BackgroundTaskService.processQueue()` drains items with full metadata (modeId, timestamp). Uses peek-then-remove: items stay in queue until processing succeeds. Checks for existing Transcription records to prevent duplicates.
2. **Orphaned files second** - `WatchAudioProcessor.processOrphanedFiles()` scans `Documents/Audio/` for `watch-*.wav` files without matching Transcription records. This is the catch-all fallback for files that weren't in the queue.

## Registration

`BGTaskScheduler.register()` must be called during `application(_:didFinishLaunchingWithOptions:)` (Apple requirement).

1. `AppDelegate` calls `BackgroundTaskService.registerBGTaskHandler()`
2. The handler dispatches to `BackgroundTaskService.shared` (weak reference to the live instance)
3. By the time iOS delivers a `BGProcessingTask`, `AppState` is always initialized because the task is only scheduled from within the running app

## Configuration

### Info.plist

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>remote-notification</string>
    <string>processing</string>
</array>
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.antonnovoselov.VivaDicta.transcription-processing</string>
</array>
```

- `processing` background mode is required for `BGProcessingTask`
- `BGTaskSchedulerPermittedIdentifiers` lists allowed task identifiers
- `UIApplication.beginBackgroundTask` requires no Info.plist entry

## Key Files

| File | Role |
|------|------|
| `Services/BackgroundTaskService.swift` | Manages both background task mechanisms |
| `Services/BackgroundTaskQueue.swift` | Persistent work item queue (peek-then-remove) |
| `Services/PhoneWatchConnectivityService.swift` | Wraps Watch audio processing with background protection |
| `Services/WatchAudioProcessor.swift` | Headless transcription processor (used by queue) |
| `Views/RecordViewModel.swift` | Main app transcription with background protection |
| `AppDelegate.swift` | BGProcessingTask handler registration |
| `AppState.swift` | Service initialization and startup recovery |

## Debugging

Simulate BGProcessingTask in lldb:

```
# Launch the task
e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.antonnovoselov.VivaDicta.transcription-processing"]

# Simulate expiration
e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateExpirationForTaskWithIdentifier:@"com.antonnovoselov.VivaDicta.transcription-processing"]
```

**Note**: `BGProcessingTask` does not work in iOS Simulator - test on a physical device.
