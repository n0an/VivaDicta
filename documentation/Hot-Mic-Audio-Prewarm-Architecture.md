# Hot Mic / Audio Prewarm Architecture

## Overview

The Hot Mic system solves a fundamental iOS extension constraint: keyboard extensions cannot access the microphone. When a user taps the mic button in the VivaDicta keyboard extension, a deeplink opens the main app, which starts an `AVAudioEngine` session and immediately returns the user to their original app. By the time the user is back in their host app and taps the mic button again, the audio session in the main app is already warm and recording can begin with sub-100ms latency.

The core technique is `AVAudioEngine.installTap(onBus:)`. Unlike `AVAudioRecorder`, which holds an audio session only while actively recording, an `AVAudioEngine` with an installed tap keeps the audio session active continuously. iOS will not suspend a process that holds an active audio session, so the main app stays alive in the background even after the user returns to their host app.

The system has two phases on the engine:

- **Armed** — The engine is running, the tap is installed, buffers are computed but immediately discarded. The audio session is active and the app stays alive.
- **Capturing** — A real recording is in progress. The same tap writes every incoming buffer to an `AVAudioFile` on disk.

Switching from armed to capturing is atomic: `AudioCaptureContext.isCapturing` is set to `true` and an `AVAudioFile` destination is assigned under an `NSLock`. No engine restart, no permission dialog, no audio gap.

## Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                         Hot Mic System Overview                              │
│                                                                              │
│  Keyboard Extension              Main App (background)                       │
│  (no mic access)                 (mic session active)                        │
│                                                                              │
│  ┌──────────────────┐            ┌────────────────────────────────────────┐  │
│  │  VivaDictaKeyboard│            │  AudioPrewarmManager (singleton)       │  │
│  │                  │            │                                        │  │
│  │  uiState:        │            │  AVAudioEngine                         │  │
│  │  .notReady ──────┼────────►  │  InputNode──(tap)──►AudioCaptureCtx   │  │
│  │                  │  deeplink  │                       │  isCapturing?  │  │
│  │  (mic tapped)    │            │                       ├─ false: discard│  │
│  │                  │◄───────── │  activateKeyboard     └─ true: → file  │  │
│  │  uiState:        │  session   │  Session()                             │  │
│  │  .ready          │            │                                        │  │
│  │                  │            │  expiryTimer (default: 180s)           │  │
│  │  (mic tapped     │            │  → endSession() on timeout             │  │
│  │   again)         │            └────────────────────────────────────────┘  │
│  │                  │                                                         │
│  │  Darwin notif    │──────────────────────────────────────────────────────► │
│  │  startRecording  │            RecordViewModel.startCaptureAudio()         │
│  └──────────────────┘            → prewarmManager.startRealCapture(url)      │
│                                                                              │
│  Latency comparison:                                                         │
│  Cold start:  ~500-1500ms  (setup session + get permission + engine start)  │
│  Hot Mic:     <100ms       (only: create AVAudioFile + flip isCapturing)    │
└──────────────────────────────────────────────────────────────────────────────┘
```

## AudioPrewarmManager

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                         AudioPrewarmManager (@Observable)                    │
│                                                                              │
│  Singleton. Owns the AVAudioEngine and manages the full session lifecycle.  │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                      Session States                                 │    │
│  │                                                                     │    │
│  │  ┌──────────┐  startPrewarmSession()  ┌───────────────────────┐    │    │
│  │  │  Stopped  │────────────────────────►│  Armed                │    │    │
│  │  │  (default)│                        │  (engine running,     │    │    │
│  │  └──────────┘                        │   buffers discarded)  │    │    │
│  │                                       └──────────┬────────────┘    │    │
│  │                                                  │                  │    │
│  │                            startRealCapture(url) │                  │    │
│  │                                                  ▼                  │    │
│  │                                       ┌──────────────────────┐     │    │
│  │                                       │  Capturing           │     │    │
│  │                                       │  (engine running,    │     │    │
│  │                                       │   buffers → file)    │     │    │
│  │                                       └──────────┬───────────┘     │    │
│  │                                                  │                  │    │
│  │                               stopRealCapture()  │                  │    │
│  │                                                  ▼                  │    │
│  │                                       ┌──────────────────────┐     │    │
│  │                                       │  Armed               │     │    │
│  │                                       │  (timeout deferred   │     │    │
│  │                                       │   until processing   │     │    │
│  │                                       │   complete)          │     │    │
│  │                                       └──────────┬───────────┘     │    │
│  │                                                  │                  │    │
│  │                       rescheduleSessionTimeout() │                  │    │
│  │                                                  ▼                  │    │
│  │                                       ┌──────────────────────┐     │    │
│  │  endSession() / timeout ◄─────────────│  Armed (fresh timer) │     │    │
│  │  ────────────────────────             └──────────────────────┘     │    │
│  │  engine.stop()                                                      │    │
│  │  AVAudioSession.setActive(false)                                    │    │
│  │  AppGroupCoordinator.deactivateKeyboardSession()                    │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  Key Properties:                                                             │
│  • audioSessionTimeout: Int    — configurable, default 180s (UserDefaults) │
│  • isSessionActive: Bool       — engine.isRunning && within timeout OR      │
│                                  captureContext.isCapturing                  │
│  • isSessionActiveObservable   — @Observable mirror of isSessionActive      │
│  • currentAudioLevel: Float    — live RMS level (0.0-1.0) for UI           │
│  • timeoutRemaining: TimeInterval — seconds until session expires           │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Audio Session Configuration

When `startPrewarmSession()` is called, the `AVAudioSession` is configured before the engine starts:

| Setting | Value | Reason |
|---------|-------|--------|
| Category | `.playAndRecord` | Enables microphone input; required to hold session in background |
| Mode | `.default` | General recording without voice processing optimizations |
| Options | `.mixWithOthers` | Does not interrupt music playback during prewarm |
| Options | `.allowBluetoothHFP` | Supports Bluetooth headset microphones |
| Options | `.defaultToSpeaker` | Routes playback to speaker when not using headphones |
| Haptics | `setAllowHapticsAndSystemSoundsDuringRecording(true)` | Allows haptic feedback while session is active |

The `.mixWithOthers` option is critical during the armed phase: users expect their music or podcasts to continue playing while the keyboard session is waiting for their recording request. When real capture begins, audio mixing continues because the category and options do not change between armed and capturing phases.

### startDummyRecording() — The Core Mechanism

The engine tap is installed via a `nonisolated` free function dispatched onto a background queue. This avoids inheriting any actor isolation context from the calling `@Observable` class, which would otherwise cause a Swift 6 concurrency violation since `AVAudioEngine.installTap` is not actor-isolated.

```
startDummyRecording():
1. Create AVAudioEngine
2. Get inputNode and its native outputFormat(forBus: 0)
3. Create AudioCaptureContext (thread-safe capture controller)
4. Dispatch to global(qos: .userInitiated):
   installInputTapNonisolated(inputNode, format, captureContext)
   → inputNode.installTap(onBus: 0, bufferSize: 1024, format: ...) { buffer, _ in
       captureContext.writeBufferIfCapturing(buffer, updateLevel:)
     }
