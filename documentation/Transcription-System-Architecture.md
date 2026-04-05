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
| **Soniox** | Cloud | stt-async-v4 | Multi-language |
| **Custom** | Cloud | User-configured | Depends on endpoint |

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
