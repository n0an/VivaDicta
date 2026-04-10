# Chat Architecture

## Overview

VivaDicta provides two chat modes for conversational AI interaction with transcription notes:

- **Single-Note Chat** - Chat about one note, accessed from the note detail screen. Uses `ChatConversation` with cascade delete (deleting the note deletes the chat).
- **Multi-Note Chat** - Chat about multiple notes at once, accessed from the main screen. Uses `MultiNoteConversation` with nullify delete (deleting one source note preserves the conversation).

Both modes support all AI providers (Apple Foundation Models, OpenAI, Anthropic, Gemini, Groq, Mistral, Grok, Ollama, OpenRouter, custom endpoints, etc.), streaming responses with haptic feedback, context window management with auto-compaction, and persistent Apple FM sessions.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Entry Points                                │
│                                                                     │
│  TranscriptionDetailView       MainView                             │
│  ┌─────────────────────┐       ┌──────────────────────────────┐    │
│  │ Chat button          │       │ Chats button (bottom toolbar) │    │
│  │ → Single-note chat   │       │ → MultiNoteChatsListView      │    │
│  └──────────┬──────────┘       │                                │    │
│             │                   │ Chat button (selection mode)   │    │
│             │                   │ → Direct multi-note chat       │    │
│             │                   └──────────────┬───────────────┘    │
│             │                                  │                    │
└─────────────┼──────────────────────────────────┼────────────────────┘
              │                                  │
              ▼                                  ▼
┌──────────────────────┐       ┌──────────────────────────────────┐
│ ChatViewModel        │       │ MultiNoteChatViewModel           │
│                      │       │                                  │
│ conversation:        │       │ conversation:                    │
│   ChatConversation   │       │   MultiNoteConversation          │
│ transcription:       │       │ sources: [MultiNoteSource]       │
│   Transcription      │       │                                  │
│                      │       │ assembledNoteText:               │
│ assembledNoteText:   │       │   XML <NOTE> tags with           │
│   transcription.text │       │   id, title, date                │
└──────────┬───────────┘       └───────────────┬──────────────────┘
           │                                   │
           │    ┌──────────────────────────┐   │
           └───►│    Shared Infrastructure  │◄──┘
                │                          │
                │ ChatContextManager       │
                │ MultiNoteContextManager  │
                │ AIService+Chat           │
                │ LanguageModelSession+    │
                │   Compacting             │
                │ ChatCleanupService       │
                └──────────────────────────┘
```

## Data Models

### ChatConversation (Single-Note)

```swift
@Model
final class ChatConversation {
    var id: UUID
    var createdAt: Date
    var appleFMTranscriptData: Data?          // Encoded Apple FM Transcript

    @Relationship(deleteRule: .cascade)
    var messages: [ChatMessage]?

    @Relationship
    var transcription: Transcription?         // 1:1, cascade from Transcription
}
```

**Delete behavior:** Transcription owns the conversation via `@Relationship(deleteRule: .cascade)`. Deleting a note deletes its chat.

### MultiNoteConversation (Multi-Note)

```swift
@Model
final class MultiNoteConversation {
    var id: UUID
    var title: String                         // "5 selected notes", "All Notes (11)"
    var createdAt: Date
    var appleFMTranscriptData: Data?
    var noteContext: String                    // Assembled note text (stored at creation)
    var sourceNoteCount: Int                   // Number of notes at creation time

    @Relationship(deleteRule: .cascade)
    var messages: [ChatMessage]?
}
```

**Simplified design:** Note text is captured at creation time into `noteContext` (XML `<NOTE>` tags with id, title, date). No junction model or back-references to source transcriptions. This avoids complexity around note deletion cascading and makes the conversation fully self-contained.

### ChatMessage (Shared)

```swift
@Model
final class ChatMessage {
    var id: UUID
    var role: String                           // "user", "assistant", "summary"
    var content: String
    var createdAt: Date
    var aiProviderName: String?
    var aiModelName: String?
    var isError: Bool
    var isSummary: Bool                        // Compaction summary
    var estimatedTokenCount: Int               // Pre-computed for context management

