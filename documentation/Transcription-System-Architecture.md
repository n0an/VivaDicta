# Transcription System Architecture

## Overview

The transcription system routes audio files to the appropriate speech-to-text provider based on the active VivaMode configuration. It supports on-device models (WhisperKit, Parakeet) and cloud providers (OpenAI, Groq, Deepgram, ElevenLabs, Gemini, Mistral, Soniox, Custom), with a unified post-processing pipeline.

## Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                         TranscriptionManager                                 │
│                                                                              │
│  Unified interface: transcribe(audioURL:) → String                          │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                      Provider Router                                │    │
│  │                                                                     │    │
│  │  currentMode.transcriptionProvider determines routing:              │    │
│  │                                                                     │    │
│  │  .parakeet  ──► ParakeetTranscriptionService (NVIDIA, on-device)   │    │
│  │  .whisperKit ──► WhisperKitTranscriptionService (OpenAI, on-device)│    │
│  │  .* (cloud)  ──► CloudTranscriptionService (sub-router)            │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                   Post-Processing Pipeline                          │    │
│  │                                                                     │    │
│  │  Raw text from provider                                             │    │
│  │       │                                                             │    │
│  │       ▼                                                             │    │
│  │  TranscriptionOutputFilter.filter()     ← Always applied           │    │
│  │       │  • Remove [brackets], (parens), {braces}                   │    │
│  │       │  • Remove <TAG>...</TAG> blocks                            │    │
│  │       │  • Remove filler words (uh, um, hmm...)                    │    │
│  │       │  • Collapse whitespace                                     │    │
│  │       ▼                                                             │    │
│  │  TextFormatter.format()                 ← If mode.isAutoTextForma..│    │
│  │       │  • Split into ~50-word paragraphs                          │    │
│  │       │  • Max 4 significant sentences per paragraph               │    │
│  │       │  • NaturalLanguage tokenizer with lang detection           │    │
│  │       ▼                                                             │    │
│  │  ReplacementsService.applyReplacements()← If isReplacementsEnabled │    │
│  │       │  • SwiftData-backed word replacements                      │    │
│  │       │  • Case-insensitive regex matching                         │    │
│  │       │  • Word boundary aware (CJK/Thai exempted)                 │    │
│  │       ▼                                                             │    │
│  │  TranscriptionOutputFilter.hasMeaningfulContent() ← Before save     │    │
│  │       │  • Reject empty / punctuation-only text                     │    │
│  │       ▼                                                             │    │
│  │  Final transcribed text                                             │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Provider Hierarchy

```
TranscriptionService (protocol)
    │
    ├── ParakeetTranscriptionService      (on-device, NVIDIA)
    │
    ├── WhisperKitTranscriptionService    (on-device, OpenAI Whisper)
    │   └── Supports model preloading for faster first transcription
    │
    └── CloudTranscriptionService         (sub-router)
        │
        ├── OpenAITranscriptionService    (Whisper API)
        ├── GroqTranscriptionService      (Whisper via Groq)
        ├── DeepgramTranscriptionService  (Nova models)
        ├── ElevenLabsTranscriptionService(Scribe v1)
        ├── GeminiTranscriptionService    (Gemini models)
        ├── MistralTranscriptionService   (Mistral STT)
        ├── SonioxTranscriptionService    (Soniox v4)
        └── CustomTranscriptionService    (user-configured endpoint)
```

## Audio Format and MIME Types

Cloud transcription services use dynamic MIME types derived from the audio file extension via `URL.audioMIMEType` (`Extensions/URL+AudioMIMEType.swift`):

| Extension | MIME Type |
|-----------|-----------|
| `.wav` | `audio/wav` (default) |
| `.m4a` | `audio/mp4` |
| `.mp3` | `audio/mpeg` |
| `.flac` | `audio/flac` |
| `.ogg` | `audio/ogg` |
| `.webm` | `audio/webm` |

The iOS app records WAV (16kHz mono PCM). The Watch app records M4A (16kHz mono AAC). On-device providers (WhisperKit, Parakeet) use AVFoundation to load audio files and handle format detection automatically - no MIME type needed.

