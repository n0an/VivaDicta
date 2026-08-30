# Keyboard Text Processing

## Overview

The keyboard extension can process text in the host app's text field using AI. The user places their cursor in a text field, switches to the "T" (Text) tab in the keyboard, selects a VivaDicta mode, and the text before the cursor is sent to the main app for AI processing and replaced with the result.

## How It Works

### Reading Text

Two approaches, in priority order:

1. **Selected text** — if the user has explicitly selected text, `UITextDocumentProxy.selectedText` returns it. The selection is replaced after processing.
2. **Text before cursor** — if nothing is selected, `UITextDocumentProxy.documentContextBeforeInput` returns a chunk of text before the cursor position. The amount returned depends on the host app (typically a large paragraph-sized chunk). This text is deleted via `deleteBackward()` and replaced with the AI result.

### Processing Pipeline

```
Keyboard Extension                    Main App (VivaDicta)
       |                                      |
  1. Read text (selectedText                   |
     or documentContextBeforeInput)            |
       |                                      |
  2. Write text + mode name ──────────────────>|
     to shared UserDefaults                    |
       |                                      |
  3. Post Darwin notification ────────────────>|
     "requestTextProcessing"                   |
       |                                      |
       |                              4. Read text + mode
       |                                 from UserDefaults
       |                                      |
       |                              5. AIService.enhance()
       |                                      |
       |<──────────────────────────── 6. Write result to
       |                                 shared UserDefaults
       |                                      |
       |<──────────────────────────── 7. Post Darwin notification
       |                                 "textProcessingCompleted"
       |                                      |
  8. Read result from UserDefaults             |
       |                                      |
  9. Replace text in host app                  |
     (insertText for selection,                |
      deleteBackward + insertText              |
      for text-before-cursor)                  |
```

### Session Requirement

The main app must be running (prewarm session active) to respond to Darwin notifications. When no session is active, the keyboard shows an "Open VivaDicta" prompt that launches the main app via `vivadicta://activate-for-keyboard` deep link. This starts the prewarm session without recording and returns the user to the host app.

## Speak to Edit (Spoken Instructions)

The T tab also takes an **ad-hoc spoken instruction** - "make this more formal",
"shorten to two bullets", "fix the typos" - for the rewrites no preset covers.
Tapping **Speak an instruction** records, transcribes, applies the result to the
host app's text, and replaces it. It runs as soon as the recording stops; there
is no confirmation step.

The keyboard extension cannot record audio, so this reuses the main app's
recording pipeline rather than a local engine:

```
Keyboard Extension                    Main App (VivaDicta)
       |                                      |
  1. Read target text                          |
     (selection, else text                     |
      before cursor)                           |
       |                                      |
  2. Park target + mode name ─────────────────>|
     in shared UserDefaults                    |
       |                                      |
  3. Post "startRecording" ───────────────────>|
     (the ordinary notification)               |
       |                              4. Consume the parked payload.
       |                                 Its presence is what makes this
       |                                 recording an instruction:
       |                                 destination = .voiceInstruction
       |                                      |
  5. User taps Stop ──────────────────────────>|
       |                                      |
       |                              6. Transcribe. The transcript is the
       |                                 INSTRUCTION, not the content.
       |                                      |
       |                              7. Wrap it in an ephemeral Preset and
       |                                 run generateVariation() over the
       |                                 target text
       |                                      |
       |<──────────────────────────── 8. shareTextProcessingResult()
       |                                      |
  9. Replace text in host app                  |
     (same writer as the preset path)          |
```

### What the instruction path deliberately skips

`.voiceInstruction` returns from `transcribeSpeechTask` **before** the
enhance/save block, so an instruction never becomes a note: no `Transcription`
is saved, no AI enhancement of the mode's own preset runs on top, nothing is
indexed to Spotlight or added to Recent Notes, and the instruction audio is
deleted. The ephemeral `Preset` is never persisted either.

