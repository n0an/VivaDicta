# AppGroupCoordinator Architecture Diagram

## Overview
AppGroupCoordinator is the central communication hub between the VivaDicta main app and its keyboard extension, using App Groups (shared UserDefaults) and Darwin Notifications for real-time iOS-native communication.

## Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────────────────────────┐
│                                   iOS System Level                                   │
├──────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  ┌─────────────────────────┐                    ┌─────────────────────────────┐    │
│  │   MAIN APP (VivaDicta)   │                    │   KEYBOARD EXTENSION        │    │
│  │                          │                    │                             │    │
│  │  ┌────────────────────┐  │                    │  ┌──────────────────────┐  │    │
│  │  │   RecordViewModel   │  │                    │  │ KeyboardViewController│  │    │
│  │  └─────────┬──────────┘  │                    │  └──────────┬───────────┘  │    │
│  │            │              │                    │             │               │    │
│  │  ┌─────────▼──────────┐  │                    │  ┌──────────▼───────────┐  │    │
│  │  │  PrewarmManager    │  │                    │  │ KeyboardDictationState│  │    │
│  │  │                    │  │                    │  │                      │  │    │
│  │  │ • startPrewarm()   │  │                    │  │ • requestStart()     │  │    │
│  │  │ • isSessionActive  │  │                    │  │ • requestStop()      │  │    │
│  │  │ • 180s timeout     │  │                    │  │ • requestCancel()    │  │    │
│  │  └─────────┬──────────┘  │                    │  └──────────┬───────────┘  │    │
│  │            │              │                    │             │               │    │
│  └────────────┼──────────────┘                    └─────────────┼──────────────┘    │
│               │                                                 │                    │
│               ▼                                                 ▼                    │
│  ┌───────────────────────────────────────────────────────────────────────────────┐  │
│  │                         AppGroupCoordinator (Singleton)                       │  │
│  │                                                                               │  │
│  │  ┌─────────────────────────────────────────────────────────────────────────┐ │  │
│  │  │                         Communication Channels                          │ │  │
│  │  │                                                                         │ │  │
│  │  │  1. Shared UserDefaults (App Group: group.com.antonnovoselov.VivaDicta)│ │  │
│  │  │     • Persistent state storage                                         │ │  │
│  │  │     • Cross-process data sharing                                       │ │  │
│  │  │                                                                         │ │  │
│  │  │  2. Darwin Notifications (CFNotificationCenter)                        │ │  │
│  │  │     • Real-time signaling                                              │ │  │
│  │  │     • No data payload (just triggers)                                  │ │  │
│  │  └─────────────────────────────────────────────────────────────────────────┘ │  │
│  │                                                                               │  │
│  │  ┌─────────────────────────────────────────────────────────────────────────┐ │  │
│  │  │                           State Management                              │ │  │
│  │  │                                                                         │ │  │
│  │  │  Recording State:        Session Management:      Transcription State:  │ │  │
│  │  │  • isRecording           • keyboardSessionActive  • transcriptionStatus │ │  │
│  │  │  • shouldStartRecording  • sessionExpiryTime      • transcribedText     │ │  │
│  │  │  • shouldStopRecording   • lastRecordingTimestamp • errorMessage        │ │  │
│  │  │  • shouldCancelRecording                          • audioLevel          │ │  │
│  │  │                                                                         │ │  │
│  │  │  FlowMode Management:    Language Settings:       API Keys:             │ │  │
│  │  │  • selectedAIModeKey     • selectedLanguageKey    • apiKeyTemplate     │ │  │
│  │  │  • aiEnhanceModesKey     • transcriptionPrompt                         │ │  │
│  │  └─────────────────────────────────────────────────────────────────────────┘ │  │
│  │                                                                               │  │
│  │  ┌─────────────────────────────────────────────────────────────────────────┐ │  │
│  │  │                         Notification Handlers                           │ │  │
│  │  │                                                                         │ │  │
│  │  │  Main App → Keyboard:          Keyboard → Main App:                    │ │  │
│  │  │  • recordingStateChanged       • startRecording                        │ │  │
│  │  │  • transcriptionCompleted      • stopRecording                         │ │  │
│  │  │  • keyboardSessionActivated    • cancelRecording                       │ │  │
│  │  │  • keyboardSessionExpired      • pauseRecording                        │ │  │
│  │  │  • audioLevelUpdated           • resumeRecording                       │ │  │
│  │  │  • transcriptionError                                                  │ │  │
│  │  └─────────────────────────────────────────────────────────────────────────┘ │  │
│  └───────────────────────────────────────────────────────────────────────────────┘  │
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