## Custom Endpoint Request Formats

`CustomTranscriptionService` can send the same set of fields (`file`, `model`, `language`, `response_format`, `temperature`) in two wire formats, selected per endpoint via `CustomTranscriptionRequestFormat` and stored on `CustomTranscriptionModel.requestFormat`:

| Format | Content-Type | `file` field |
|--------|--------------|--------------|
| `.multipartFormData` (default) | `multipart/form-data; boundary=…` | raw audio bytes as a file part |
| `.jsonBase64` | `application/json` | `data:<mime-type>;base64,<payload>` string |

OpenAI's own API and most self-hosted Whisper servers want multipart. Some gateways only accept the JSON/base64 shape and answer multipart with HTTP 400, so the user picks the format in `AddCustomTranscriptionModelView`. Configurations saved before the field existed decode as `.multipartFormData`.

## Model Availability Checking

```
getCurrentTranscriptionModel() validation:

┌──────────────────┬────────────────────────────────────────────┐
│ Provider Type    │ Availability Check                         │
├──────────────────┼────────────────────────────────────────────┤
│ Parakeet         │ model.isDownloaded == true                 │
│ WhisperKit       │ model.isDownloaded == true                 │
│ Cloud providers  │ model.apiKey != nil                        │
│ Custom           │ CustomTranscriptionModelManager.isConfigured│
└──────────────────┴────────────────────────────────────────────┘
```

## Sequence Diagram: Transcription Flow

```
RecordViewModel          TranscriptionManager        Provider Service
      │                          │                         │
      │  transcribe(audioURL:)   │                         │
      ├─────────────────────────►│                         │
      │                          │                         │
      │                          │  getCurrentModel()      │
      │                          │  (validate available)   │
      │                          │                         │
      │                          │  Route by provider:     │
      │                          │  .parakeet → Parakeet   │
      │                          │  .whisperKit → WhisperKit
      │                          │  .* → CloudTranscription│
      │                          │                         │
      │                          ├────────────────────────►│
      │                          │  transcribe(url, model) │
      │                          │                         │
      │                          │◄────────────────────────│
      │                          │  raw text               │
      │                          │                         │
      │                          │  Pipeline:              │
      │                          │  1. OutputFilter         │
      │                          │  2. TextFormatter?       │
      │                          │  3. Replacements?        │
      │                          │                         │
      │◄─────────────────────────│                         │
      │  processed text          │                         │
```

## Model Sources

| Provider | Type | Models | Language Support |
|----------|------|--------|-----------------|
| **Parakeet** | On-device | NVIDIA Parakeet models | Multi-language |
| **WhisperKit** | On-device | OpenAI Whisper variants | 99 languages |
| **OpenAI** | Cloud | whisper-1 | 57 languages |
| **Groq** | Cloud | Whisper Large v3 + distil | Multi-language |
| **Deepgram** | Cloud | Nova-2, Whisper | 100+ languages |
| **ElevenLabs** | Cloud | Scribe v1 | 99 languages |
| **Gemini** | Cloud | Gemini Flash/Pro | Multi-language |
| **Mistral** | Cloud | Mistral STT models | Multi-language |
| **Soniox** | Cloud | stt-async-v5, stt-rt-v5 (streaming) | Multi-language |
| **Custom** | Cloud | User-configured | Depends on endpoint |

## Realtime (Streaming) Transcription

Most providers work by upload: the recording is finished, sent, and awaited. Five models instead transcribe over a WebSocket while the user speaks, so by the time recording stops only the tail is outstanding.

| Model | Session actor | Settled unit | Unsettled tail |
|---|---|---|---|
| Soniox `stt-rt-v5` | `SonioxRealtimeDictationSession` | `is_final` tokens | non-final tokens, replaced per batch |
| Deepgram Nova 3 | `DeepgramNovaRealtimeSession` | `is_final` chunks | interim string |
| Deepgram Flux | `DeepgramFluxRealtimeSession` | `EndOfTurn` turns | open turn (`EagerEndOfTurn` is retractable) |
| ElevenLabs Scribe | `ElevenLabsRealtimeSession` | `committed_transcript` | `partial_transcript` |
| Mistral Voxtral Realtime | `MistralRealtimeSession` | deltas (additive) | none - no tail exists |

