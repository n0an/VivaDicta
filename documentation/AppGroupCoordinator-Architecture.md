# AppGroupCoordinator Architecture Diagram

## Overview
AppGroupCoordinator is the central communication hub between the VivaDicta main app and its extensions (keyboard, widget, share, action), using App Groups (shared UserDefaults) and Darwin Notifications for real-time iOS-native communication.

## Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────────────────────────┐
│                                   iOS System Level                                   │
├──────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  ┌─────────────────────────┐                    ┌─────────────────────────────┐      │
│  │   MAIN APP (VivaDicta)   │                    │   KEYBOARD EXTENSION        │      │
│  │                          │                    │                             │      │
│  │  ┌────────────────────┐  │                    │  ┌──────────────────────┐   │      │
│  │  │   RecordViewModel   │  │                    │  │ KeyboardViewController│  │      │
│  │  └─────────┬──────────┘  │                    │  └──────────┬───────────┘  │      │
│  │            │              │                    │             │               │      │
│  │  ┌─────────▼──────────┐  │                    │  ┌──────────▼───────────┐   │      │
│  │  │  PrewarmManager    │  │                    │  │ KeyboardDictationState│  │      │
│  │  │                    │  │                    │  │                      │   │      │
│  │  │ • startPrewarm()   │  │                    │  │ • requestStart()     │   │      │
│  │  │ • isSessionActive  │  │                    │  │ • requestStop()      │   │      │
│  │  │ • 180s timeout     │  │                    │  │ • requestCancel()    │   │      │
│  │  └─────────┬──────────┘  │                    │  └──────────┬───────────┘  │      │
│  │            │              │                    │             │               │      │
│  └────────────┼──────────────┘                    └─────────────┼──────────────┘      │
│               │                                                 │                      │
│  ┌────────────┼──────────────┐  ┌───────────────┐  ┌───────────┼──────────────┐      │
│  │  WIDGET EXTENSION        │  │ SHARE EXT     │  │  ACTION EXTENSION        │      │
│  │  • ToggleSessionIntent   │  │ • Audio share │  │  • Text processing      │      │
│  │  • Live Activity         │  │ • Lang override│ │                          │      │
│  └────────────┼──────────────┘  └───────┬───────┘  └───────────┬──────────────┘      │
│               │                          │                      │                      │
│               ▼                          ▼                      ▼                      │
│  ┌───────────────────────────────────────────────────────────────────────────────┐    │
│  │                         AppGroupCoordinator (Singleton)                       │    │
│  │                                                                               │    │
│  │  ┌─────────────────────────────────────────────────────────────────────────┐  │    │
│  │  │                         Communication Channels                          │  │    │
│  │  │                                                                         │  │    │
│  │  │  1. Shared UserDefaults (App Group: group.com.antonnovoselov.VivaDicta) │  │    │
│  │  │     • Persistent state storage                                          │  │    │
│  │  │     • Cross-process data sharing                                        │  │    │
│  │  │                                                                         │  │    │
│  │  │  2. Darwin Notifications (CFNotificationCenter)                         │  │    │
│  │  │     • Real-time signaling                                               │  │    │
│  │  │     • No data payload (just triggers)                                   │  │    │
│  │  │                                                                         │  │    │
│  │  │  3. Shared File Container (SharedAudio directory)                       │  │    │
│  │  │     • Audio file exchange for Share Extension                            │  │    │
│  │  └─────────────────────────────────────────────────────────────────────────┘  │    │
│  │                                                                               │    │
│  │  ┌─────────────────────────────────────────────────────────────────────────┐  │    │
│  │  │                           State Management                              │  │    │
│  │  │                                                                         │  │    │
│  │  │  Recording State:        Session Management:      Transcription State:  │  │    │
│  │  │  • isRecording           • keyboardSessionActive  • transcriptionStatus │  │    │
│  │  │  • lastRecordingTimestamp • sessionExpiryTime     • transcribedText     │  │    │
│  │  │                                                   • errorMessage        │  │    │
│  │  │  Audio:                  Clipboard Context:       • audioLevel          │  │    │
│  │  │  • audioLevel (0.0-1.0)  • keyboardClipboardCtx                        │  │    │
│  │  │                                                                         │  │    │
│  │  │  VivaMode Settings:      Language Settings:       API Keys:             │  │    │
│  │  │  • selectedVivaModeKey   • selectedLanguageKey    • apiKeyTemplate      │  │    │
│  │  │  • vivaModesKey                                                         │  │    │
│  │  │                                                                         │  │    │
│  │  │  Keyboard Preferences:   Share Extension:         Success Tracking:     │  │    │
│  │  │  • smartFormattingOnPaste• pendingSharedAudioFile  • keyboardFirstUse   │  │    │
│  │  │  • keepTranscriptInClip  • pendingLanguageOverride                      │  │    │
│  │  │  • hapticFeedbackEnabled                                                │  │    │
│  │  │  • soundFeedbackEnabled  General:                                       │  │    │
│  │  │  • isVADEnabled          • isHapticsEnabled                             │  │    │
│  │  └─────────────────────────────────────────────────────────────────────────┘  │    │
│  │                                                                               │    │
│  │  ┌─────────────────────────────────────────────────────────────────────────┐  │    │
│  │  │                         Notification Handlers                           │  │    │
│  │  │                                                                         │  │    │
│  │  │  Main App → Keyboard:          Keyboard → Main App:                     │  │    │
│  │  │  • recordingStateChanged       • startRecording                         │  │    │
│  │  │  • transcriptionCompleted      • stopRecording                          │  │    │
│  │  │  • keyboardSessionActivated    • cancelRecording                        │  │    │
│  │  │  • keyboardSessionExpired      • pauseRecording                         │  │    │
│  │  │  • audioLevelUpdated           • resumeRecording                        │  │    │
│  │  │  • transcriptionTranscribing                                            │  │    │
│  │  │  • transcriptionEnhancing      Widget/Control → Main App:               │  │    │
│  │  │  • transcriptionError          • startRecordingFromControl              │  │    │
│  │  │  • transcriptionCancelled      • terminateSessionFromLiveActivity       │  │    │
│  │  │  • vivaModeChanged                                                      │  │    │
│  │  └─────────────────────────────────────────────────────────────────────────┘  │    │
│  └───────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                      │
└──────────────────────────────────────────────────────────────────────────────────────┘
```

## Sequence Diagram: Recording Flow with PrewarmManager

```
Keyboard Extension          AppGroupCoordinator           Main App            PrewarmManager
        │                           │                         │                      │
        │  User taps record button  │                         │                      │
        ├──────────────────────────►│                         │                      │
        │   requestStartRecording() │                         │                      │
        │                           │                         │                      │
        │                           ├──────────────────────►  │                      │
        │                           │  Darwin Notification    │                      │
        │                           │  "startRecording"       │                      │
        │                           │                         │                      │
        │                           │                         ├─────────────────────►│
        │                           │                         │ startPrewarmSession()│
        │                           │                         │                      │
        │                           │◄─────────────────────   │                      │
        │                           │ activateKeyboardSession │◄─────────────────────│
        │                           │    (180s timeout)       │   Session Active     │
        │                           │                         │                      │
        │◄──────────────────────────┤                         │                      │
        │  Session Active Signal    │                         │                      │
        │                           │                         │                      │
        │  [Recording happens...]   │                         │                      │
        │                           │                         │                      │
        │  User taps stop button    │                         │                      │
        ├──────────────────────────►│                         │                      │
        │   requestStopRecording()  │                         │                      │
        │                           │                         │                      │
        │                           ├──────────────────────►  │                      │
        │                           │  Darwin Notification    │                      │
        │                           │  "stopRecording"        │                      │
        │                           │                         │                      │
        │                           │                         ├─────────────────────►│
        │                           │                         │  stopCaptureAudio()  │
        │                           │                         │                      │
        │                           │                         │◄─────────────────────│
        │                           │                         │   Audio file ready   │
        │                           │                         │                      │
        │                           │◄─────────────────────  │                      │
        │                           │ updateTranscriptionStatus│                      │
        │                           │    (.transcribing)      │                      │
        │                           │                         │                      │
        │◄──────────────────────────┤                         │                      │
        │  Status: Transcribing     │                         │                      │
        │                           │                         │                      │
        │                           │                         │  [Transcription]     │
        │                           │                         │                      │
        │                           │◄─────────────────────  │                      │
        │                           │ updateTranscriptionStatus│                      │
        │                           │    (.enhancing)         │                      │
        │                           │                         │                      │
        │◄──────────────────────────┤                         │                      │
        │  Status: AI Processing    │                         │                      │
        │                           │                         │                      │
        │                           │                         │  [AI Processing]     │
        │                           │                         │                      │
        │                           │◄─────────────────────  │                      │
        │                           │  shareTranscribedText() │                      │
        │                           │                         │                      │
        │◄──────────────────────────┤                         │                      │
        │  Transcription Complete   │                         │                      │
        │                           │                         │                      │
        │                           │◄─────────────────────  │                      │
        │                           │ deactivateKeyboardSession│◄─────────────────────│
        │                           │                         │  Session Ended       │
        │                           │                         │                      │
