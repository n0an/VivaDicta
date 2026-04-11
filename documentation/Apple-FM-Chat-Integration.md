# Apple Foundation Models - Chat Integration

## Overview

Apple Foundation Models (Apple FM) is the on-device AI provider available on iOS 26+. Unlike cloud providers that send a stateless message array per request, Apple FM uses a stateful `LanguageModelSession` that accumulates context in a `Transcript`. This document covers how the chat feature manages Apple FM sessions, constructs transcripts, handles persistence, performs compaction, and integrates tool calling.

## Key Differences from Cloud Providers

| Aspect | Cloud Providers | Apple FM |
|--------|----------------|----------|
| State | Stateless (full message array each request) | Stateful (`LanguageModelSession` persists context) |
| Context window | Large (128K-1M tokens) | Small (~4K tokens via `SystemLanguageModel.default.contextSize`) |
| Compaction trigger | Preemptive at 70% fill ratio | Reactive only (catch `exceededContextWindowSize`) |
| Session persistence | Not needed (rebuilt each request) | JSON-encoded `Transcript` stored in SwiftData |
| Message assembly | `ChatContextManager.assembleMessages()` builds `[[String: String]]` | Synthesized `Transcript` entries |
| Tool calling | Not supported | `ExaWebSearchTool` via `Tool` protocol |
| Guardrails | N/A (provider-side moderation) | `permissiveContentTransformations` |

## Model Configuration

### Guardrails

All chat sessions use `permissiveContentTransformations` guardrails, which allows less restrictive content transformation - important for a transcription app where users dictate real-world content (medical terms, legal language, etc.):

```swift
private var appleFMModel: SystemLanguageModel {
    SystemLanguageModel(guardrails: .permissiveContentTransformations)
}
```

### Generation Options (Sampling Parameters)

Chat responses use nucleus sampling (top-p) with temperature:

```swift
let options = GenerationOptions(
    sampling: .random(probabilityThreshold: 0.9),  // top-p: consider tokens until 90% cumulative probability
    temperature: 0.7                                // moderate creativity, balanced coherence
)
```

| Parameter | Value | Effect |
|-----------|-------|--------|
| `probabilityThreshold` (top-p) | 0.9 | Nucleus sampling - considers the smallest set of tokens whose cumulative probability reaches 90%. Filters out low-probability tokens while keeping variety. |
| `temperature` | 0.7 | Scales the probability distribution before sampling. 0.0 = deterministic, 1.0 = maximum randomness. 0.7 balances creativity with coherence. |

**Compaction summarization** uses different options for consistent, focused summaries:

```swift
GenerationOptions(sampling: .greedy, maximumResponseTokens: 100)
```

- `.greedy` = always pick the highest-probability token (deterministic, no randomness)
- `maximumResponseTokens: 100` = hard stop at 100 tokens to keep summaries concise

## Tool Calling

### Exa Web Search Tool

When configured with an Exa API key (Settings > Chat Tools), the model can autonomously search the web during chat. This is implemented via Apple FM's `Tool` protocol.

```swift
struct ExaWebSearchTool: Tool {
    let name = "searchWeb"
    let description = "Search the web for current information..."

    @Generable
    struct Arguments: Sendable {
        @Guide(description: "The search query to look up on the web")
        var query: String
    }

    func call(arguments: Arguments) async throws -> some PromptRepresentable { ... }
}
```

**How it works:**
1. The model reads the user's question and decides if web search would help
2. It generates a `searchWeb` tool call with a search query
3. `ExaWebSearchTool.call()` sends a POST to `https://api.exa.ai/search`
4. Results (up to 5, with 500-char text snippets) are returned as `GeneratedContent`
5. The model incorporates the search results into its response

**Wiring:** Tools are passed to every `LanguageModelSession` creation:

```swift
private var appleFMTools: [any Tool] {
    guard let key = ExaAPIKeyManager.apiKey, !key.isEmpty else { return [] }
    return [ExaWebSearchTool(apiKey: key)]
}

let session = LanguageModelSession(model: appleFMModel, tools: appleFMTools, transcript: transcript)
```

If no Exa API key is configured, `appleFMTools` returns an empty array and no tools are available.

**API key storage:** Exa API key is stored in Keychain via `ExaAPIKeyManager` (iCloud Keychain synced). Configured in Settings > AI Processing > Chat Tools.

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
    let session = LanguageModelSession(model: appleFMModel, tools: appleFMTools, transcript: transcript)
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
let session = LanguageModelSession(model: appleFMModel, tools: appleFMTools, transcript: transcript)
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

Apple FM uses **snapshot-based streaming** (not token deltas) - each iteration yields the complete response text so far, so `streamingText = content` assigns directly without accumulation.

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

## Context Overflow Protection

### Note Size Check

Before opening an Apple FM chat, the note size is checked against the context window. Uses a two-tier approach:

1. **Synchronous estimate (init):** Character-based heuristic with 0.80 threshold (note + system prompt must be under 80% of context)
2. **Async refinement (iOS 26.4+):** Real `tokenCount(for:)` API with 0.80 threshold. If the sync estimate was too conservative and the note actually fits, the error is cleared and the session is initialized.

```swift
private static func estimateNoteExceedsAppleFM(noteText: String, systemPrompt: String) -> Bool {
    let noteTokens = ChatContextManager.estimateTokens(noteText)
    let systemTokens = ChatContextManager.estimateTokens(systemPrompt)
    let limit = ChatContextManager.contextLimit(for: .apple, model: "foundation-model")
    return (noteTokens + systemTokens) > Int(Double(limit) * 0.80)
}
```

### Context Fill Ratio

The context usage indicator in the chat header uses:
- **iOS 26.4+:** Real `SystemLanguageModel.default.tokenCount(for:)` against `SystemLanguageModel.default.contextSize`
- **iOS 26.0-26.3:** Character-based estimation via `ChatContextManager.fillRatio()`

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

## Error Handling

| Error | Handling |
|-------|----------|
| `exceededContextWindowSize` | Reactive compaction: summarize, rebuild, retry |
| `guardrailViolation` | Show "Content was blocked by safety guidelines" |
| `CancellationError` | Save partial response if any streaming text received |
| Other `GenerationError` | Show localized error description |

## Availability Guards

Apple FM requires iOS 26+. The session is stored as `Any?` to avoid `@available` on the property:

```swift
/// LanguageModelSession stored type-erased for iOS version compatibility.
private var appleFMSession: Any?
```

All Apple FM code paths use `@available(iOS 26, *)` guards and `if #available(iOS 26, *)` checks. Real token counting requires iOS 26.4+ (`if #available(iOS 26.4, *)`).

## File References

| File | Apple FM Relevance |
|------|--------------------|
| `LanguageModelSession+Compacting.swift` | `Transcript.buildFresh()`, `buildCompacted()`, `getMessages()`, `logTranscript()` |
| `ChatViewModel.swift` | Single-note: session init, send, stream, compact, save, tools |
| `MultiNoteChatViewModel.swift` | Multi-note: same patterns, different system prompt and note assembly |
| `ChatContextManager.swift` | `chatSystemPrompt`, `compactionPrompt`, `estimateTokens()`, `contextLimit()` |
| `MultiNoteContextManager.swift` | `systemPrompt`, `assembleNoteText()` for multi-note XML |
| `ExaWebSearchTool.swift` | Exa web search `Tool` implementation + `ExaAPIKeyManager` |