## Key Components Explanation

### 1. **Communication Mechanisms**

#### Shared UserDefaults (App Group)
- **Purpose**: Persistent state storage accessible by both app and extension
- **App Group ID**: `group.com.antonnovoselov.VivaDicta`
- **Use Cases**:
  - Storing recording state
  - Sharing transcribed text
  - Saving user preferences (FlowMode, language)
  - Session management

#### Darwin Notifications (CFNotificationCenter)
- **Purpose**: Real-time signaling between processes
- **Characteristics**:
  - Immediate delivery
  - No data payload
  - Used as triggers to check shared state

### 2. **PrewarmManager Integration**

The PrewarmManager works with AppGroupCoordinator to maintain background audio sessions:

1. **Session Activation**:
   - When keyboard requests recording, main app starts prewarm session
   - PrewarmManager keeps app alive for 180 seconds in background
   - AppGroupCoordinator notifies keyboard that session is active

2. **Session Lifecycle**:
   - `activateKeyboardSession(timeoutSeconds: 180)`: Marks session as active
   - `isKeyboardSessionActive`: Checks if session is still valid
   - `deactivateKeyboardSession()`: Cleans up when recording completes

3. **Timeout Management**:
   - Session has 180-second timeout
   - If recording is active, session extends automatically
   - Expired sessions are cleaned up to prevent stale state

### 3. **State Synchronization**

#### Recording Flow:
1. Keyboard extension calls `requestStartRecording()`
2. AppGroupCoordinator posts Darwin notification
3. Main app receives notification and starts PrewarmManager
4. PrewarmManager activates audio session
5. AppGroupCoordinator updates session state
6. Keyboard receives confirmation and shows recording UI

#### Transcription Flow:
1. Recording stops via `requestStopRecording()`
2. Main app processes audio file
3. Status updates: `.transcribing` → `.enhancing` → `.completed`
4. Transcribed text shared via `shareTranscribedText()`
5. Keyboard retrieves text via `getAndConsumeTranscribedText()`

### 4. **FlowMode Management**

```
Keyboard Extension                AppGroupCoordinator              Main App
       │                                 │                            │
       │  User selects FlowMode          │                            │
       ├────────────────────────────────►│                            │
       │  setSelectedFlowMode(name)      │                            │
       │                                 │                            │
       │                                 ├───────────────────────────►│
       │                                 │  Save to UserDefaults      │
       │                                 │  (selectedAIModeKey)       │
       │                                 │                            │
       │                                 │                            │
       │                                 │◄───────────────────────────│
       │                                 │  On recording start:       │
       │                                 │  reloadSelectedModeFromKeyboard()
       │                                 │                            │
```

### 5. **Error Handling & Cleanup**

- **Stale State Prevention**: `resetSessionStateOnAppLaunch()` clears old data
- **Timeout Protection**: Sessions expire after timeout to prevent deadlocks
- **Error Recovery**: Error messages are consumed after reading
- **Proper Cleanup**: `deinit` handlers clear observers and callbacks

### 6. **Key Methods**

#### For Keyboard Extension:
- `requestStartRecording()`: Initiate recording from keyboard
- `requestStopRecording()`: Stop recording from keyboard
- `requestCancelRecording()`: Cancel recording from keyboard
- `setSelectedFlowMode()`: Update selected AI mode

#### For Main App:
- `updateRecordingState()`: Update recording status
- `updateTranscriptionStatus()`: Update transcription progress
- `shareTranscribedText()`: Share transcribed text with keyboard
- `activateKeyboardSession()`: Start keyboard session with timeout
- `updateAudioLevel()`: Share audio level for visualization

#### Lifecycle Management:
- `resetSessionStateOnAppLaunch()`: Clear stale state on app start
- `deactivateKeyboardSession()`: End keyboard session
- `getAndConsumeTranscribedText()`: Retrieve and clear transcribed text

## Benefits of This Architecture

1. **Process Isolation**: App and extension run in separate processes
2. **Real-time Communication**: Darwin notifications provide immediate updates
3. **State Persistence**: Shared UserDefaults survive process termination
4. **Background Operation**: PrewarmManager keeps app alive for recording
5. **Clean Separation**: Each component has clear responsibilities
6. **Error Resilience**: Multiple mechanisms to prevent and recover from errors