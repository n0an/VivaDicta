# Deep Linking & URL Routing Architecture

## Overview

VivaDicta uses URL-based routing as the primary mechanism for coordinating navigation and recording actions across its main app, keyboard extension, share extension, and widgets. The system combines three technologies: a custom `vivadicta://` URL scheme for inter-process communication, universal links for web-to-app routing, and `NSUserActivity` for Handoff and Spotlight continuation. Navigation within the main app is managed by `Router` (a `@Observable` `NavigationStack` wrapper) and by flag properties on `AppState`.

## Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        Incoming Navigation Sources                           │
│                                                                              │
│  Widgets             Share Extension      Keyboard Extension   Quick Actions │
│  (WidgetKit)         (ShareViewController) (KeyboardVC)        (SceneDelegate)│
│       │                     │                    │                   │       │
│       │ startRecordFromWidget│ vivadicta://       │ vivadicta://      │ short-│
│       │ (non-scheme URL)     │ transcribe-shared  │ record-for-       │ cut   │
│       │                     │                    │ keyboard          │ item  │
│       └──────────┬──────────┴──────────┬─────────┘                   │       │
│                  │                     │                              │       │
│         .onOpenURL { url }    SceneDelegate.handleShortcutItem()     │       │
│                  │                     │                              │       │
│           handleDeepLink()    appState.shouldStartRecording = true ◄─┘       │
│                  │                                                            │
│   ┌──────────────┼────────────────────────────────────────────────┐          │
│   │              │         handleDeepLink() Router                │          │
│   │              │                                                │          │
│   │  startRecordFromWidget ──► AppState.shouldStartRecording      │          │
│   │  vivadicta://transcribe-shared ──► AppState.shouldTranscribe  │          │
│   │  vivadicta://record-for-keyboard ──► prewarm + host return    │          │
│   │  vivadicta.com (universal link) ──► opens main screen         │          │
│   │                                                               │          │
│   └───────────────────────────────────────────────────────────────┘          │
│                                                                              │
│  Spotlight / Siri / Handoff                                                  │
│  .onContinueUserActivity("com.antonnovoselov.VivaDicta.viewTranscription")   │
│       │                                                                      │
│       └──► handleTranscriptionActivity() ──► Router.select(transcription:)  │
└──────────────────────────────────────────────────────────────────────────────┘
```

## URL Scheme Routes (`vivadicta://`)

All inbound URL scheme traffic enters through the `.onOpenURL` modifier registered on `MainView` inside `VivaDictaApp.body`. The handler calls `handleDeepLink(_:)` which pattern-matches the full URL string.

```
vivadicta://                      (registered URL scheme — base)
    │
    ├── record-for-keyboard?hostId=<bundleId>
    │       Opened by: keyboard extension mic button (notReady state)
    │       Action:    start audio prewarm → activate keyboard session
    │                  → attemptReturnToHost(hostId:) → start recording
    │
    ├── transcribe-shared
    │       Opened by: Share Extension after copying audio to app group
    │       Action:    AppState.shouldTranscribeSharedAudio = true
    │
    └── (unrecognised path)
            Action:    warning log, no navigation
```

The `startRecordFromWidget` URL used by widgets is intentionally **not** a `vivadicta://` scheme URL. The widget passes it as a non-standard URL string directly through `widgetURL(URL(string:))`. The `handleDeepLink(_:)` function matches it with a plain string equality check (`url.absoluteString == "startRecordFromWidget"`) and sets `AppState.shouldStartRecording = true`.

### Universal Links

Universal link hosts `vivadicta.com` and `www.vivadicta.com` are detected inside `handleDeepLink(_:)` by inspecting `url.host`. The current implementation logs the path and returns early, opening the app to its default main screen. This provides a future extension point for web-to-transcription-detail routing.

## Keyboard Extension Routing

The keyboard extension uses a two-phase URL scheme protocol to hand off a recording session to the main app and return the user to the originating app when the session is ready.

### Phase 1: Keyboard opens VivaDicta

When the keyboard's mic button is tapped and the Hot Mic session is not yet active (`uiState == .notReady`), `VivaDictaKeyboardToolbarView` constructs a URL and calls `openURL`:

```
vivadicta://record-for-keyboard?hostId=<percent-encoded bundle ID>
```

The `hostId` is obtained from `KeyboardInputViewController.hostApplicationBundleId` (provided by KeyboardKit). It identifies which app the keyboard is currently serving so the main app can return the user there after starting recording.

### Phase 2: VivaDicta prepares and returns to host

`handleDeepLink(_:)` processes `vivadicta://record-for-keyboard` as follows:

```
1. AppState.startLiveActivity()              — show Dynamic Island recording indicator
2. AudioPrewarmManager.startPrewarmSession() — prepare audio session (async, awaited)
3. AppGroupCoordinator.activateKeyboardSession(timeoutSeconds:)
                                             — signal keyboard that hot mic is ready
4. attemptReturnToHost(hostId:)              — look up URL scheme for hostId
    ├── scheme found + canOpenURL:
    │       RecordViewModel.startCaptureAudio()
    │       (wait 0.2 s)
    │       UIApplication.shared.open(hostURL)
    └── scheme not found OR canOpenURL fails:
            start recording if model is selected
            AppState.showKeyboardFlowToast = true
```