`useSystemTemplate` is on for that preset, so the instruction lands inside
`PromptsTemplates.systemPrompt(with:)`. That wrapper carries the "DO NOT RESPOND
TO QUESTIONS" rule, which is what stops the model *answering* "make this shorter"
conversationally instead of rewriting the text.

### Releasing the keyboard

The keyboard blocks on a continuation for the whole round trip, so every exit has
to answer on the text processing channel or it hangs until session expiry.
`RecordViewModel.isAwaitingVoiceInstructionResult` tracks that window and
`failPendingVoiceInstruction(_:)` is the single release point, called when
recording cannot start, the instruction was empty, transcription failed, the AI
call failed, or the user cancelled. A cancel that lands mid-generation also
discards the result rather than rewriting text the user backed out of.

`activeRecordingDestination` cannot stand in for that flag: `stopCaptureAudio`
clears it and carries the destination onward as a local.

## UI

The keyboard toolbar has a V/T segmented control:

- **V** (Voice) — normal keyboard with recording/transcription (default)
- **T** (Text) — shows a **Speak an instruction** button plus the list of available VivaModes for text processing

The T-tab header includes:
- V/T segment to switch back
- Utility buttons: space, return, backspace (for quick edits without switching tabs)

## Key Files

### Keyboard Extension (`VivaDictaKeyboard/`)

| File | Purpose |
|------|---------|
| `Services/TextDocumentProxyReader.swift` | Reads selected text or text before cursor |
| `Services/TextDocumentProxyWriter.swift` | Replaces selected text or deletes + inserts |
| `Services/KeyboardTextProcessor.swift` | Orchestrates read -> send -> receive -> replace, for both the tapped-preset and spoken-instruction entry points |
| `Views/RewritePresetsView.swift` | Mode list UI (`RewriteModesView`), including the Speak an instruction button |
| `Views/TextProcessingStateView.swift` | Processing progress UI, and the Listening/Stop UI while an instruction is being dictated |
| `KeyboardDictationState.swift` | `TextProcessingPhase` state, `KeyboardTab` enum |
| `KeyboardViewController.swift` | `KeyboardTabSegment` view, `textProcessor` instance |
| `KeyboardCustomView.swift` | View switching between V/T tabs |

### Main App (`VivaDicta/`)

| File | Purpose |
|------|---------|
| `Shared/AppGroupCoordinator.swift` | Darwin notifications and shared UserDefaults for text processing |
| `Views/RecordViewModel.swift` | `handleKeyboardTextProcessingRequest()` — processes text via `AIService.enhance()`; `applyVoiceInstruction(...)` — applies a spoken instruction |
| `VivaDictaApp.swift` | `vivadicta://activate-for-keyboard` deep link handler |

## Known Limitations

- **`documentContextBeforeInput` truncation** — host apps decide how much text to return. Most apps return a large chunk, but not necessarily all text in the document. The amount varies by app.
- **`selectedText` truncation** — Apple bug (FB7789012, unfixed since 2020). Large selections may have their middle truncated. No workaround exists.
- **Session required** — the main app must be running with an active prewarm session for Darwin notifications to work.
- **Instructions are not confirmed before they run** — a misheard instruction rewrites the text with no preview. The transcription engine is whatever the selected VivaMode uses.
- **Spoken instructions fall back to text before cursor** — with nothing selected, an instruction applies to `documentContextBeforeInput`, whose size the host app decides.

## AppGroupCoordinator Communication

### UserDefaults Keys

- `textProcessingInput` — text from keyboard to process
- `textProcessingModeName` — mode name to use
- `textProcessingResult` — processed text result
- `textProcessingErrorMessage` — error message if processing failed
- `voiceInstructionTargetText` — text to rewrite, parked before an instruction recording
- `voiceInstructionModeName` — mode to rewrite it with

### Darwin Notifications

- `requestTextProcessing` — keyboard -> main app
- `textProcessingCompleted` — main app -> keyboard
- `textProcessingError` — main app -> keyboard