    @Relationship(inverse: \ChatConversation.messages)
    var conversation: ChatConversation?

    @Relationship(inverse: \MultiNoteConversation.messages)
    var multiNoteConversation: MultiNoteConversation?
}
```

A message belongs to either a single-note or multi-note conversation (never both). Dual optional relationships avoid model duplication while keeping all existing UI components (`ChatBubbleView`, `ChatInputBar`) working unchanged.

## Context Management

### Token Estimation

`ChatContextManager.estimateTokens()` uses character-based heuristics:
- Latin text: ~4 characters per token
- CJK text: ~2 characters per token
- Pre-computed on each `ChatMessage.estimatedTokenCount` to avoid repeated estimation

### Per-Provider Context Limits

| Provider | Context Window |
|----------|---------------|
| Apple FM | Dynamic (`SystemLanguageModel.default.contextSize`) |
| Anthropic | 200,000 |
| OpenAI (GPT-5/4o/O3/O4) | 128,000 |
| Gemini 2.5+/3.x | 1,000,000 |
| Gemini (older) | 128,000 |
| Groq (Llama-4) | 128,000 |
| Groq (other) | 8,192 |
| Mistral, Grok | 128,000 |
| Ollama | 4,096 |
| OpenRouter, Vercel AI Gateway, HuggingFace | 32,000 |
| Default | 8,000 |

### Context Overflow Protection

- **Apple FM:** If note text + system prompt exceeds 60% of context, an error is shown upfront ("too long for Apple Foundation Models").
- **Cloud providers:** Notes are proportionally truncated if they exceed context budget. Each note gets `(budget * 4) / noteCount` characters, with `[... truncated ...]` appended.

### Auto-Compaction (Cloud Providers - 70% Threshold)

When context fill exceeds 70%, compaction triggers automatically before the next message. Older messages are summarized via a separate AI call using `ChatContextManager.compactionPrompt`. The most recent messages are kept; older ones are replaced by a single summary message.

Apple FM does NOT use preemptive compaction - see below.

### Reactive Compaction (Apple FM Only)

Apple FM's ~4K context window is too small for accurate character-based fill estimation. Instead, compaction is purely reactive:

1. Send message to `session.streamResponse()`
2. If `exceededContextWindowSize` is thrown, summarize conversation via a separate `LanguageModelSession`
3. Rebuild session with `Transcript.buildCompacted()` (instructions + note + summary)
4. Compact SwiftData messages (keep 2 most recent)
5. Retry the original message

See `documentation/Apple-FM-Chat-Integration.md` for full details on the synthesized transcript architecture.

### Manual Compaction

Users can trigger compaction via the overflow menu ("Compact Chat"). Uses the same summarization logic as auto/reactive compaction. Both Apple FM and cloud providers keep 2 most recent messages after manual compaction.

## Multi-Note Context Assembly

Multiple notes are wrapped in XML for AI disambiguation:

```xml
<NOTE id="1" title="Meeting notes from standup" date="Apr 10, 2026, 9:30 AM">
[raw transcription text]
</NOTE>