5. await continuation.resume() (tap installed)
6. audioEngine.start()
```

The tap callback runs on AVAudioEngine's private audio thread at every 1024-frame interval (approximately 23ms at 44.1kHz, 21ms at 48kHz). It must not block.

### Timeout Management

The session expires after `audioSessionTimeout` seconds of inactivity (default: 180 seconds). The timer is managed carefully to avoid terminating a session during processing:

| Event | Timer Behavior |
|-------|----------------|
| `startPrewarmSession()` | Timer scheduled for `audioSessionTimeout` |
| `extendSession()` (deeplink, session already active) | Timer invalidated and rescheduled from now |
| `startRealCapture()` | Timer **invalidated** — no expiry during recording |
| `stopRealCapture()` | Timer **not restarted** — processing is in flight |
| `rescheduleSessionTimeout()` | Timer restarted after transcription + AI processing |
| Timer fires | `endSession()` called, engine stopped, keyboard notified |

This design prevents the audio session from expiring while the app is actively transcribing or running AI processing after a recording ends. `rescheduleSessionTimeout()` is the explicit signal that the full pipeline (record → transcribe → AI process) is complete and the session can safely idle again.

## AudioCaptureContext

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  AudioCaptureContext (nonisolated, @unchecked Sendable)                      │
│                                                                              │
│  Thread-safe bridge between the audio thread and the Swift concurrency       │
│  system. Uses NSLock for all state transitions.                             │
│                                                                              │
│  Properties (all NSLock-protected):                                         │
│  • _isCapturing: Bool       — gate: only write buffers when true            │
│  • _audioFile: AVAudioFile? — destination file set before isCapturing=true  │
│  • _currentAudioLevel: Float — latest RMS power reading                     │
│                                                                              │
│  writeBufferIfCapturing(_:updateLevel:)  [called on audio thread, ~21ms]   │
│    1. calculateAudioLevel(buffer)        (outside lock, no blocking)        │
│    2. updateLevel(level) callback        (schedules Task to @MainActor)     │
│    3. lock.lock()                                                            │
│    4. _currentAudioLevel = level                                            │
│    5. guard _isCapturing, let file = _audioFile else { return }             │
│    6. file.write(from: buffer)                                              │
│    7. lock.unlock()                                                          │
│                                                                              │
│  Atomicity guarantee:                                                        │
│  When startRealCapture() assigns both _audioFile and _isCapturing under     │
│  separate lock acquisitions, the audio thread either sees both set or       │
│  neither. A partially-configured capture state is not possible because      │
│  _audioFile is assigned first and _isCapturing is set last.                 │
│                                                                              │
│  Audio Level Algorithm:                                                      │
│    sum = Σ(sample²)  for each frame in buffer                               │
│    RMS = sqrt(sum / frameLength)                                            │
│    dB  = 20 × log10(RMS)                                                   │
│    normalized = clamp(0, 1, 1 − |dB / 50|)                                 │
│    Effective range: −50 dB (silence) → 0.0, 0 dB (full scale) → 1.0       │
│                                                                              │
│  Supports both float32 (AVAudioEngine default) and int16 PCM formats.      │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Keyboard Extension Integration

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                     Full Keyboard → Hot Mic Flow                             │
│                                                                              │
│  VivaDictaKeyboard                   VivaDicta (main app)                   │
│                                                                              │
│  1. Keyboard opens, KeyboardDictationState.start()                          │
│     isSessionActive = AppGroupCoordinator.isKeyboardSessionActive           │
│     → false (no prewarm)                                                    │
│     uiState = .notReady → mic button shown in gray                         │
│                                                                              │
│  2. User taps mic (uiState == .notReady)                                    │
│     openURL("vivadicta://record-for-keyboard?hostId=<bundleId>")            │
│     → Main app opens in foreground                                          │
│                                                                              │
│  3. VivaDictaApp.handleDeepLink(_:)                                         │
│     a. appState.startLiveActivity()                                         │
│     b. AudioPrewarmManager.shared.startPrewarmSession()  ← await           │
│        - Configure AVAudioSession (.playAndRecord)                          │
│        - Install tap on AVAudioEngine.inputNode                             │
│        - Start AVAudioEngine  ← app now holds active audio session         │
│        - Schedule 180s expiry timer                                         │
│     c. AppGroupCoordinator.activateKeyboardSession(timeoutSeconds: 180)     │
│        - Writes keyboardSessionActive=true to App Group UserDefaults        │
│        - Posts Darwin notification: keyboardSessionActivated                │
│     d. attemptReturnToHost(hostId:)                                         │
│        - vm.startCaptureAudio()  ← recording begins immediately             │
│        - UIApplication.open(hostAppURL)  ← user returned to host app       │
│                                                                              │
│  4. Darwin notification received by KeyboardDictationState                  │
│     onKeyboardSessionActivated → isSessionActive = true                     │
│     uiState = .ready → mic button turns orange                             │
│                                                                              │
│     [If host app has no registered URL scheme, recording starts anyway      │
│      and a toast prompts the user to switch back manually.]                 │
│                                                                              │
│  5. Back in host app, user taps mic (uiState == .ready)                    │
│     (recording is already running; user taps again to stop)                 │
│     dictationState.requestStopRecording()                                   │
│     AppGroupCoordinator.requestStopRecording()                              │
│     Darwin notification → RecordViewModel.stopCaptureAudio()               │
│                                                                              │
│  6. RecordViewModel.stopCaptureAudio()                                      │
│     prewarmManager.stopRealCapture()  ← file flushed, engine keeps running │
│     [transcribe → AI process]                                               │
│     prewarmManager.rescheduleSessionTimeout()                               │
│     AppGroupCoordinator.shareTranscribedText(text)                         │
│     → Darwin: transcriptionCompleted                                        │
│                                                                              │
│  7. KeyboardDictationState.onTranscriptionCompleted                         │
│     onTranscriptionReady?(transcription)                                    │
│     → KeyboardViewController pastes text into host app's text field        │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Keyboard UI State Machine

`KeyboardDictationState.uiState` derives from three sources and drives mic button appearance:

| uiState | Condition | Mic Button |
|---------|-----------|------------|
| `.notReady` | `!isSessionActive` (no prewarm) | Gray — opens main app on tap |
| `.ready` | `isSessionActive && !isRecording` | Orange — sends start recording |
| `.recording` | `isRecording == true` | Red — sends stop recording |
| `.processing` | `transcriptionStatus == .transcribing` or `.enhancing` | Spinner |
| `.error` | `transcriptionStatus == .error` | Orange — clears error on tap |

The keyboard never directly controls microphone access. It only reads state from App Group UserDefaults and sends Darwin notification commands to the main app.

## RecordViewModel Integration

`RecordViewModel` selects its recording path at the moment `startCaptureAudio()` is called:

```
startCaptureAudio()
    │
    ├── prewarmManager.isSessionActive == true
    │   (keyboard flow — engine already running)
    │   │
    │   ├── captureURL = <documents>/recording.wav
    │   ├── prewarmManager.startRealCapture(to: captureURL)
    │   │   → audioFile created, isCapturing = true
    │   │   → expiryTimer invalidated
    │   │
    │   └── animationTimer reading prewarmManager.currentAudioLevel every 0.2s
    │
    └── prewarmManager.isSessionActive == false
        (normal flow — set up fresh audio session)
        │
        ├── setupAudioSession() → request mic permission
        ├── AVAudioRecorder(url: captureURL, settings: 16kHz mono PCM Int16)
        └── animationTimer reading audioRecorder.averagePower every 0.2s
