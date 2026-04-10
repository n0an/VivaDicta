# Apple Foundation Models - Chat Integration

## Overview

Apple Foundation Models (Apple FM) is the on-device AI provider available on iOS 26+. Unlike cloud providers that send a stateless message array per request, Apple FM uses a stateful `LanguageModelSession` that accumulates context in a `Transcript`. This document covers how the chat feature manages Apple FM sessions, constructs transcripts, handles persistence, and performs compaction.

## Key Differences from Cloud Providers

| Aspect | Cloud Providers | Apple FM |
|--------|----------------|----------|
| State | Stateless (full message array each request) | Stateful (`LanguageModelSession` persists context) |
| Context window | Large (128K-1M tokens) | Small (~4K tokens via `SystemLanguageModel.default.contextSize`) |
| Compaction trigger | Preemptive at 70% fill ratio | Reactive only (catch `exceededContextWindowSize`) |
| Session persistence | Not needed (rebuilt each request) | JSON-encoded `Transcript` stored in SwiftData |
| Message assembly | `ChatContextManager.assembleMessages()` builds `[[String: String]]` | Synthesized `Transcript` entries |

## Synthesized Transcript Architecture

Instead of stuffing all context into a single instructions string, the chat uses structured `Transcript` entries with clean separation of concerns.

### Entry Types

```
.instructions  - System prompt (chat personality, guidelines)
.prompt        - User message (note text, questions)
.response      - Model response (acknowledgments, answers, summaries)
```

Each entry contains `Transcript.Segment` values created via:
```swift
Transcript.TextSegment(content: "text here")  // creates a TextSegment
Transcript.Segment.text(textSegment)           // wraps in Segment enum
```

### Fresh Session Transcript

When a new chat starts (no saved transcript data):

```
[.instructions]  "You are a helpful AI assistant. The user is discussing..."
[.prompt]         "<NOTE>\n{note text}\n</NOTE>"
[.response]       "I've read your note. Ask me anything about it."
```

For multi-note chats, the prompt contains XML-wrapped notes and the acknowledgment references the note count:

```
[.instructions]  "You are a helpful AI assistant. The user is discussing multiple..."
[.prompt]         "<NOTE id="1" title="..." date="...">...</NOTE>\n<NOTE id="2"..."
[.response]       "I've read your 5 notes. Ask me anything about them."
```

Built via `Transcript.buildFresh()`:
```swift
let transcript = Transcript.buildFresh(
    instructions: ChatContextManager.chatSystemPrompt,
    notePrompt: "<NOTE>\n\(assembledNoteText)\n</NOTE>",
    noteAcknowledgment: "I've read your note. Ask me anything about it.",
    summary: existingSummary  // optional, from prior compaction
)
```

**Recovery fallback:** If `appleFMTranscriptData` is missing or corrupted but a compaction summary exists in SwiftData (a `ChatMessage` with `isSummary == true`), the fresh transcript includes it as an additional `.response` to preserve context:
```
[.instructions]  system prompt
[.prompt]         note text
[.response]       acknowledgment
[.response]       "Summary of our earlier conversation: {summary}"
```
The most common scenario for this is when the user switches from a cloud provider (e.g. Claude, GPT) to Apple FM mid-conversation - the chat has SwiftData messages but no `appleFMTranscriptData` yet.

### Compacted Session Transcript

After compaction, the transcript is rebuilt with just three entries:

```
[.instructions]  system prompt
[.prompt]         note text
[.response]       "{summary of entire conversation}"
```

Built via `Transcript.buildCompacted()`:
```swift
let transcript = Transcript.buildCompacted(
    instructions: ChatContextManager.chatSystemPrompt,
    notePrompt: appleFMNotePrompt,
    summary: summary
)
```

All prior conversation turns are replaced by a single summary response.

## Session Lifecycle

### 1. Initialization (`initializeAppleFMSession`)

Called during view model setup. Two paths:

**Restore from saved data:**
```swift
if let data = conversation.appleFMTranscriptData,
   let transcript = try? JSONDecoder().decode(Transcript.self, from: data) {
    let session = LanguageModelSession(transcript: transcript)
    session.prewarm()
    appleFMSession = session
}
```

**Create fresh:**
```swift
let transcript = Transcript.buildFresh(
    instructions: systemPrompt,
    notePrompt: noteText,
    noteAcknowledgment: "I've read your note...",
    summary: existingSummaryFromSwiftData
)
let session = LanguageModelSession(transcript: transcript)
session.prewarm()
appleFMSession = session
```

### 2. Prewarming

`session.prewarm()` is called immediately after session creation or restoration. This pre-loads the model and prepares the context for faster first response.

### 3. Sending Messages (`sendAppleFMMessageImpl`)

```swift
let options = GenerationOptions(
    sampling: .random(probabilityThreshold: 0.9),
    temperature: 0.7
)
let stream = session.streamResponse(to: text, options: options)
```

No preemptive compaction check. The runtime decides when context is exceeded.

### 4. Streaming Response (`streamAppleFMResponse`)

Iterates `session.streamResponse()` async sequence, updating `streamingText` for live UI. Triggers haptic feedback on stream start and each content increment. After streaming, applies `AIEnhancementOutputFilter.filter()` to clean output.

### 5. Saving Transcript (`saveAppleFMTranscript`)

After each successful response, the transcript is JSON-encoded and stored:

