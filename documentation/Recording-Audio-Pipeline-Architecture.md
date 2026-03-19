# Recording & Audio Pipeline Architecture

## Overview

The recording pipeline handles the complete lifecycle of voice capture in VivaDicta, from microphone input to audio file ready for transcription. It supports two recording paths: normal (direct AVAudioRecorder) and keyboard prewarm (continuous AVAudioEngine with hot-switching).

## Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                           RecordViewModel (@MainActor)                       │
│                                                                              │
│  State Machine:  idle → recording → transcribing → enhancing → idle         │
│                                 ↘                           ↗               │
│                                   → error → idle                            │
│                                                                              │
│  ┌──────────────┐    ┌───────────────────┐    ┌────────────────────┐        │
│  │ startCapture  │    │  stopCapture       │    │ cancelProcessing   │        │
│  │ Audio()       │    │  Audio()           │    │ ()                 │        │
│  └──────┬───────┘    └────────┬──────────┘    └────────┬───────────┘        │
│         │                      │                        │                    │
│         ▼                      ▼                        ▼                    │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                     Dual Recording Path Selection                   │    │
│  │                                                                     │    │
│  │  if prewarmManager.isSessionActive:                                │    │
│  │    → Keyboard path (AVAudioEngine via AudioPrewarmManager)         │    │
│  │  else:                                                              │    │
│  │    → Normal path (AVAudioRecorder, 16kHz mono PCM)                 │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                     Post-Recording Pipeline                         │    │
│  │                                                                     │    │
│  │  1. Move recording.wav → <UUID>.wav (prevent overwrite)            │    │
│  │  2. Detect sample rate (keyboard = 48kHz)                          │    │
│  │  3. Downsample to 16kHz mono if needed (AVAudioConverter)          │    │
│  │  4. TranscriptionManager.transcribe(audioURL:)                     │    │
│  │  5. AIService.enhance(text:) if configured                         │    │
│  │  6. Save Transcription + TranscriptionVariation (dual-write)       │    │
│  │  7. Index to Spotlight + Siri Activity                             │    │
│  │  8. Share text to keyboard via AppGroupCoordinator                 │    │
│  │  9. Auto-copy to clipboard if enabled                              │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────────────┘
```

## AudioPrewarmManager (Singleton)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                         AudioPrewarmManager                                  │
│                                                                              │
│  Purpose: Keep audio engine running continuously for keyboard extension      │
│  latency reduction. Switches between discarding buffers (armed) and          │
│  writing to file (capturing).                                                │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                        AVAudioEngine                                │    │
│  │                                                                     │    │
│  │  InputNode ──(installTap)──► AudioCaptureContext ──► File/Discard  │    │
│  │              bufferSize:1024        │                                │    │
│  │              runs on audio thread   │                                │    │
│  │                                     ▼                               │    │
│  │                              Audio Level Calc                       │    │
│  │                              (RMS → 0.0-1.0)                       │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  Session Lifecycle:                                                          │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────────────┐      │
│  │ Keyboard  │    │ Engine   │    │ Real     │    │ Real capture     │      │
│  │ deeplink  │───►│ starts   │───►│ capture  │───►│ stops            │      │
│  │ activates │    │ (armed)  │    │ starts   │    │ (engine keeps    │      │
│  │ session   │    │ discards │    │ writes   │    │  running)        │      │
│  └──────────┘    │ buffers  │    │ to file  │    └────────┬─────────┘      │
│                   └──────────┘    └──────────┘             │                 │
│                                                            ▼                 │
│                                              ┌──────────────────────┐       │
│                                              │ Processing complete  │       │
│                                              │ → rescheduleTimeout()│       │
│                                              │ → back to armed      │       │
│                                              └──────────────────────┘       │
│                                                                              │
│  Timeout Management:                                                         │
│  • Default: 180s (configurable via UserDefaults)                            │
│  • Timer invalidated during real capture                                    │
│  • Timer NOT restarted after stopRealCapture (deferred during processing)   │
│  • rescheduleSessionTimeout() called after transcription+enhancement done   │
│  • If timeout fires → endSession() → engine stops, keyboard notified        │
└──────────────────────────────────────────────────────────────────────────────┘
```