```

`stopCaptureAudio()` follows the same branch logic. In prewarm mode, it calls `prewarmManager.stopRealCapture()` instead of `audioRecorder.stop()`. A 50ms `Task.sleep(for:)` follows to allow the audio thread to flush the final buffers before the file is moved and read by the transcription pipeline.

After the full pipeline completes, `rescheduleSessionTimeout()` is called from three separate code paths in `RecordViewModel`:

- Normal success path (AI processing or transcription-only)
- Cancel-while-enhancing path (transcription saved without AI output)
- Error recovery path

This ensures the session timer is always reset after any terminal state is reached, regardless of which code path ran.

## Session Recovery

If the audio engine unexpectedly stops while a recording was active (e.g., audio route interruption), `stopRealCapture()` detects the inconsistency and attempts to restart the prewarm session:

```swift
guard audioEngine?.isRunning == true else {
    // Unexpected engine stop: recover by restarting prewarm
    Task {
        try await startPrewarmSession()
    }
    return
}
```

On recovery, the keyboard session expiry is refreshed via `AppGroupCoordinator.refreshKeyboardSessionExpiry(timeoutSeconds:)` so the keyboard UI does not incorrectly revert to `.notReady`.

## Session Termination

The session ends through one of four paths:

| Path | Trigger | Cleanup |
|------|---------|---------|
| Timeout | `expiryTimer` fires after `audioSessionTimeout` | `endSession()` |
| Live Activity | User taps "End" in Dynamic Island | `AudioPrewarmManager.shared.endSession()` |
| App launch | Next cold start | `AppGroupCoordinator.resetSessionStateOnAppLaunch()` clears stale App Group state; `AudioPrewarmManager` starts fresh |
| Manual | Settings toggle or programmatic call | `AudioPrewarmManager.shared.endSession()` |

`endSession()` always deactivates the keyboard session via `AppGroupCoordinator.deactivateKeyboardSession()`, which posts the `keyboardSessionExpired` Darwin notification. This causes the keyboard's `uiState` to revert to `.notReady` and the mic button to go gray.

## Performance Characteristics

| Metric | Cold Start | Hot Mic |
|--------|-----------|---------|
| Time to first audio buffer | ~500–1500ms | <100ms |
| Audio session setup | Required | Already active |
| Engine start | Required | Already running |
| Microphone permission dialog | May appear | Never (already granted) |
| File creation overhead | Included in above | ~5ms |

The hot mic path's latency is bounded only by the time required to create an `AVAudioFile` at the target URL and write the capture flag — both operations complete in single-digit milliseconds on any device supported by the app.

## Audio Format

The AVAudioEngine uses the device's native hardware format for its tap. On most iOS devices this is 48kHz stereo float32 PCM. This format is incompatible with the 16kHz mono int16 PCM that on-device transcription models (WhisperKit, Parakeet) expect.

After `stopCaptureAudio()`, `RecordViewModel` detects the sample rate and downsamples when necessary:

```
sampleRate > 16000Hz detected?
    │
    └── YES: downsampleTo16kHzMono(inputURL:, outputURL: "<name>.16k.wav")
             using AVAudioConverter with .max quality
             → delete original (saves ~67% disk space for 48kHz source)
