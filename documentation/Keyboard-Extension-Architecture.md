# Keyboard Extension Architecture

## Overview

VivaDictaKeyboard is a custom keyboard extension that brings voice transcription and AI text processing directly into any text field on iOS. Rather than running its own audio stack, the extension delegates all recording and processing to the main VivaDicta app process via AppGroupCoordinator — the keyboard acts as the command interface and result receiver, while the main app does the heavy lifting. This split-process design is required by iOS extension constraints and enables on-device model warm-up, full audio session management, and access to API keys that extensions cannot hold independently.

The extension is built on top of KeyboardKit, which provides the standard iOS keyboard layout, haptic/audio feedback, and host application identification. VivaDicta replaces KeyboardKit's default toolbar with a custom SwiftUI view that surfaces the microphone button and mode selector.

## Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        VivaDictaKeyboard Extension Process                   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                     KeyboardViewController                          │    │
│  │                (UIInputViewController subclass via KeyboardKit)     │    │
│  │                                                                     │    │
│  │  viewDidLoad()                    viewWillSetupKeyboardView()       │    │
│  │  • Creates KeyboardDictationState  • Installs KeyboardCustomView    │    │
│  │  • Binds onTranscriptionReady      • Passes dictationState via env  │    │
│  │  • Configures KeyboardApp          • Configures haptic/sound prefs  │    │
│  │  • Calls dictationState.start()                                     │    │
│  │                                                                     │    │
│  │  handleTranscription(text)                                          │    │
│  │  • TextInsertionFormatter (if smartInsert enabled)                  │    │
│  │  • textDocumentProxy.insertText()                                   │    │
│  │  • AppGroupCoordinator.recordKeyboardSuccessfulUse()                │    │
│  │  • ClipboardManager.copyToClipboard() (if keepInClipboard enabled) │    │
│  └──────────────────────────┬──────────────────────────────────────────┘    │
│                             │ @Environment injection                         │
│  ┌──────────────────────────▼──────────────────────────────────────────┐    │
│  │                      KeyboardCustomView (SwiftUI)                   │    │
│  │                                                                     │    │
│  │  Switches on dictationState.uiState:                                │    │
│  │  ┌───────────┐  ┌───────────┐  ┌────────────┐  ┌───────────────┐   │    │
│  │  │  .notReady │  │  .ready   │  │ .recording │  │  .processing  │   │    │
│  │  │  .ready    │  │ ──────────│  │────────────│  │───────────────│   │    │
│  │  │            │  │ Standard  │  │ Recording  │  │ Processing    │   │    │
│  │  │ KeyboardView│  │ keyboard  │  │ StateView  │  │ StateView     │   │    │
│  │  │ + toolbar  │  │ + toolbar │  │            │  │               │   │    │
│  │  └───────────┘  └───────────┘  └────────────┘  └───────────────┘   │    │
│  │                                                                     │    │
│  │  FullAccessPromptView overlay (if Full Access missing)              │    │
│  └──────────────────────────┬──────────────────────────────────────────┘    │
│                             │ @Observable                                    │
│  ┌──────────────────────────▼──────────────────────────────────────────┐    │
│  │                   KeyboardDictationState (@Observable)              │    │
│  │                                                                     │    │
│  │  Computed: uiState  ←─  isRecording + isSessionActive +            │    │
│  │                          transcriptionStatus                        │    │
│  │                                                                     │    │
│  │  VivaModeManager ──► reads/writes App Group UserDefaults            │    │
│  │                                                                     │    │
│  │  Callbacks from AppGroupCoordinator:                                │    │
│  │  onRecordingStateChanged  onKeyboardSessionActivated                │    │
│  │  onTranscriptionCompleted onTranscriptionTranscribing               │    │
│  │  onTranscriptionEnhancing onTranscriptionError                      │    │
│  │  onAudioLevelUpdated      onTranscriptionCancelled                  │    │
│  └──────────────────────────┬──────────────────────────────────────────┘    │
│                             │                                                │
└─────────────────────────────┼──────────────────────────────────────────────┘
                              │ IPC boundary
          ┌───────────────────▼──────────────────────────────────┐
          │               AppGroupCoordinator (Singleton)         │
          │                                                        │
          │  Shared UserDefaults (group.com.antonnovoselov.        │
          │  VivaDicta): isRecording, transcriptionStatus,         │
          │  transcribedText, sessionExpiry, audioLevel, modes     │
          │                                                        │
          │  Darwin Notifications (CFNotificationCenter):          │
          │  startRecording / stopRecording / cancelRecording      │
          │  recordingStateChanged / transcriptionCompleted        │
          │  keyboardSessionActivated / audioLevelUpdated          │
          └───────────────────┬──────────────────────────────────┘
                              │
          ┌───────────────────▼──────────────────────────────────┐
          │                 Main App Process                      │
          │                                                       │
          │  PrewarmManager ── AVAudioSession management         │
          │  TranscriptionManager ── WhisperKit / Parakeet        │
          │  AIService ── cloud/on-device AI processing           │
          │  RecordViewModel ── orchestrates the full pipeline    │
          └───────────────────────────────────────────────────────┘