```swift
let data = try JSONEncoder().encode(session.transcript)
conversation.appleFMTranscriptData = data
```

This persists to SwiftData (and syncs via CloudKit), so reopening the chat restores the full session state.

### 6. Clearing Chat

On "Clear Chat", the transcript data is wiped and a fresh session is created:
```swift
conversation.appleFMTranscriptData = nil
initializeAppleFMSession()
```

## Compaction

### Why Reactive-Only for Apple FM

Apple FM's context window is ~4K tokens. Character-based token estimation (`estimateTokens()`) is too inaccurate at this scale - a few hundred characters of estimation error can mean the difference between 60% and 80% fill. Preemptive compaction at 70% was removed because:

1. Notes alone often consumed 50-70% of context
2. After compaction, even 2 kept messages pushed fill back above 70%
3. This created compaction loops where every message triggered compaction

Cloud providers (128K-1M tokens) still use preemptive compaction at 70% because estimation errors are negligible at that scale.

### Reactive Compaction Flow

When `session.streamResponse()` throws `exceededContextWindowSize`:

1. **Catch the error** in `sendAppleFMMessageImpl`
2. **Show compaction UI** (`isCompacting = true`)
3. **Summarize conversation** via `summarizeAndRebuildSession()`:
   - Extract all prompts/responses from current transcript
   - Create a separate `LanguageModelSession` with `ChatContextManager.compactionPrompt`
   - Generate summary with `maximumResponseTokens: 100`, `.greedy` sampling
   - Summary is first-person, 2-3 sentences ("we discussed", "you asked", "I suggested")
4. **Rebuild session** with `Transcript.buildCompacted()` (instructions + note + summary)
5. **Compact SwiftData** via `compactSwiftDataMessages()` (keep 2 most recent, delete rest)
6. **Retry the original message** against the rebuilt session

```swift
catch LanguageModelSession.GenerationError.exceededContextWindowSize {
    isCompacting = true
    session = try await summarizeAndRebuildSession(session, label: "single-note")
    appleFMSession = session
    compactSwiftDataMessages()
    isCompacting = false

    // Retry with compacted session
    let result = try await streamAppleFMResponse(session: session, text: text, options: options)
    saveAppleFMTranscript()
    return result
}
```

### Manual (Force) Compaction

Users can trigger compaction via the overflow menu. Uses the same summarization logic:

1. Extract conversation from transcript
2. Summarize with separate session (`maximumResponseTokens: 100`)
3. Rebuild with `Transcript.buildCompacted()`
4. Compact SwiftData messages (`keepCount: 2`)
5. Save transcript and persist

### Compaction Prompt

Both reactive and manual compaction use the same prompt:

```
You are summarizing a conversation you had with a user. Write in first person
as the assistant recalling what was discussed. Use "we discussed", "you asked",
"I suggested" etc. Summarize in 2-3 sentences maximum. Only preserve the most
important facts and decisions. Be extremely concise.
```

### SwiftData Message Cleanup

After compaction, `compactSwiftDataMessages()` keeps only the 2 most recent non-summary messages. All older messages and any existing summary message are deleted. A new summary `ChatMessage` (role: "summary", `isSummary: true`) is inserted as a visual indicator.

## Dual Storage Architecture

Apple FM chat maintains two parallel stores:

| Store | Purpose | Content |
|-------|---------|---------|
| `LanguageModelSession.transcript` | Model context | Full conversation including synthesized entries |
| SwiftData `ChatMessage` records | UI display + CloudKit sync | User/assistant messages + summary indicators |

These are kept in sync:
- After each response: transcript saved to `appleFMTranscriptData`
- After compaction: both transcript rebuilt and SwiftData messages compacted
- On restore: transcript decoded from `appleFMTranscriptData`, SwiftData messages loaded for UI

## Deferred Persistence Pattern

To prevent SwiftUI layout disruption during Apple FM streaming:

1. User message created as in-memory `ChatMessage`, appended to `messages` array
2. `modelContext.insert()` is NOT called yet (avoids @Model mutation during layout)
3. Streaming happens with live `streamingText` updates
4. `pendingUserMessage` tracks the deferred message across `loadMessages()` calls
5. After streaming completes: both user and assistant messages inserted into SwiftData
6. `trySave()` persists to disk

This is critical because `modelContext.insert()` mutates the conversation's `messages` relationship, which can trigger SwiftUI layout recalculation and cause the scroll view to blank out mid-stream.

## Availability Guards

Apple FM requires iOS 26+. The session is stored as `Any?` to avoid `@available` on the property:

```swift
/// LanguageModelSession stored type-erased for iOS version compatibility.
private var appleFMSession: Any?
```

All Apple FM code paths use `@available(iOS 26, *)` guards and `if #available(iOS 26, *)` checks.

## File References

| File | Apple FM Relevance |
|------|--------------------|
| `LanguageModelSession+Compacting.swift` | `Transcript.buildFresh()`, `buildCompacted()`, `getMessages()`, `logTranscript()` |
| `ChatViewModel.swift` | Single-note: session init, send, stream, compact, save |
| `MultiNoteChatViewModel.swift` | Multi-note: same patterns, different system prompt and note assembly |
| `ChatContextManager.swift` | `chatSystemPrompt`, `compactionPrompt`, `estimateTokens()`, `contextLimit()` |
| `MultiNoteContextManager.swift` | `systemPrompt`, `assembleNoteText()` for multi-note XML |
