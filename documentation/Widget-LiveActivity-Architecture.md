# Widget & Live Activity Architecture

## Overview

VivaDicta's widget system provides three entry points for starting a recording without opening the app: a configurable home screen widget, a static icon widget, and a suite of lock screen widgets. A Live Activity surfaces real-time recording and processing status on the Dynamic Island. All surface types share a single widget extension target (`VivaDictaWidget`) and communicate with the main app exclusively through `AppGroupCoordinator` Darwin notifications and shared App Group UserDefaults.

## Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                         VivaDictaWidgetBundle                                │
│                                                                              │
│  ┌──────────────────────┐  ┌──────────────────────┐  ┌──────────────────┐   │
│  │  VivaDictaIconWidget  │  │  VivaDictaWidget      │  │VivaDictaWidget   │   │
│  │  (StaticConfiguration)│  │  (AppIntentConfiguration│  │Control          │   │
│  │                      │  │   + ConfigurationAppIntent│  │(ControlWidget)  │   │
│  │  Surfaces:           │  │                      │  │                  │   │
│  │  • .systemSmall      │  │  Surfaces:           │  │  Action:         │   │
│  │  • .accessoryCircular│  │  • .systemSmall      │  │  ToggleRecord    │   │
│  │  • .accessoryRectang.│  │  • .accessoryCircular│  │  Intent          │   │
│  │  • .accessoryInline  │  │  • .accessoryRectang.│  │                  │   │
│  │                      │  │  • .accessoryInline  │  │                  │   │
│  │  Timeline: 15 min    │  │                      │  │                  │   │
│  │  intervals (96 steps)│  │  Timeline: 1h (24    │  │                  │   │
│  │  Animated mesh bg    │  │  steps), color config│  │                  │   │
│  └──────────────────────┘  └──────────────────────┘  └──────────────────┘   │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐    │
│  │                      VivaDictaLiveActivity                           │    │
│  │                   (ActivityConfiguration)                            │    │
│  │                                                                      │    │
│  │  Lock screen / notification banner:                                  │    │
│  │  • App name + ToggleSessionIntent stop button                        │    │
│  │                                                                      │    │
│  │  Dynamic Island (expanded):                                          │    │
│  │  • Leading: app name + state.statusText                              │    │
│  │  • Trailing: state icon (tappable stop button when idle)             │    │
│  │                                                                      │    │
│  │  Dynamic Island (compact / minimal):                                 │    │
│  │  • Trailing / minimal: state icon only                               │    │
│  └──────────────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────────────┘

                        ▲                    │
     Darwin notification│                    │ Darwin notification
     (startRecording,   │                    │ (terminateSession
      startFromControl) │                    │  FromLiveActivity)
                        │                    ▼

┌──────────────────────────────────────────────────────────────────────────────┐
│                       Main App (AppState + AppGroupCoordinator)              │
│                                                                              │
│  startLiveActivity()        ──► Activity.request(attributes:content:)        │
│  updateLiveActivityState()  ──► liveActivity.update(updatedContent)          │
│  endLiveActivity()          ──► liveActivity.end(nil, .immediate)            │
│  checkAndEndStaleLiveActivity() ── timer-based 10-minute cleanup             │
└──────────────────────────────────────────────────────────────────────────────┘
```

## LiveActivityState: The State Machine

`LiveActivityState` is the single source of truth that drives all Live Activity UI. It is a `Codable` enum, which means values cross the process boundary as part of `ActivityContent` without any custom serialisation.

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        LiveActivityState State Machine                       │
│                                                                              │
│                        ┌─────────────┐                                      │
│                  ┌────►│    idle      │◄───────────────────────────┐         │
│                  │     │  (orange mic)│                            │         │
│                  │     └──────┬───────┘                            │         │
│                  │            │ startLiveActivity()                │         │
│                  │            │ updateLiveActivityState(.recording) │         │
│                  │            ▼                                    │         │
│                  │     ┌─────────────┐                            │         │
│                  │     │  recording  │                            │         │
│                  │     │(orange signal│                           │         │
│                  │     │    meter)   │                            │         │
│                  │     └──────┬───────┘                            │         │
│                  │            │ stopRecording()                    │         │
│                  │            │ updateLiveActivityState(.transcribing)│       │
│                  │            ▼                                    │         │
│                  │     ┌─────────────┐                            │         │
│                  │     │transcribing │                            │         │
│                  │     │(blue pencil)│                            │         │
│                  │     └──────┬───────┘                            │         │
│                  │            │ AI enabled                         │         │
│                  │            │ updateLiveActivityState(.enhancing) │         │
│                  │            ▼                                    │         │
│                  │     ┌─────────────┐                            │         │
│                  │     │  enhancing  │                            │         │
│                  │     │(blue sparkles│                           │         │
│                  │     └──────┬───────┘                            │         │
│                  │            │                                    │         │
│                  └────────────┘ endLiveActivity() / timer / stop  ─┘         │
│                                                                              │
│  State properties:                                                           │
│  • iconName   — SF Symbol name for compact/minimal/trailing display         │
│  • iconColor  — "orange" (idle/recording) | "blue" (transcribing/enhancing) │
│  • statusText — human-readable label shown in expanded leading region        │
└──────────────────────────────────────────────────────────────────────────────┘
```

| State | Icon | Color | Status Text |
|-------|------|-------|-------------|
| `.idle` | `microphone.circle.fill` | orange | "Ready" |
| `.recording` | `microphone.and.signal.meter.fill` | orange | "Recording" |
| `.transcribing` | `pencil.and.scribble` | blue | "Transcribing" |
| `.enhancing` | `sparkles` | blue | "AI Processing" |

## VivaDictaLiveActivityAttributes

`VivaDictaLiveActivityAttributes` conforms to `ActivityAttributes` and defines the static and dynamic portions of the Live Activity payload.

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                  VivaDictaLiveActivityAttributes                             │
│                                                                              │
│  Static (set once at Activity.request time):                                 │
│  • name: String   — always "VivaDicta"                                      │
│                                                                              │
│  ContentState (updated via liveActivity.update()):                           │
│  • state: LiveActivityState                                                  │
│    ├── .idle                                                                 │
│    ├── .recording                                                            │
│    ├── .transcribing                                                         │
│    └── .enhancing                                                            │
│                                                                              │
│  staleDate: nil  — activity never expires automatically (timer managed       │
│                    in AppState instead)                                      │
└──────────────────────────────────────────────────────────────────────────────┘
```

The static `name` field is intentionally minimal. All visual variation comes through `ContentState.state`; no auxiliary static data (e.g. mode name or language) is embedded.

## Live Activity Lifecycle (AppState)

`AppState` owns the `Activity` handle and manages its full lifecycle. The activity is never started from the widget extension itself; it is always started by the main app in response to user action.

```
startLiveActivity()
    │
    ├── Guard: liveActivity == nil (prevent double-start)
    ├── Invalidate any existing liveActivityTimer
    ├── Build VivaDictaLiveActivityAttributes(name: "VivaDicta")
    ├── Build ActivityContent(state: .idle, staleDate: nil)
    ├── Activity.request(attributes:content:) → stores handle in liveActivity
    ├── Record liveActivityStartTime = Date()
    └── Schedule liveActivityTimer (600 s) → endLiveActivity()

updateLiveActivityState(_ state: LiveActivityState)
    │
    ├── Guard: liveActivity != nil
    ├── Build ActivityContent(state: ContentState(state:), staleDate: nil)
    └── liveActivity.update(updatedContent)

endLiveActivity()
    │
    ├── Guard: liveActivity != nil
    ├── liveActivityTimer.invalidate()
    ├── liveActivity.end(nil, dismissalPolicy: .immediate)
    ├── liveActivity = nil
    └── liveActivityStartTime = nil
```

### Stale Activity Cleanup

Two mechanisms prevent orphaned Live Activities:

**Timer-based (normal path):** A `Timer` fires after 600 seconds (10 minutes) from `liveActivityStartTime` and calls `endLiveActivity()`. This is the primary safety net for sessions left open when the app is backgrounded.

**Scene-transition check (cold start / foreground):** `checkAndEndStaleLiveActivity()` is called when the app transitions to the foreground. It compares the elapsed time against the 600-second limit:

```
checkAndEndStaleLiveActivity()
    │
    ├── Guard: liveActivity != nil, liveActivityStartTime != nil
    ├── elapsed = Date().timeIntervalSince(startTime)
    │
    ├── elapsed >= 600s
    │   └── endLiveActivity()
    │
    └── elapsed < 600s
        ├── liveActivityTimer.invalidate()
        └── Reschedule timer for (600 - elapsed) seconds
```

This handles the case where the app was force-killed or relaunched while a Live Activity was running. Without this check, the timer created in the previous process would be lost and the activity would remain visible indefinitely.

## ToggleSessionIntent

`ToggleSessionIntent` is a `LiveActivityIntent` that runs inside the widget extension process without opening the main app. It is used as the action for the stop button rendered inside the Live Activity UI.

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                         ToggleSessionIntent                                  │
│                                                                              │
│  Parameters:                                                                 │
│  • isSessionActive: Bool                                                     │
│                                                                              │
│  perform()                                                                   │
│      │                                                                       │
│      └── isSessionActive == false                                            │
│          ├── AppGroupCoordinator.shared                                      │
│          │       .requestTerminateSessionFromLiveActivity()                  │
│          │   ──► Darwin notification:                                        │
│          │       "...terminateSessionFromLiveActivity"                       │
│          │   ──► Main app onTerminateSessionFromLiveActivity callback        │
│          │                                                                   │
│          └── End all Activity<VivaDictaLiveActivityAttributes>.activities   │
│              immediately (dismissalPolicy: .immediate)                       │
│              (widget-side cleanup, independent of main app)                  │
└──────────────────────────────────────────────────────────────────────────────┘
```

The intent always initialises with `isSessionActive: false` when embedded in the stop button — the parameter exists to support a future toggle-on path if needed. `isDiscoverable` is `false` so the intent does not appear in Shortcuts or Siri.

The dual cleanup pattern is deliberate: ending activities from the widget extension ensures immediate visual dismissal even if the main app is not yet running to handle the Darwin notification.

## Home Screen Widget (VivaDictaWidget)

`VivaDictaWidget` uses `AppIntentConfiguration` with `ConfigurationAppIntent` so users can pick a background color theme from the widget edit screen.

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                           VivaDictaWidget                                    │
│                   AppIntentConfiguration, kind: "VivaDictaWidget"            │
│                                                                              │
│  ConfigurationAppIntent:                                                     │
│  • widgetColorString: String? → resolves to WidgetColor enum                │
│  • WidgetColor cases: gradient1, gradient2, orange, red, blue, green        │
│  • Each case defines a 3×3 MeshGradient color array                         │
│                                                                              │
│  Provider (AppIntentTimelineProvider):                                       │
│  • Hourly entries for 24 hours (policy: .after +24h)                        │
│  • SimpleEntry.t — time parameter derived from hour+minute for mesh         │
│    animation: t = (hours*60 + minutes) / 10.0 (cycles ~every 10 hours)      │
│                                                                              │
│  Supported families:                                                         │
│  • .systemSmall    → WidgetViewSmall (animated MeshGradient background,      │
│                       mic.circle icon, .widgetURL("startRecordFromWidget"))  │
│  • .accessoryCircular   → LockScreenCircularView                             │
│  • .accessoryRectangular→ LockScreenRectangularView                          │
│  • .accessoryInline     → Label("Record Note", mic icon)                    │
└──────────────────────────────────────────────────────────────────────────────┘
```

The `t` parameter feeds sine-based point offsets for the `MeshGradient`, producing a slowly shifting animated background that cycles approximately every 10 hours using only discrete timeline snapshots — no continuous animations.

## Icon Widget (VivaDictaIconWidget)

`VivaDictaIconWidget` uses `StaticConfiguration` (no user-configurable parameters). Its identity is the VivaDicta app icon rather than the microphone icon used in the configurable widget.

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        VivaDictaIconWidget                                   │
│                   StaticConfiguration, kind: "VivaDictaIconWidget"           │
│                                                                              │
│  Provider (TimelineProvider):                                                │
│  • 15-minute entries for 24 hours (96 steps, policy: .after +24h)           │
│  • IconWidgetEntry.t = (hours*60 + minutes) / 5.0                           │
│    (faster cycle ~5 hours, used for animated "VivaDicta" text gradient)      │
│                                                                              │
│  Supported families:                                                         │
│  • .systemSmall    → VivaDictaIconWidgetEntryViewSmall                       │
│    ├── Icon: VivaDictaIconFrameless image                                    │
│    │   - Full color mode: standard image render                              │
│    │   - Reduced color mode: .luminanceToAlpha() for system tinting          │
│    ├── "VivaDicta" text with animated MeshGradient foreground                │
│    ├── "Record Note" subtitle (.secondary)                                   │
│    └── Background: dark/light-aware LinearGradient                           │
│  • .accessoryCircular   → LockScreenIconCircularView (VivaDictaIcon50)       │
│  • .accessoryRectangular→ LockScreenIconRectangularView (icon + name + sub)  │
│  • .accessoryInline     → Label("Record Note", mic icon)                    │
└──────────────────────────────────────────────────────────────────────────────┘
```

Both widgets respond to `widgetRenderingMode` so they adapt correctly when placed in reduced-color contexts (e.g. StandBy clock face, always-on display).

## Lock Screen Widget Views

Lock screen families are split into two sets, one per widget kind. They live in `LockScreenWidgetViews.swift` and are shared between `VivaDictaWidget` and `VivaDictaIconWidget`.

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                         Lock Screen View Inventory                           │
│                                                                              │
│  Used by VivaDictaWidget:                                                    │
│  • LockScreenCircularView    — mic.circle symbol, orange gradient tint       │
│  • LockScreenRectangularView — mic.circle + "VivaDicta" text                 │
│                                                                              │
│  Used by VivaDictaIconWidget:                                                │
│  • LockScreenIconCircularView    — VivaDictaIcon50 image                     │
│  • LockScreenIconRectangularView — icon + "VivaDicta" bold + "Record Note"   │
│                                                                              │
│  All views:                                                                  │
│  • Use .containerBackground(for: .widget) { } (required for lock screen)    │
│  • Use ContainerRelativeShape for backgrounds that clip to widget shape      │
│  • .widgetURL("startRecordFromWidget") set at the parent router level        │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Control Widget (VivaDictaWidgetControl)

`VivaDictaWidgetControl` is a `ControlWidget` that appears in Control Center. It uses `ToggleRecordIntent` (defined in `AppIntent.swift`) rather than `ToggleSessionIntent`, triggering a Darwin notification path through `AppGroupCoordinator.requestStartRecordingFromControl()`.

```
StaticControlConfiguration(kind: "VivaDictaControlWidget")
    └── ControlWidgetButton(action: ToggleRecordIntent())
            └── Image(systemName: "microphone.circle")
```

## Widget ↔ App Communication

All inter-process communication flows through `AppGroupCoordinator` using two mechanisms:

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                     Communication Channels                                   │
│                                                                              │
│  1. Shared App Group UserDefaults                                            │
│     Container: group.com.antonnovoselov.VivaDicta                           │
│     Used for: isRecording, transcriptionStatus, audioLevel,                 │
│               keyboardSessionActive, transcribedText, etc.                  │
│     Direction: main app writes → extensions read (and vice versa)           │
│                                                                              │
│  2. Darwin Notifications (CFNotificationCenter)                             │
│     Direction: bidirectional, cross-process, no data payload                │
│     Delivery: .deliverImmediately flag                                       │
│                                                                              │
│  Widget → Main App notifications:                                            │
│  • "...startRecording"               (keyboard extension tap)               │
│  • "...startRecordingFromControl"    (Control Center button)                │
│  • "...terminateSessionFromLiveActivity" (Live Activity stop button)         │
│                                                                              │
│  Main App → Extensions notifications:                                        │
│  • "...recordingStateChanged"        (recording started/stopped)            │
│  • "...transcriptionTranscribing"    (transcription in progress)            │
│  • "...transcriptionEnhancing"       (AI processing in progress)            │
│  • "...transcriptionCompleted"       (text ready to insert)                 │
│  • "...transcriptionError"           (pipeline failure)                      │
│  • "...audioLevelUpdated"            (meter level for keyboard UI)          │
│                                                                              │
│  Widget URL scheme (passive, taps only):                                     │
│  • "startRecordFromWidget" — handled by the main app's onOpenURL modifier   │
│    Sets AppState.shouldStartRecording = true                                 │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Termination Flow from Live Activity

```
User taps stop button (Dynamic Island or lock screen banner)
    │
    ▼
ToggleSessionIntent.perform()   [widget process]
    ├── AppGroupCoordinator.shared.requestTerminateSessionFromLiveActivity()
    │       └── Posts Darwin: "...terminateSessionFromLiveActivity"
    └── Activity<...>.activities.forEach { await $0.end(nil, .immediate) }

Darwin notification delivered
    │
    ▼
AppGroupCoordinator.handleTerminateSessionFromLiveActivity()   [main app process]
    └── Task { @MainActor in onTerminateSessionFromLiveActivity?() }
            └── AppState: stop recording, cancel transcription, end session
```

### Recording Trigger Flow from Widget Tap

```
User taps widget (any family)
    │
    ▼
System opens main app with URL "startRecordFromWidget"
    │
    ▼
App's .onOpenURL handler
    └── AppState.shouldStartRecording = true
            └── RecordView reacts to state change → begins recording
```

## Timer-Based Duration Tracking

`AppState` uses a `Timer` (not `Task.sleep`) for the 10-minute Live Activity cap. This choice is intentional: a `Timer` fires on the main run loop even when the app is backgrounded briefly, and it can be invalidated and rescheduled cleanly during foreground transitions.

```
liveActivityTimer = Timer.scheduledTimer(
    withTimeInterval: 600,
    repeats: false
) { [weak self] _ in
    Task { await self?.endLiveActivity() }
}
```

`liveActivityStartTime` is stored alongside the timer so that `checkAndEndStaleLiveActivity()` can compute remaining time and reschedule correctly after a cold start. The two fields are always set and cleared together.

## Dismissal Policy

All Live Activity endings use `.immediate`. The `.default` policy keeps the activity visible in the notification area for several seconds after ending; `.immediate` removes it instantly. This is correct behaviour for VivaDicta because the activity ending signals that the session is over, not that a result is ready to be viewed.

The widget extension also ends activities with `.immediate` in `ToggleSessionIntent.perform()`, ensuring the UI disappears even when the main app has not yet processed the termination Darwin notification.

## Key Files

| File | Location | Purpose |
|------|----------|---------|
| `VivaDictaWidgetBundle.swift` | `VivaDictaWidget/` | Entry point; registers all three widget kinds |
| `VivaDictaWidget.swift` | `VivaDictaWidget/` | Configurable home screen + lock screen widget |
| `VivaDictaIconWidget.swift` | `VivaDictaWidget/` | Static icon-based home screen + lock screen widget |
| `VivaDictaLiveActivity.swift` | `VivaDictaWidget/` | Dynamic Island and lock screen banner |
| `LockScreenWidgetViews.swift` | `VivaDictaWidget/` | Shared circular, rectangular, and inline lock screen views |
| `ToggleSessionIntent.swift` | `VivaDictaWidget/` | `LiveActivityIntent` for the in-activity stop button |
| `AppIntent.swift` | `VivaDictaWidget/` | `ConfigurationAppIntent` and `WidgetColor` enum |
| `VivaDictaWidgetControl.swift` | `VivaDictaWidget/` | Control Center button |
| `VivaDictaLiveActivityAttributes.swift` | `VivaDicta/Models/` | `ActivityAttributes` model and `LiveActivityState` enum |
| `AppState.swift` | `VivaDicta/` | Live Activity start / update / end / stale-check logic |
| `AppGroupCoordinator.swift` | `VivaDicta/Shared/` | Darwin notification bridge and shared UserDefaults |