## AudioCaptureContext (Thread-Safe)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  AudioCaptureContext (nonisolated, @unchecked Sendable)                      │
│                                                                              │
│  Thread-safe bridge between audio thread and main thread.                   │
│  Uses NSLock for atomic state transitions.                                  │
│                                                                              │
│  Properties (all lock-protected):                                           │
│  • _isCapturing: Bool        — whether to write buffers to file             │
│  • _audioFile: AVAudioFile?  — target file for writing                      │
│  • _currentAudioLevel: Float — latest RMS level                             │
│                                                                              │
│  Key Method:                                                                 │
│  writeBufferIfCapturing(buffer, updateLevel:)                               │
│    1. Calculate RMS audio level from PCM buffer (float32 or int16)          │
│    2. Call updateLevel callback (posts to @MainActor)                       │
│    3. Lock → check isCapturing → write buffer to file → unlock              │
│                                                                              │
│  Audio Level Algorithm:                                                      │
│    RMS = sqrt(sum(sample²) / frameLength)                                   │
│    dB = 20 * log10(RMS)                                                     │
│    normalized = clamp(0, 1, 1 - abs(dB / 50))                              │
│    Range: -50dB → 0.0, 0dB → 1.0                                           │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Sequence Diagram: Normal Recording Flow

```
User                RecordViewModel         AVAudioRecorder       TranscriptionManager    AIService
  │                       │                       │                       │                   │
  │  Tap record button    │                       │                       │                   │
  ├──────────────────────►│                       │                       │                   │
  │                       │                       │                       │                   │
  │                       │  setupAudioSession()  │                       │                   │
  │                       │  (playAndRecord,      │                       │                   │
  │                       │   request permission)  │                       │                   │
  │                       │                       │                       │                   │
  │                       │  captureClipboardCtx  │                       │                   │
  │                       │  state → .recording   │                       │                   │
  │                       │  HapticManager.medium  │                       │                   │
  │                       │                       │                       │                   │
  │                       ├──────────────────────►│                       │                   │
  │                       │  record(16kHz mono)   │                       │                   │
  │                       │                       │                       │                   │
  │                       │  Timer(0.2s) ─────────│──► audioPower update  │                   │
  │                       │                       │    + AppGroupCoord    │                   │
  │                       │                       │      .updateAudioLevel│                   │
  │                       │                       │                       │                   │
  │  Tap stop button      │                       │                       │                   │
  ├──────────────────────►│                       │                       │                   │
  │                       │  stop + move file     │                       │                   │
  │                       │  state → .transcribing│                       │                   │
  │                       │                       │                       │                   │
  │                       ├──────────────────────────────────────────────►│                   │
  │                       │                       │  transcribe(audioURL) │                   │
  │                       │                       │                       │                   │
  │                       │◄──────────────────────────────────────────────│                   │
  │                       │                       │  transcribedText      │                   │
  │                       │                       │                       │                   │
  │                       │  state → .enhancing   │                       │                   │
  │                       ├──────────────────────────────────────────────────────────────────►│
  │                       │                       │                       │  enhance(text)    │
  │                       │                       │                       │                   │
  │                       │◄──────────────────────────────────────────────────────────────────│
  │                       │                       │                       │  enhancedText     │
  │                       │                       │                       │                   │
  │                       │  Save Transcription + TranscriptionVariation  │                   │
  │                       │  Index Spotlight                              │                   │
  │                       │  Share to keyboard                           │                   │
  │                       │  Auto-copy to clipboard                      │                   │
  │                       │  state → .idle        │                       │                   │
  │                       │  HapticManager.heartbeat                     │                   │
```

## Sequence Diagram: Keyboard Prewarm Recording Flow