```

## UIInputViewController Lifecycle and SwiftUI Hosting

`KeyboardViewController` subclasses `KeyboardInputViewController` (provided by KeyboardKit, which itself extends `UIInputViewController`). The extension lifecycle follows two distinct phases:

**viewDidLoad** — runs once when iOS loads the extension process. The controller:
1. Creates a single `KeyboardDictationState` instance that lives for the extension's lifetime.
2. Registers the `onTranscriptionReady` closure, which is the final delivery point for transcribed text into the host app's text field.
3. Calls `dictationState.start()` to wire up all AppGroupCoordinator callbacks.
4. Calls `setup(for:)` with a `KeyboardApp` value that carries the app group ID and the `vivadicta://` deep-link scheme.
5. Reads haptic and sound preferences from shared UserDefaults and applies them to `state.feedbackContext`.

**viewWillSetupKeyboardView** — called each time the keyboard appears (including when the user switches back from another keyboard). The controller installs `KeyboardCustomView` as the root view via `setupKeyboardView`. The `dictationState` is injected as an `@Environment` value so every SwiftUI view in the hierarchy can observe it without explicit parameter passing.

The `deinit` calls `dictationState.stop()`, which clears all AppGroupCoordinator callbacks to prevent callbacks from firing on a deallocated state object.

SwiftUI views cannot be direct subviews of `UIInputViewController`; KeyboardKit bridges this via its own `setupKeyboardView` host. All keyboard UI is therefore pure SwiftUI, with the single UIKit anchor point being `KeyboardViewController` itself and `textDocumentProxy` for text insertion.

## Dictation State Machine

`KeyboardDictationState` is the central `@Observable` class that drives every view state transition. It holds three independent pieces of raw state and derives a single `UIState` enum from them:

```
isRecording         (Bool)   ──┐
isSessionActive     (Bool)   ──┼──► uiState (UIState)
transcriptionStatus (enum)   ──┘
```

### UIState derivation

```
isRecording == true                      → .recording
transcriptionStatus == .transcribing     → .processing
transcriptionStatus == .enhancing        → .processing
transcriptionStatus == .error            → .error
isSessionActive == true                  → .ready
isSessionActive == false                 → .notReady
```

### Full state sequence for a successful transcription

```
.notReady
    │  Main app prewarm session activated
    ▼
.ready
    │  User taps mic; requestStartRecording() sent
    ▼
.recording         (isRecording = true via onRecordingStateChanged)
    │  User taps stop; requestStopRecording() sent
    ▼
.processing / transcribing   (transcriptionStatus = .transcribing via onTranscriptionTranscribing)
    │
    ▼
.processing / enhancing      (transcriptionStatus = .enhancing via onTranscriptionEnhancing)
    │                         — only if AI processing is enabled in selected mode —
    ▼
onTranscriptionCompleted fires → text delivered to handleTranscription → inserted into host field
    │
    ▼
.ready                       (transcriptionStatus resets to .idle)
```

### Error and cancellation paths

- **Error**: `transcriptionStatus = .error` and `errorMessage` is set → `UIState` becomes `.error` → `ErrorStateView` is shown → auto-dismiss timer fires after 5 seconds or user taps Dismiss → state resets to `.idle`.
- **Cancel**: User taps the X in `RecordingStateView` → `requestCancelRecording()` → main app cancels → `onTranscriptionCancelled` fires → `transcriptionStatus` resets to `.idle` → returns to `.ready` or `.notReady`.
- **Session timeout**: If the keyboard session expires while recording, `isSessionActive` becomes `false`. A 1-second guard in `requestStartRecording` detects that `isRecording` never became `true` and sets `isSessionActive = false` defensively, reverting to `.notReady` to avoid a stuck UI.