<NOTE id="2" title="Client call follow-up" date="Apr 9, 2026, 2:15 PM">
[raw transcription text]
</NOTE>
```

The system prompt instructs the AI to reference notes by title or number when responding. Only `transcription.text` (raw original) is used, not `enhancedText` or variations.

## Apple FM Session Management

Apple FM uses a stateful `LanguageModelSession` with synthesized `Transcript` entries for clean separation of instructions, note context, and conversation history. Sessions are persisted via JSON-encoded `Transcript` data stored on the conversation model.

For full details on session lifecycle, synthesized transcript architecture, prewarming, dual storage, and deferred persistence, see `documentation/Apple-FM-Chat-Integration.md`.

## Deferred Persistence Pattern

To prevent SwiftUI layout disruption during streaming, message persistence is deferred:

1. User taps send
2. `ChatMessage` created in memory, appended to `messages` array (immediate UI)
3. `modelContext.insert()` is NOT called yet
4. AI streaming happens
5. After response completes (or on cancel/error), both user and assistant messages are inserted into SwiftData
6. `trySave()` persists to disk

This avoids mutating the `@Model` conversation's relationships during streaming, which previously caused the scroll view to briefly blank out.

## Entry Points

### Single-Note Chat

- **Location:** Note detail screen, bottom action bar (bubble icon)
- **Flow:** `findOrCreateConversation(for:)` finds existing or creates new `ChatConversation`, then presents `ChatView` as sheet
- **Persistence:** Conversation reused on subsequent opens

### Multi-Note Chat (Chats List)

- **Location:** Main screen bottom toolbar (bubble icon, non-selection mode)
- **Flow:** Opens `MultiNoteChatsListView` as full screen cover. User can create new conversations or open existing ones.
- **Creation:** `MultiNoteCreationView` shows tag filter chips + selectable notes list with Select All toggle

### Multi-Note Chat (Selection Mode)

- **Location:** Main screen bottom toolbar (bubble icon, selection mode)
- **Flow:** Creates `MultiNoteConversation` with selected notes, exits selection mode, opens chat directly as sheet

## Cleanup

`ChatCleanupService` runs on app launch (throttled to once per 24 hours) and deletes conversations older than the configured retention period. Applies to both `ChatConversation` and `MultiNoteConversation`. Enabled via Settings > Storage > Auto-delete Chats (1/3/7/14/30 days).

Additionally, single-note conversations are cascade-deleted when their source Transcription is deleted (via auto-delete notes or manual deletion).

## UI Components

| Component | Shared | Used By |
|-----------|--------|---------|
| `ChatBubbleView` | Yes | Both chat types |
| `ChatInputBar` | Yes | Both (configurable placeholder) |
| `ChatView` | No | Single-note only |
| `MultiNoteChatView` | No | Multi-note only |
| `MultiNoteChatsListView` | No | Multi-note list |
| `MultiNoteCreationView` | No | Multi-note creation |

`ChatBubbleView` renders user messages (right-aligned, accent), assistant messages (left-aligned, gray, Markdown via `Text(.init())`), summary cards (centered, minimal), and error messages (red tint).

`ChatInputBar` accepts a configurable `placeholder` parameter (defaults to "Ask about this note..."; multi-note uses "Ask about these notes...").

## File Inventory

| File | Purpose |
|------|---------|
| `Models/ChatConversation.swift` | Single-note conversation model |
| `Models/ChatMessage.swift` | Shared message model (dual relationship) |
| `Models/MultiNoteConversation.swift` | Multi-note conversation model (self-contained, no junction) |
| `Services/AIEnhance/ChatContextManager.swift` | Single-note context assembly and limits |
| `Services/AIEnhance/MultiNoteContextManager.swift` | Multi-note context assembly with XML tags |
| `Services/AIEnhance/AIService+Chat.swift` | Provider routing for chat requests |
| `Services/AIEnhance/LanguageModelSession+Compacting.swift` | Apple FM transcript builders and compaction |
| `documentation/Apple-FM-Chat-Integration.md` | Detailed Apple FM chat integration docs |
| `Services/ChatCleanupService.swift` | Auto-delete old conversations |
| `Views/Chat/ChatViewModel.swift` | Single-note chat view model |
| `Views/Chat/ChatView.swift` | Single-note chat UI |
| `Views/Chat/ChatBubbleView.swift` | Message bubble (shared) |
| `Views/Chat/ChatInputBar.swift` | Text input bar (shared) |
| `Views/MultiNoteChat/MultiNoteChatViewModel.swift` | Multi-note chat view model |
| `Views/MultiNoteChat/MultiNoteChatView.swift` | Multi-note chat UI |
| `Views/MultiNoteChat/MultiNoteChatsListView.swift` | Multi-note conversations list |
| `Views/MultiNoteChat/MultiNoteChatsListViewModel.swift` | List view model |
| `Views/MultiNoteChat/MultiNoteCreationView.swift` | Note selection for new conversation |
