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

## UI

The keyboard toolbar has a V/T segmented control:

- **V** (Voice) — normal keyboard with recording/transcription (default)
- **T** (Text) — shows a list of available VivaModes for text processing

The T-tab header includes:
- V/T segment to switch back
- Utility buttons: space, return, backspace (for quick edits without switching tabs)

## Key Files

### Keyboard Extension (`VivaDictaKeyboard/`)

| File | Purpose |
|------|---------|
| `Services/TextDocumentProxyReader.swift` | Reads selected text or text before cursor |
| `Services/TextDocumentProxyWriter.swift` | Replaces selected text or deletes + inserts |
| `Services/KeyboardTextProcessor.swift` | Orchestrates read -> send -> receive -> replace |
| `Views/RewritePresetsView.swift` | Mode list UI (`RewriteModesView`) |
| `Views/TextProcessingStateView.swift` | Processing progress UI |
| `KeyboardDictationState.swift` | `TextProcessingPhase` state, `KeyboardTab` enum |
| `KeyboardViewController.swift` | `KeyboardTabSegment` view, `textProcessor` instance |
| `KeyboardCustomView.swift` | View switching between V/T tabs |

### Main App (`VivaDicta/`)

| File | Purpose |
|------|---------|
| `Shared/AppGroupCoordinator.swift` | Darwin notifications and shared UserDefaults for text processing |
| `Views/RecordViewModel.swift` | `handleKeyboardTextProcessingRequest()` — processes text via `AIService.enhance()` |
| `VivaDictaApp.swift` | `vivadicta://activate-for-keyboard` deep link handler |

## Known Limitations

- **`documentContextBeforeInput` truncation** — host apps decide how much text to return. Most apps return a large chunk, but not necessarily all text in the document. The amount varies by app.
- **`selectedText` truncation** — Apple bug (FB7789012, unfixed since 2020). Large selections may have their middle truncated. No workaround exists.
- **Session required** — the main app must be running with an active prewarm session for Darwin notifications to work.

## AppGroupCoordinator Communication

### UserDefaults Keys

- `textProcessingInput` — text from keyboard to process
- `textProcessingModeName` — mode name to use
- `textProcessingResult` — processed text result
- `textProcessingErrorMessage` — error message if processing failed

### Darwin Notifications

- `requestTextProcessing` — keyboard -> main app
- `textProcessingCompleted` — main app -> keyboard
- `textProcessingError` — main app -> keyboard