### ProcessingStage sub-states

While `UIState` is `.processing`, `KeyboardCustomView` maps `transcriptionStatus` to a finer `ProcessingStage` enum to drive the animated icon and label in `ProcessingStateView`:

| transcriptionStatus | ProcessingStage    | Label             | Icon                     |
|---------------------|--------------------|-------------------|--------------------------|
| `.transcribing`     | `.transcribing`    | "Transcribing..."  | `pencil.and.scribble`    |
| `.enhancing`        | `.enhancingWithAI` | "AI Processing..." | `sparkles`               |
| `.completed`        | `.completed`       | "Completed"        | —                        |
| `.error`            | `.error(message)`  | error message      | —                        |

## AppGroup Coordination: Keyboard to Main App Communication

Because the keyboard extension and the main app run in separate processes, they cannot call each other directly. AppGroupCoordinator bridges this gap with two complementary mechanisms:

**Shared UserDefaults** (`group.com.antonnovoselov.VivaDicta`) — persistent storage readable and writable by both processes. Used for values that must survive process suspension: recording state, transcription status, transcribed text, session expiry timestamp, audio level, VivaMode list, selected mode name, and keyboard preferences.

**Darwin Notifications** (`CFNotificationCenter`) — fire-and-forget signals that cross process boundaries immediately. They carry no payload; the receiver reads any necessary data from shared UserDefaults after the notification triggers a callback. Used for time-sensitive commands: startRecording, stopRecording, cancelRecording, recordingStateChanged, transcriptionCompleted, keyboardSessionActivated, keyboardSessionExpired, audioLevelUpdated, transcriptionTranscribing, transcriptionEnhancing, transcriptionError, transcriptionCancelled, vivaModeChanged.

### Keyboard-initiated recording handshake

```
Keyboard (requestStartRecording)
    │
    ├── if useClipboardContext: setKeyboardClipboardContext(UIPasteboard.general.string)
    ├── Darwin notification "startRecording" ──────────────────────────► Main App
    │                                                                       │
    │                                                               PrewarmManager.start()
    │                                                               AVAudioSession activated
    │                                                               activateKeyboardSession(180s)
    │                                                                       │
    │◄─── Darwin: "keyboardSessionActivated" ◄──────────────────────────────┤
    │     isSessionActive = true → UIState becomes .ready                   │
    │                                                                       │
    │  User taps mic (requestStartRecording already sent, session is active)│
    │     isRecording = true  ◄──── Darwin: "recordingStateChanged" ◄───────┤
    │     UIState: .recording                                               │
```

### Transcription delivery handshake

```
Main App (transcription complete)
    │
    ├── shareTranscribedText(text)   → writes to UserDefaults "transcribedText"
    ├── updateTranscriptionStatus(.completed) → writes to UserDefaults
    └── Darwin: "transcriptionCompleted" ────────────────────────────────► Keyboard
                                                                              │
                                                              onTranscriptionCompleted fires
                                                              getAndConsumeTranscribedText()
                                                                              │
                                                              onTranscriptionReady(text)
                                                              textDocumentProxy.insertText()
```

The "consume" pattern (`getAndConsumeTranscribedText`, `getAndConsumeTranscriptionErrorMessage`) ensures that text is read exactly once and cleared from shared storage, preventing double-insertion if the extension process is relaunched.

### Clipboard context forwarding

When the selected VivaMode has `useClipboardContext` enabled, the keyboard can read the current clipboard before signaling the main app to start recording. `UIPasteboard.general` is accessible to the keyboard extension (with Full Access) but not to the background-running main app at the moment recording begins. The keyboard stores the text via `setKeyboardClipboardContext(_:)` in shared UserDefaults; the main app's `AIService` retrieves it via `getAndConsumeKeyboardClipboardContext()` when building the AI prompt.

## VivaModeManager: Keyboard-Scoped Mode Selection

`VivaModeManager` is an `@Observable` class owned by `KeyboardDictationState`. It reads the mode list and selected mode from the same App Group UserDefaults that the main app writes to, giving the keyboard a live view of all user-configured modes.

```
App Group UserDefaults
  "VivaModes"       (JSON-encoded [VivaMode]) ──► loadVivaModes()  → availableVivaModes
  "selectedVivaMode" (mode name string)       ──► loadSelectedMode() → selectedVivaMode
```