```

## TranscriptionStatus Enum

The coordinator defines a pipeline status enum shared with extensions:

| Status | Raw Value | Description |
|--------|-----------|-------------|
| `.idle` | `"idle"` | No active transcription |
| `.recording` | `"recording"` | Audio recording in progress |
| `.transcribing` | `"transcribing"` | Speech-to-text processing |
| `.enhancing` | `"AI processing"` | AI text processing |
| `.completed` | `"completed"` | Text ready for consumption |
| `.error` | `"error"` | Error occurred |

## Key Components Explanation

### 1. **Communication Mechanisms**

#### Shared UserDefaults (App Group)
- **Purpose**: Persistent state storage accessible by all app targets and extensions
- **App Group ID**: `group.com.antonnovoselov.VivaDicta`
- **Data stored**:
  - Recording state (`isRecording`, `lastRecordingTimestamp`)
  - Transcribed text sharing (`transcribedText`)
  - User preferences (VivaMode via `selectedVivaModeKey`, language via `selectedLanguageKey`)
  - Session management (`keyboardSessionActive`, `keyboardSessionExpiryTime`)
  - Transcription status and errors (`transcriptionStatus`, `transcriptionErrorMessage`)
  - Audio level for visualization (`audioLevel`, 0.0–1.0)
  - Keyboard clipboard context (`keyboardClipboardContext`)
  - Keyboard preferences (`smartFormattingOnPaste`, `keepTranscriptInClipboard`, `isKeyboardHapticFeedbackEnabled`, `isKeyboardSoundFeedbackEnabled`)
  - VAD setting (`IsVADEnabled`)
  - General haptics (`isHapticsEnabled`)
  - API keys (`apiKeyTemplate`)
  - Keyboard success tracking (`keyboardFirstSuccessfulUse`)
  - Share Extension pending audio (`pendingSharedAudioFileName`, `pendingLanguageOverride`)

#### Darwin Notifications (CFNotificationCenter)
- **Purpose**: Real-time signaling between processes
- **Characteristics**:
  - Immediate delivery
  - No data payload (just triggers)
  - Directly trigger callbacks without intermediate flag checking
  - Used for: startRecording, stopRecording, cancelRecording, pauseRecording, resumeRecording, state changes, transcription status updates, startRecordingFromControl, terminateSessionFromLiveActivity, vivaModeChanged

#### Shared File Container
- **Purpose**: Audio file exchange between Share Extension and main app
- **Location**: `SharedAudio/` directory inside the App Group container
- **Flow**: Share Extension saves audio file → stores filename in UserDefaults → main app reads and transcribes on next launch

### 2. **PrewarmManager Integration**

The PrewarmManager works with AppGroupCoordinator to maintain background audio sessions:

1. **Session Activation**:
   - When keyboard requests recording, main app starts prewarm session
   - PrewarmManager keeps app alive for 180 seconds in background
   - AppGroupCoordinator notifies keyboard that session is active

2. **Session Lifecycle**:
   - `activateKeyboardSession(timeoutSeconds: 180)`: Marks session as active
   - `isKeyboardSessionActive`: Checks if session is still valid (auto-extends if recording is active)
   - `deactivateKeyboardSession()`: Cleans up when recording completes
   - `refreshKeyboardSessionExpiry(timeoutSeconds:)`: Extends the session timeout without deactivating

3. **Timeout Management**:
   - Session has configurable timeout (typically 180 seconds)
   - If recording is active when timeout expires, session extends automatically
   - Expired sessions are cleaned up to prevent stale state
   - Stale recording state (>30s old with no active session) is auto-cleared

### 3. **State Synchronization**

#### Recording Flow:
1. Keyboard extension calls `requestStartRecording()`
2. AppGroupCoordinator posts Darwin notification "startRecording"
3. Main app receives notification and triggers `onStartRecordingRequested` callback
4. RecordViewModel starts PrewarmManager session
5. AppGroupCoordinator updates session state in shared UserDefaults
6. Keyboard monitors session state and shows recording UI

#### Transcription Flow:
1. Recording stops via `requestStopRecording()`
2. Main app processes audio file
3. Status updates: `.transcribing` → `.enhancing` → `.completed`
4. Transcribed text shared via `shareTranscribedText()`
5. Keyboard retrieves text via `getAndConsumeTranscribedText()`

#### Widget/Control Center Recording:
1. Widget or Control Center calls `requestStartRecordingFromControl()`
2. Main app receives via `onStartRecordingFromControl` callback
3. Live Activity can terminate a session via `requestTerminateSessionFromLiveActivity()`

### 4. **VivaMode Management**

```
Keyboard Extension                AppGroupCoordinator              Main App
       │                                 │                            │
       │  User selects VivaMode          │                            │
       ├────────────────────────────────►│                            │
       │  setSelectedVivaMode(name)      │                            │
       │                                 │                            │
       │                                 ├───────────────────────────►│
       │                                 │  Save to UserDefaults      │
       │                                 │  (selectedVivaModeKey)     │
       │                                 │  + Darwin: vivaModeChanged │
       │                                 │                            │
       │                                 │                            │
       │                                 │◄───────────────────────────│
       │                                 │  On recording start:       │
       │                                 │  reloadSelectedModeFromKeyboard()
       │                                 │                            │