### Host App URL Scheme Mapping

`getURLSchemeForBundleId(_:)` contains a static dictionary mapping bundle identifiers to URL schemes for ~40 commonly used apps. When a host app is not in the dictionary, the function returns `nil` and the keyboard flow toast is shown as a fallback. Unknown hosts are logged to Firebase Analytics under the `unrecognized_host_app` event so new entries can be added over time.

Known apps with no public URL scheme (and therefore excluded from analytics) are listed in `knownNoSchemeHosts`:
- `com.apple.SafariViewService` — SFSafariViewController in-app browser
- `com.apple.springboard` — iOS home screen
- Several AI apps without public schemes (Grok, GPChat, Saner AI, Venice AI, Snappy Notes)

### AppGroupCoordinator: Keyboard Session Lifecycle

Once the main app starts recording, it communicates all state changes back to the keyboard extension via Darwin notifications and App Group UserDefaults. The keyboard reads these to drive its UI state machine (`KeyboardDictationState.UIState`).

```
Main App                              Keyboard Extension
    │                                         │
    │── activateKeyboardSession() ────────────► isSessionActive = true
    │── updateRecordingState(true) ──────────► isRecording = true
    │── updateTranscriptionStatus(.transcribing)► status = .transcribing
    │── updateTranscriptionStatus(.enhancing) ─► status = .enhancing
    │── shareTranscribedText(text) ──────────► transcriptionCompleted callback
    │                                         │── textDocumentProxy.insertText()
    │── deactivateKeyboardSession() ─────────► isSessionActive = false
```

All notifications use the Darwin notify center (`CFNotificationCenterGetDarwinNotifyCenter()`) and are delivered across process boundaries without requiring the receiving process to be running. Shared state (recording flag, status string, transcribed text, audio levels) is persisted in `UserDefaults(suiteName: "group.com.antonnovoselov.VivaDicta")`.

## Widget Deep Links

All four supported widget families use an identical `widgetURL`:

```
URL(string: "startRecordFromWidget")
```

- `.systemSmall` — home screen widget
- `.accessoryCircular` — lock screen circular widget
- `.accessoryRectangular` — lock screen rectangular widget
- `.accessoryInline` — lock screen inline widget

When tapped, the system opens VivaDicta and delivers the URL to `onOpenURL`. The handler sets `AppState.shouldStartRecording = true`, which the `RecordView` observes to begin recording immediately. There are no query parameters; widget taps always trigger an immediate recording start with the currently selected mode.

## Share Extension Routing

The Share Extension (`ShareViewController`) handles audio files shared from other apps. It writes the audio to the shared app group container and then opens the main app with a URL scheme trigger.

```
Share Extension                        Main App
    │                                      │
    │ 1. Copy audio to                     │
    │    SharedAudio/<UUID>.<ext>           │
    │                                      │
    │ 2. Write filename to                 │
    │    UserDefaults (app group)          │
    │    kPendingSharedAudioFileName       │
    │                                      │
    │ 3. open(vivadicta://transcribe-shared)│
    │                                      │
    │                          onOpenURL ──►│
    │                 AppState.shouldTranscribeSharedAudio = true
    │                                      │
    │ 4. completeRequest()                 │ MainView observes flag,
    │                                      │ reads pending filename via
    │                                      │ AppGroupCoordinator
    │                                      │ .getAndConsumePendingSharedAudioFileName()
```

The share extension cannot directly access `UIApplication.shared` in extension contexts. Instead it traverses the UIResponder chain (`var responder: UIResponder? = self`) to find the `UIApplication` instance and call `open(_:)` on it.

Optional language override (for models that accept a language parameter) is stored separately as `kPendingLanguageOverride` and consumed by the main app together with the audio filename.

## Quick Actions (Home Screen Shortcuts)

Long-pressing the VivaDicta icon on the home screen presents a context menu with a single quick action. The action set is registered when the app goes to background:

```swift
// Called in .onChange(of: scenePhase) when transitioning to .background
func updateShortcutItems() {
    let recordAction = UIApplicationShortcutItem(
        type: QuickActionType.startRecord.rawValue,   // "startRecord"
        localizedTitle: "Start recording",
        localizedSubtitle: "Turn your voice into text",
        icon: UIApplicationShortcutIcon(systemImageName: "microphone.circle.fill")
    )
    UIApplication.shared.shortcutItems = [recordAction]
}
```

`SceneDelegate` handles delivery in two cases:

| Scenario | Method called | Behaviour |
|---|---|---|
| App already running | `windowScene(_:performActionFor:completionHandler:)` | Calls `handleShortcutItem(_:)` immediately |
| Cold launch | `scene(_:willConnectTo:options:)` | Stores item as `deferredQuickAction`; `handleShortcutItem(_:)` is called from `sceneDidBecomeActive(_:)` |

`handleShortcutItem(_:)` sets `SceneDelegate.appState?.shouldStartRecording = true`. `AppState` is passed to `SceneDelegate` via a `static weak var appState: AppState?` set in `MainView.onAppear`.