`TranscriptionModelProvider.isStreamingModel(_:)` is the predicate; `asyncEquivalent(of:)` maps a streaming slug to the batch model used when the socket path is not taken. Flux and Voxtral Realtime have no batch counterpart, so they fall back to Nova 3 and `voxtral-mini-latest` respectively.

### The shared contract

Every backend is an `actor` conforming to `RealtimeDictationSession`, and all are fed identical PCM (`pcm_s16le`, 16 kHz, mono). Each wraps it for its own wire format - raw binary frames for Soniox and Deepgram, base64-in-JSON for ElevenLabs and Mistral - so the capture side stays provider-agnostic.

`finish()` sends the provider's end-of-audio message, then waits up to 10 seconds for the server to flush and acknowledge. **It throws rather than returning partial text.** The WAV is written throughout, so the caller's recovery is to transcribe that file the normal way; a truncated transcript returned as a success would be saved silently with nothing to signal the loss.

### Two capture paths

The recorder differs by whether a hot mic session is already running, and `RecordViewModel.startCaptureAudio` branches on `prewarmManager.isSessionActive`:

- **No prewarm session** - `RealtimeDictationCoordinator` opens its own `StreamingAudioCapture`, an `AVAudioEngine` capture that writes the WAV and fans identical PCM to the socket. `AVAudioRecorder`, the normal recorder, exposes no buffer callbacks and cannot stream.
- **Prewarm session active** (the keyboard path) - the coordinator borrows the running engine via `prewarmedBy:`. `AudioPrewarmManager` keeps writing the WAV in the engine's native format and additionally feeds a `RealtimePCMStreamSink`. A second `AVAudioEngine` on the same input would fight the prewarm session for the route. See Hot-Mic-Audio-Prewarm-Architecture.md.

Either way a socket that will not open falls back to an ordinary capture rather than failing the recording.

### When streaming is skipped

`RealtimeDictationCoordinator.canHandle(mode:modelName:)` returns false, and the mode takes the upload path, when any of these hold:

- the model is not a streaming model, or its provider has no API key
- the mode has an inline translation target
- Speaker Labels is enabled (a global setting, not a mode property)

The last two are not arbitrary: the socket is opened in transcription-only mode, and a successful stream bypasses the provider's batch job entirely, so streaming those modes would quietly save untranslated text with no speaker attribution - worse than simply being slower.

### Merging tokens

`RealtimeTranscriptAccumulator` holds the rule that is easy to get backwards: providers resend the non-final tail in full on every message while finals are append-only. Appending both duplicates every word as it firms up, so finals accumulate and interims are rebuilt per batch. It is a pure value type with no socket or actor involvement precisely so the rule can be tested directly.

### Post-processing

Streamed text runs through `TranscriptionManager.postProcessStreamedText(_:startTime:)`, sharing one implementation with the upload path so filters, formatting, word replacements, and completion analytics cannot diverge between the two.

## Key Features

### WhisperKit Model Preloading
- `preloadWhisperKitModelIfNeeded()` loads model weights into memory at app startup
- Only triggers if current mode uses WhisperKit
- Significantly reduces first transcription latency
- Tracks performance metrics: prewarm, load, and total init duration

### Language Management
- `selectedLanguage` stored in shared UserDefaults (accessible to keyboard extension)
- Each VivaMode can override language or use "auto" detection
- `setCurrentMode()` automatically applies the mode's language setting

### Cloud Model Refresh
- `updateCloudModels()` rebuilds available model list when API keys change
- Triggers `onCloudModelsUpdate` callback for UI updates
- Combines: Parakeet + WhisperKit + Cloud models

### Model Availability
- `hasAvailableTranscriptionModels`: Quick check if any model is usable
- Considers: downloaded on-device models, configured API keys, custom model setup