```

### 5. **Keyboard Clipboard Context**

The keyboard extension can capture clipboard text and share it with the main app for AI context:
- `setKeyboardClipboardContext(_:)`: Stores clipboard text from keyboard
- `getAndConsumeKeyboardClipboardContext()`: Main app retrieves and clears the context

### 6. **Share Extension Audio Handling**

Share Extension flow for receiving audio files from other apps:
1. Share Extension saves audio file to `sharedAudioDirectory` (inside App Group container)
2. Stores filename via `setPendingSharedAudioFileName(_:)` and optional language via `setPendingLanguageOverride(_:)`
3. On main app launch, checks `hasPendingSharedAudio` and retrieves via `getAndConsumePendingSharedAudioFileName()` / `getAndConsumePendingLanguageOverride()`

### 7. **Keyboard Success Tracking**

Tracks first successful keyboard transcription for deferred App Store rating request:
- `recordKeyboardSuccessfulUse()`: Called from keyboard after first successful text insertion
- `consumeKeyboardSuccessFlag()`: Called from main app on launch; returns `true` once, then clears the flag

### 8. **Keyboard Preferences**

Settings shared between main app and keyboard extension:
- `isSmartFormattingOnPasteEnabled`: Smart spacing/capitalization when inserting text (default: `true`)
- `isKeepTranscriptInClipboardEnabled`: Copy transcription to clipboard after inserting (default: `false`)
- `isKeyboardHapticFeedbackEnabled`: Haptic feedback for key presses (default: `true`)
- `isKeyboardSoundFeedbackEnabled`: Sound feedback for key presses (default: `true`)

### 9. **Error Handling & Cleanup**

- **Stale State Prevention**: `resetSessionStateOnAppLaunch()` clears all session data on fresh start
- **Stale Recording Detection**: `isRecording` auto-clears if state is >30s old with no active session
- **Timeout Protection**: Sessions expire after timeout to prevent deadlocks
- **Error Recovery**: Error messages are consumed after reading (`getAndConsumeTranscriptionErrorMessage()`)
- **Proper Cleanup**: `deinit` removes all Darwin notification observers

### 10. **Key Methods**

#### For Keyboard Extension:
- `requestStartRecording()`: Initiate recording from keyboard
- `requestStopRecording()`: Stop recording from keyboard
- `requestCancelRecording()`: Cancel recording from keyboard
- `setSelectedVivaMode()`: Update selected AI mode
- `setKeyboardClipboardContext(_:)`: Share clipboard text for AI context
- `recordKeyboardSuccessfulUse()`: Track first successful use

#### For Widget / Control Center:
- `requestStartRecordingFromControl()`: Start recording from widget/control
- `requestTerminateSessionFromLiveActivity()`: Terminate session from Live Activity

#### For Main App:
- `updateRecordingState()`: Update recording status
- `updateTranscriptionStatus()`: Update transcription progress
- `updateTranscriptionError()`: Set error message and error status
- `shareTranscribedText()`: Share transcribed text with keyboard
- `activateKeyboardSession()`: Start keyboard session with timeout
- `refreshKeyboardSessionExpiry()`: Extend session timeout
- `updateAudioLevel()`: Share audio level for visualization
- `getAndConsumeKeyboardClipboardContext()`: Retrieve keyboard clipboard context
- `consumeKeyboardSuccessFlag()`: Check and clear keyboard success flag

#### For Share Extension:
- `setPendingSharedAudioFileName()`: Store pending audio filename
- `setPendingLanguageOverride()`: Store optional language for pending audio
- `sharedAudioDirectory`: URL for shared audio file storage

#### Lifecycle Management:
- `resetSessionStateOnAppLaunch()`: Clear all stale state on app start
- `deactivateKeyboardSession()`: End keyboard session
- `getAndConsumeTranscribedText()`: Retrieve and clear transcribed text
- `getAndConsumeTranscriptionErrorMessage()`: Retrieve and clear error message

#### All Callbacks (Main App):
- `onStartRecordingRequested`: Keyboard requests recording start
- `onStopRecordingRequested`: Keyboard requests recording stop
- `onCancelRecordingRequested`: Keyboard requests recording cancel
- `onPauseRecordingRequested`: Keyboard requests recording pause
- `onResumeRecordingRequested`: Keyboard requests recording resume
- `onKeyboardSessionActivated`: Keyboard session became active
- `onKeyboardSessionExpired`: Keyboard session expired
- `onTranscriptionCompleted`: Transcription completed with text
- `onTranscriptionTranscribing`: Transcription started
- `onTranscriptionEnhancing`: AI processing started
- `onTranscriptionError`: Error occurred
- `onTranscriptionErrorMessage`: Error message available
- `onTranscriptionCancelled`: Transcription was cancelled
- `onAudioLevelUpdated`: Audio level changed
- `onRecordingStateChanged`: Recording state changed
- `onStartRecordingFromControl`: Widget/Control Center requests recording
- `onTerminateSessionFromLiveActivity`: Live Activity requests session termination
- `onVivaModeChanged`: VivaMode was changed from keyboard

## Benefits of This Architecture

1. **Process Isolation**: App and extensions run in separate processes
2. **Real-time Communication**: Darwin notifications provide immediate updates
3. **State Persistence**: Shared UserDefaults survive process termination
4. **Background Operation**: PrewarmManager keeps app alive for recording
5. **Clean Separation**: Each component has clear responsibilities
6. **Error Resilience**: Multiple mechanisms to prevent and recover from stale state
7. **Multi-Extension Support**: Same coordinator serves keyboard, widget, share, and action extensions