When the user changes the mode via `ModeCycleSelector`, `selectedVivaMode.didSet` writes the new name back to shared UserDefaults and posts a Darwin notification (`vivaModeChanged`). The main app observes this notification and calls `reloadSelectedModeFromExtension()` on `AIService` so that the next recording uses the correct provider and preset without requiring an app restart or manual sync.

`refreshVivaModes()` is called at `start()` time (every time the keyboard appears) to pick up any mode changes the user made in the main app since the extension was last active. Because extension processes can be terminated by iOS at any time, this ensures the keyboard always reflects the current configuration.

The `ModeCycleSelector` view supports both chevron taps and horizontal swipe gestures for fast mode cycling, with a wrapping index that loops from last back to first. `HapticManager.selectionChanged()` provides tactile confirmation of each transition.

## TextInsertionFormatter: Context-Aware Text Output

Before `textDocumentProxy.insertText()` is called, `TextInsertionFormatter` inspects the text surrounding the cursor position and adjusts the transcribed text to fit naturally into the existing content. This is only applied when `selectedVivaMode.isSmartInsertEnabled` is true.

The formatter reads two values from `UITextDocumentProxy`:
- `documentContextBeforeInput` — text immediately before the cursor (up to a system-defined limit)
- `documentContextAfterInput` — text immediately after the cursor

These are wrapped in an `InsertionContext` struct and passed through two independent transformations:

### Smart spacing

Decides whether to prepend or append a space character:

| Condition | Action |
|-----------|--------|
| cursor at field start | no space before |
| character before cursor is whitespace | no space before |
| character before cursor is letter, digit, or punctuation (`.!?,;:-`) | prepend space |
| character after cursor is non-whitespace, non-punctuation | append space |
| cursor at end of text | append space |

### Smart capitalization

Decides whether to force-uppercase or force-lowercase the first letter of the transcribed text:

| Condition | Action |
|-----------|--------|
| text before cursor is empty or whitespace-only | capitalize |
| last non-whitespace character before cursor is `.`, `!`, `?`, or `\n` | capitalize |
| first word of transcribed text is an acronym or proper noun (all uppercase) | preserve case |
| all other cases | lowercase first letter |

The formatter returns the adjusted string for immediate insertion. If the proxy returns `nil` for context (some text fields do not expose surrounding text), the formatter appends a trailing space and inserts as-is.

## Full Access Requirements and Permission Flow

iOS keyboard extensions can operate in two modes:

**Without Full Access** — the extension runs in a sandboxed mode. `UIPasteboard.general` is unavailable, network requests are blocked, and audio recording is not possible. The keyboard can still type characters, but all voice features are disabled.

**With Full Access** — clipboard access, network access, and inter-process communication via Darwin Notifications are all enabled. Required for all VivaDicta keyboard functionality.

`KeyboardViewController.hasFullAccess` (provided by `UIInputViewController`) reflects the current permission state. This boolean is checked in two places:

1. `KeyboardCustomView` passes `hasFullAccess` to `VivaDictaKeyboardToolbarView` as a plain value property (re-evaluated each time the view reloads).
2. `VivaDictaKeyboardToolbarView.handleMic()` checks `hasFullAccess` before taking any action. If `false`, it calls `onShowFullAccessPrompt()` which triggers `FullAccessPromptView` with a spring animation.

`FullAccessPromptView` opens `UIApplication.openSettingsURLString` which routes to the Settings app. The user must navigate to Settings > General > Keyboard > Keyboards > VivaDicta > Allow Full Access and enable the toggle. There is no programmatic way to trigger this grant from within the extension.

The prompt appears as a slide-up overlay covering the keyboard with a spring transition. The main keyboard content fades to opacity 0 behind it. The user can dismiss the prompt with the X button without leaving the keyboard.

## Audio Session Management Within Extension Constraints

The keyboard extension does not start an audio session itself. iOS extension memory and background process limits make running WhisperKit or Parakeet models inside a keyboard extension impractical — these models require hundreds of megabytes and extended CPU time that would exceed extension resource budgets.

Instead, the extension offloads recording to the main app process:

1. `requestStartRecording()` posts a Darwin notification.
2. The main app's `PrewarmManager` activates an `AVAudioSession` with category `.playAndRecord`, mode `.voiceChat`, and the appropriate background mode entitlement.
3. The main app records audio, runs transcription, and runs AI processing entirely within its own process.
4. The extension only receives the final text result via shared UserDefaults and a Darwin notification.