```
Keyboard Deeplink    AudioPrewarmManager      RecordViewModel         AppGroupCoordinator
      │                      │                       │                       │
      │  Open VivaDicta      │                       │                       │
      │  via deeplink        │                       │                       │
      ├─────────────────────►│                       │                       │
      │                      │                       │                       │
      │                      │  startPrewarmSession()│                       │
      │                      │  Configure audio sess │                       │
      │                      │  Start AVAudioEngine  │                       │
      │                      │  Install tap (discard) │                       │
      │                      │  Schedule timeout      │                       │
      │                      │                       │                       │
      │                      │                       │  activateKeyboard     │
      │                      │                       ├──────────────────────►│
      │                      │                       │  Session(180s)        │
      │                      │                       │                       │
      │                      │  [Engine running,     │                       │
      │                      │   discarding buffers] │                       │
      │                      │                       │                       │
      │  Darwin: startRec    │                       │                       │
      ├─────────────────────────────────────────────►│                       │
      │                      │                       │  startCaptureAudio()  │
      │                      │                       │                       │
      │                      │  startRealCapture(url)│                       │
      │                      │◄──────────────────────│                       │
      │                      │  Invalidate timeout   │                       │
      │                      │  Set audioFile + flag │                       │
      │                      │  [Now writing to disk]│                       │
      │                      │                       │                       │
      │  Darwin: stopRec     │                       │                       │
      ├─────────────────────────────────────────────►│                       │
      │                      │                       │  stopCaptureAudio()   │
      │                      │                       │                       │
      │                      │  stopRealCapture()    │                       │
      │                      │◄──────────────────────│                       │
      │                      │  Clear audioFile+flag │                       │
      │                      │  [Engine still running│                       │
      │                      │   timeout deferred]   │                       │
      │                      │                       │                       │
      │                      │                       │  [Transcribe + AI]    │
      │                      │                       │                       │
      │                      │  rescheduleTimeout()  │                       │
      │                      │◄──────────────────────│                       │
      │                      │  Reset timer          │                       │
      │                      │  Refresh keyboard sess│                       │
      │                      │  [Back to armed mode] │                       │
```

## Smart Cancel Behavior

```
cancelProcessing() behavior depends on current state:

┌─────────────────┬─────────────────────────────────────────────────────────┐
│ Current State   │ Behavior                                                │
├─────────────────┼─────────────────────────────────────────────────────────┤
│ .recording      │ Cancel recording. No data saved. Audio file deleted.   │
│                 │ Uses cancelTranscribe() internally.                     │
├─────────────────┼─────────────────────────────────────────────────────────┤
│ .transcribing   │ Cancel transcription. No data saved.                   │
│                 │ Task cancelled, pendingTranscription cleared.           │
├─────────────────┼─────────────────────────────────────────────────────────┤
│ .enhancing      │ Save transcription WITHOUT enhancement.                │
│                 │ pendingTranscription data used to create Transcription  │
│                 │ record with text only (enhancedText = nil).            │
│                 │ Spotlight indexed, shared to keyboard, clipboard copy.  │
└─────────────────┴─────────────────────────────────────────────────────────┘
```

## Audio Format Details

| Path | Sample Rate | Channels | Format | Bit Depth |
|------|-------------|----------|--------|-----------|
| Normal (AVAudioRecorder) | 16,000 Hz | 1 (mono) | Linear PCM | 16-bit int |
| Keyboard (AVAudioEngine) | Device native (48kHz typical) | Device native | Linear PCM | Float32 or Int16 |
| After downsampling | 16,000 Hz | 1 (mono) | Linear PCM | 16-bit int |

## Downsampling Logic

Triggered when detected sample rate > 16kHz (keyboard recordings are typically 48kHz):

1. Open source file, read processing format
2. Create target format: 16kHz, mono, PCM Int16
3. Create AVAudioConverter with max quality
4. Read entire input into buffer
5. Calculate output frame count: `inputFrames * (16000 / sourceSampleRate)`
6. Convert and write to `<name>.16k.wav`
7. Verify output > 1KB, delete original if successful
8. Space savings: ~67% for 48kHz → 16kHz

## Key Integration Points

- **AppGroupCoordinator**: Recording state, audio level, transcription status shared with keyboard
- **TranscriptionManager**: Receives audio URL, returns transcribed text
- **AIService**: Receives transcribed text, returns enhanced text
- **HapticManager**: Feedback at recording start (medium), enhancement start (light), completion (heartbeat), error
- **ClipboardManager**: Auto-copy if `isAutoCopyAfterRecordingEnabled`
- **RateAppManager**: Request review after successful transcription
- **Spotlight**: Index new transcription via `CSSearchableItem`
- **Siri**: Donate user activity for predictions
