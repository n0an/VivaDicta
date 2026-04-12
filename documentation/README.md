# Documentation

## Core Systems

| Document | Description |
|----------|-------------|
| [Smart Search RAG](Smart-Search-RAG-Architecture.md) | Chunk-based local retrieval for Smart Search, grounding filter, prompt injection, citations, current embedder setup |
| [Recording & Audio Pipeline](Recording-Audio-Pipeline-Architecture.md) | AVAudioRecorder setup, audio session management, file handling |
| [Transcription System](Transcription-System-Architecture.md) | On-device (WhisperKit/Parakeet) and cloud transcription routing |
| [AI Processing](AI-Processing-Architecture.md) | Multi-provider AI text processing, prompt building, mode/preset routing |
| [OAuth](OAuth-Architecture.md) | OAuth PKCE sign-in for ChatGPT/Gemini, local callback server bridge, token lifecycle |
| [Text Processing Pipeline](Text-Processing-Pipeline-Architecture.md) | Multi-stage pipeline: replacements, vocabulary, AI, output filters, formatting |
| [Preset System](Preset-System-Architecture.md) | Built-in and custom presets, preset catalog, sync with CloudKit |
| [Data Persistence & CloudKit Sync](Data-Persistence-CloudKit-Architecture.md) | SwiftData models, CloudKit container, cross-device sync |
| [Tags System](Tags-System-Architecture.md) | Source tags, user tags, filtering logic, tag management |
| [Chat Architecture](Chat-Architecture.md) | Single-note and multi-note chat, context management, compaction |
| [Apple FM Chat Integration](Apple-FM-Chat-Integration.md) | Apple Foundation Models session lifecycle, synthesized transcripts, reactive compaction |

## Extensions & Integrations

| Document | Description |
|----------|-------------|
| [watchOS App](WatchOS-App-Architecture.md) | Watch companion app, WatchConnectivity, complications, mode picker |
| [Keyboard Extension](Keyboard-Extension-Architecture.md) | Custom keyboard with recording/transcription via AppGroupCoordinator |
| [Keyboard Text Processing](Keyboard-Text-Processing.md) | AI text processing from keyboard using UITextDocumentProxy and AppGroupCoordinator |
| [AppGroupCoordinator](AppGroupCoordinator-Architecture.md) | Shared state between main app and extensions via App Groups |
| [Widget & Live Activity](Widget-LiveActivity-Architecture.md) | Home/lock screen widgets, Live Activity for recording status |
| [App Intents & Shortcuts](App-Intents-Shortcuts-Architecture.md) | Siri/Shortcuts integration, TranscriptionEntity, Spotlight indexing |
| [Deep Linking & URL Routing](Deep-Linking-URL-Routing-Architecture.md) | URL scheme handling, navigation routing |
| [Hot Mic / Audio Prewarm](Hot-Mic-Audio-Prewarm-Architecture.md) | Audio session pre-warming for instant recording start |
| [Background Tasks](Background-Task-Architecture.md) | Background task protection for Watch audio and main app transcription |

## Guides & References

| Document | Description |
|----------|-------------|
| [Text Processing Pipeline (Guide)](text-processing-pipeline.md) | Detailed walkthrough of the text processing stages |
| [Haptic Feedback](haptics-implementation.md) | Haptic feedback patterns and implementation |
| [Logging & Log Capture](Logging-and-Log-Capture.md) | Logger setup, log capture from simulator/device, analyzing logs |
| [What's New Screen](whats-new-screen.md) | Developer guide for updating the What's New screen |
| [DocC Documentation](docc-documentation-guide.md) | Building and deploying DocC documentation to GitHub Pages |