```

The file settings written by `startRealCapture()` match the engine's actual format exactly (`AVLinearPCMIsFloatKey: true` for float32, `AVLinearPCMBitDepthKey: 32`) to prevent any sample rate or format mismatch errors from `AVAudioFile`.

## Key Files

| File | Role |
|------|------|
| `VivaDicta/Services/AudioPrewarmManager.swift` | Core prewarm engine: session lifecycle, `AVAudioEngine` management, `AudioCaptureContext` |
| `VivaDicta/Shared/AppGroupCoordinator.swift` | Cross-process communication: Darwin notifications, App Group UserDefaults, keyboard session activation/expiry |
| `VivaDicta/Views/RecordViewModel.swift` | Recording path selection; calls `startRealCapture`, `stopRealCapture`, `rescheduleSessionTimeout` |
| `VivaDicta/VivaDictaApp.swift` | Deeplink handler (`vivadicta://record-for-keyboard`); orchestrates prewarm start, keyboard session activation, return-to-host flow |
| `VivaDictaKeyboard/KeyboardViewController.swift` | Keyboard mic button; opens main app via `openURL` when `uiState == .notReady` |
| `VivaDictaKeyboard/KeyboardDictationState.swift` | Keyboard-side state machine; derives `uiState` from `isSessionActive`, `isRecording`, and `transcriptionStatus` |