The extension does read `audioLevel` from shared UserDefaults (written by the main app at ~10Hz during recording) to animate a waveform visualization in `RecordingStateView`. This polling is driven by the `onAudioLevelUpdated` callback in `KeyboardDictationState`, which updates `currentAudioLevel` on the main queue.

The session has a 180-second timeout managed by `PrewarmManager`. If no recording starts within that window, the session is deactivated and `isSessionActive` becomes `false`, returning the keyboard UI to `.notReady`. While recording is active, the timeout is automatically extended.

## Host App Detection and Return-to-Host URL Scheme Flow

When the keyboard is in `.notReady` state (no active main app session) and the user taps the mic, the extension cannot start recording directly. Instead, it deep-links into the main app to initiate a "hot-mic" flow — the main app opens, begins recording immediately (bypassing the normal recording screen), and the text flows back to the original text field when done.

The URL scheme is `vivadicta://record-for-keyboard`. KeyboardKit's `hostApplicationBundleId` property (available on `KeyboardInputViewController`) identifies the app currently hosting the keyboard.

```swift
// From VivaDictaKeyboardToolbarView
var urlString = "vivadicta://record-for-keyboard"
if let hostId = controller?.hostApplicationBundleId {
    if let encodedHostId = hostId.addingPercentEncoding(
        withAllowedCharacters: .urlQueryAllowed) {
        urlString += "?hostId=\(encodedHostId)"
    }
}
openURL(URL(string: urlString)!)
```

The `hostId` query parameter carries the bundle identifier of the calling app (e.g., `com.apple.mobilenotes`, `com.apple.MobileSMS`). The main app receives this via its `onOpenURL` handler in the scene delegate, passes `hostId` to `RecordViewModel`, and after transcription completes, constructs a return URL to bring the user back to the originating app:

```
vivadicta://record-for-keyboard?hostId=com.apple.mobilenotes
    → main app opens, records, transcribes
    → text placed in clipboard or passed via AppGroup
    → return URL opens com.apple.mobilenotes
```

KeyboardKit's host detection is documented at https://docs.keyboardkit.com/documentation/keyboardkit/host-article. Bundle identifiers require percent-encoding before URL embedding because some identifiers (particularly enterprise apps) may contain characters outside the safe query character set.

## Key Files

| File | Target | Purpose |
|------|--------|---------|
| `VivaDictaKeyboard/KeyboardViewController.swift` | Keyboard Extension | `UIInputViewController` entry point; installs SwiftUI hierarchy, wires `onTranscriptionReady`, calls `textDocumentProxy.insertText()` |
| `VivaDictaKeyboard/KeyboardDictationState.swift` | Keyboard Extension | `@Observable` state machine; derives `UIState` from three raw state booleans; bridges AppGroupCoordinator callbacks to SwiftUI |
| `VivaDictaKeyboard/KeyboardCustomView.swift` | Keyboard Extension | Root SwiftUI view; switches between keyboard layout, `RecordingStateView`, `ProcessingStateView`, `ErrorStateView`, and `FullAccessPromptView` based on `UIState` |
| `VivaDictaKeyboard/TextInsertionFormatter.swift` | Keyboard Extension | Context-aware text formatter; reads surrounding cursor text from `UITextDocumentProxy` to apply smart spacing and capitalization |
| `VivaDictaKeyboard/Models/VivaModeManager.swift` | Keyboard Extension | `@Observable` mode manager; loads `[VivaMode]` from App Group UserDefaults; propagates keyboard-side mode changes back to main app via `AppGroupCoordinator.setSelectedVivaMode()` |
| `VivaDictaKeyboard/Views/RecordingStateView.swift` | Keyboard Extension | Full-screen recording UI; shows elapsed timer, cancel button, mode picker, and stop button |
| `VivaDictaKeyboard/Views/ProcessingStateView.swift` | Keyboard Extension | Animated processing UI; maps `ProcessingStage` to animated SF Symbol icons with mesh gradient mask |
| `VivaDictaKeyboard/Views/FullAccessPromptView.swift` | Keyboard Extension | Full Access onboarding overlay; opens Settings when Full Access is not granted |
| `VivaDicta/Shared/AppGroupCoordinator.swift` | Shared (main app + all extensions) | IPC backbone; manages Darwin Notifications and App Group UserDefaults for all cross-process communication |
| `VivaDictaKeyboard/VivaDictaKeyboard.entitlements` | Keyboard Extension | Declares `com.apple.security.application-groups` with `group.com.antonnovoselov.VivaDicta` |