## Navigation State Management

### Router

`Router` is a `@Observable @MainActor` class that wraps the `NavigationStack` path:

```swift
@Observable @MainActor class Router {
    var path = [Transcription]()      // drives NavigationStack
    func select(transcription:)       // push a single transcription detail
    func popToRoot()                  // clear path
}
```

`Router` is injected into the environment at the `MainView` level and consumed by any view that needs to programmatically navigate to a transcription. It is also registered with `AppDependencyManager` so it can be resolved by App Intents without direct dependency injection.

### AppState Navigation Flags

`AppState` holds boolean flags that views observe to trigger transient navigation actions. Flags are set by external entry points (URL handlers, quick actions, SceneDelegate) and cleared by the view that handles them.

| Flag | Set by | Consumed by | Effect |
|---|---|---|---|
| `shouldStartRecording` | Widget URL, Quick Action | `RecordView` | Immediately begin recording |
| `shouldTranscribeSharedAudio` | Share Extension URL | `MainView` | Load and transcribe pending shared audio |
| `shouldNavigateToModels` | Settings flows | `SettingsView` | Push to model selection screen |
| `shouldNavigateToModeSettings` | Settings flows | `SettingsView` | Push to current mode settings |
| `showKeyboardFlowToast` | `attemptReturnToHost()` fallback | `MainView` | Show toast guiding user to switch back manually |

## NSUserActivity, Handoff, and Spotlight Continuation

### Activity Type

All transcription-related Handoff and Spotlight continuation uses a single activity type:

```
com.antonnovoselov.VivaDicta.viewTranscription
```

### Creating Activities

`AppState.userActivity(for:)` creates an `NSUserActivity` for a given `Transcription`:

```
activity.activityType   = "com.antonnovoselov.VivaDicta.viewTranscription"
activity.userInfo       = ["id": transcription.id.uuidString]
activity.persistentIdentifier = transcription.id.uuidString
activity.isEligibleForSearch  = true
activity.isEligibleForPrediction = true
activity.contentAttributeSet  = transcription.searchableAttributes()
```

The `contentAttributeSet` reuses the same `CSSearchableItemAttributeSet` used for Spotlight indexing, ensuring consistent metadata between Handoff and search.

### Continuing Activities

VivaDicta registers a continuation handler in `VivaDictaApp.body`:

```swift
.onContinueUserActivity("com.antonnovoselov.VivaDicta.viewTranscription") { userActivity in
    try? handleTranscriptionActivity(userActivity)
}
```

`handleTranscriptionActivity(_:)` extracts the UUID from `userActivity.userInfo["id"]`, fetches the `Transcription` from `DataController`, and calls `Router.select(transcription:)` to push the detail view.

### Spotlight Indexing

`AppState` provides four methods for managing the Spotlight index:

| Method | Trigger |
|---|---|
| `indexTranscriptionToSpotlight(_:)` | New transcription created; variation generated |
| `updateTranscriptionInSpotlight(_:)` | Transcription content updated |
| `removeTranscriptionFromSpotlight(_:)` | Transcription deleted |
| `indexTranscriptionEntityToSpotlight(_:)` | Used from detached tasks to avoid actor isolation |

`TranscriptionEntity` conforms to `IndexedEntity` (`AppIntents`) and defines `searchableAttributes` that populate:
- `title` — first 100 characters of enhanced or original text
- `contentDescription` — full text (original + enhanced, newline-separated)
- `keywords` — preset name, transcription model name, AI model name
- `duration`, `contentCreationDate` — audio metadata

Spotlight results, when tapped, resume via the `NSUserActivity` continuation path described above.

## Key Files

| File | Role |
|---|---|
| `VivaDicta/VivaDictaApp.swift` | `onOpenURL` handler, `handleDeepLink()`, `getURLSchemeForBundleId()`, `handleTranscriptionActivity()`, `updateShortcutItems()` |
| `VivaDicta/AppDelegate.swift` | `AppDelegate` (Firebase init, scene config), `SceneDelegate` (quick action delivery, deferred action handling) |
| `VivaDicta/AppState.swift` | Navigation flags, `userActivity(for:)`, Spotlight indexing methods |
| `VivaDicta/Router.swift` | `NavigationStack` path wrapper (`@Observable`, `@MainActor`) |
| `VivaDicta/Shared/AppGroupCoordinator.swift` | App Group UserDefaults + Darwin notification bus; keyboard session lifecycle; Share Extension audio handoff |
| `VivaDictaKeyboard/KeyboardViewController.swift` | `openMainAppForHotMic()` — builds `vivadicta://record-for-keyboard` URL |
| `ShareExtension/ShareViewController.swift` | Copies audio to app group, opens `vivadicta://transcribe-shared` via responder chain |
| `VivaDictaWidget/VivaDictaWidget.swift` | `widgetURL(URL(string: "startRecordFromWidget"))` on all widget families |
| `VivaDicta/Models/TranscriptionEntity.swift` | `IndexedEntity` for Spotlight + App Intents; `searchableAttributes` |
