# Cross-Note Search

## Overview

Cross-note search lets a chat turn pull evidence from other notes outside the note (or notes) already in the chat context.

It exists in two shapes:

- **Explicit cross-note search** - the user arms the "Search other notes" icon for one turn before sending. The planner runs first, then local RAG, then the final answer uses the augmented prompt.
- **Implicit cross-note search** - only runs when the user did not arm any search for this turn. Apple FM can invoke the `NotesSearchTool` directly mid-generation. Cloud providers use a non-streaming tool-decision helper that returns a query the app then runs itself.

Both shapes share:

- the same local RAG retrieval path (`NotesSearchToolRuntime.searchNotesPayload`)
- the same `<OTHER_NOTES_SEARCH_RESULTS>` prompt envelope built by `ChatCrossNoteContextManager`
- the same exclusion of notes already in the current chat context
- up to 4 note results, one chunk excerpt per note

Cross-note search is RAG-only. There is no keyword fallback, no SwiftData predicate search, no search over `enhancedText` or variations.

## Surfaces

| Surface | Explicit | Implicit (Apple FM) | Implicit (Cloud) |
|---|---|---|---|
| Single-note chat (`ChatView`) | Yes | Yes - when `CrossNoteSearchToolFeature` is on | Yes - when `CrossNoteSearchToolFeature` is on |
| Multi-note chat (`MultiNoteChatView`) | Yes | Yes - same feature flag | Yes - same feature flag |
| Smart Search chat (`SmartSearchChatView`) | No - Smart Search has its own RAG flow | No | No |

Smart Search chat always runs its own planner-first RAG, so the notion of "armed cross-note search" does not apply there.

## Arming UX

When `SmartSearchFeature.isEnabled` is true, the input row in single-note and multi-note chat shows a `Search other notes` icon (`magnifyingglass` in the `ChatInputBar`).

Behavior:

- tap once to arm cross-note search for the next send
- arming cross-note search disarms web search (they are mutually exclusive for a turn)
- send the message - the app runs planner -> RAG -> augmented prompt -> final answer
- armed state resets immediately after send

If Smart Search is disabled the icon is hidden and the feature cannot be armed.

## Feature Gates

- `SmartSearchFeature.isEnabled` - master switch. Required for any cross-note retrieval, explicit or implicit. When off, `NotesSearchToolRuntime.searchNotesPayload` returns an `error` status with an "unavailable" message.
- `CrossNoteSearchToolFeature.isEnabled` - gates the implicit variant only. Explicit arming does not consult this flag.
- ExaAPIKeyManager.isConfigured - not required for cross-note search. Only web search depends on it.

## Explicit Path

### Flow

```text
User arms "Search other notes"
        │
        ▼
User sends message
        │
        ▼
makeCrossNoteSearchContext(...)
        │
        ▼
CrossNoteSearchPlanner.makePlan(...)
   inputs:
   - latestUserMessage
   - recentMessages (up to 4, non-summary)
   - noteText (current note or assembled multi-note context)
        │
        ▼
Planner output: { shouldSearch, searchQuery, reasoning }
        │
        ├─ planner failed          -> planner-unavailable block, no RAG
        ├─ shouldSearch=false      -> no-query-inferred block, no RAG
        └─ shouldSearch=true
                │
                ▼
       NotesSearchToolRuntime.searchNotesPayload(query: plannedQuery, excluding: ...)
                │
                ▼
       RAGIndexingService.shared.search(query: plannedQuery, topK: 8)
                │
                ▼
       Filter excluded notes, resolve Transcription, keep up to 4
                │
                ▼
       ChatCrossNoteContextManager.assembleAugmentedPrompt(...)
                │
                ▼
       Final answer: Apple FM main session OR cloud streaming request
                │
                ▼
       Persist assistant message with sourceTranscriptionIds + sourceCitations
```

### Planner Inputs

`CrossNoteSearchPlanner.makePlan` takes:

- `latestUserMessage` - the text just sent
- `recentMessages` - up to 4 prior non-summary messages, via `plannerMessagesForCrossNoteSearch()`
- `noteText` - the current note text (`transcription.text` for single-note, `conversation.noteContext` for multi-note)

That means the planner context window is **current message + up to 4 previous + full current-note context**.

### Planner Payload

Plain text with labeled sections, identical for Apple FM prompt builder and cloud user message:

```text
LATEST USER MESSAGE:
...

RECENT CHAT:
User: ...
Assistant: ...

CURRENT NOTE:
...
```

For multi-note chat, `CURRENT NOTE` is the assembled `<NOTE id="..." title="..." date="...">` blocks.

### Planner Output

```json
{
  "shouldSearch": true,
  "searchQuery": "apple frameworks",
  "reasoning": "brief explanation"
}
```

Apple FM uses `@Generable` structured output (`CrossNoteSearchPlanSchema`) with `.greedy` sampling - no JSON parsing needed.

Cloud path sends the planner prompt through `AIService.makeChatRequest(...)` (non-streaming), then decodes the returned JSON. An `extractJSONObject` helper tolerates stray prose around the braces.

### Query Normalization

After the planner returns, `normalize(_:)` does:

- trim whitespace
- split on whitespace and rejoin with single spaces (collapses newlines, tabs, runs)
- cap to 80 characters
- if the normalized query is empty, `shouldSearch` is forced to `false`

### Exclusions

- **Single-note chat** excludes the current `transcription.id`
- **Multi-note chat** excludes every source note already in `conversation`

This prevents the feature from surfacing notes that are already in the chat context.

### What Goes Into the Final Prompt

`ChatCrossNoteContextManager.assembleAugmentedPrompt(query:plannedQuery:payload:)` wraps results in:

```text
<OTHER_NOTES_SEARCH_RESULTS>
Focused search query used for other notes: apple frameworks

The following excerpts come from other notes outside the notes already in this chat context.

OTHER NOTE 1
Title: ...
Date: ...
Excerpt:
...

OTHER NOTE 2
Title: ...
Date: ...
Excerpt:
...
</OTHER_NOTES_SEARCH_RESULTS>

USER QUESTION:
<original user question>
```

Injection rules:

- up to 4 notes total
- one chunk excerpt per note (never multiple chunks, never the full note text)
- excerpt is derived from the best-scoring RAG chunk for that note and flattened to at most 180 characters

Empty-result variant (planner ran, RAG found nothing):

```text
<OTHER_NOTES_SEARCH_RESULTS>
Focused search query used for other notes: apple frameworks

No relevant other notes were found outside the notes already in this chat context.
</OTHER_NOTES_SEARCH_RESULTS>

USER QUESTION:
<original user question>
```

Planner-unavailable variant (planner failed or decided no-search):

```text
<OTHER_NOTES_SEARCH_RESULTS>
<explanatory message>
</OTHER_NOTES_SEARCH_RESULTS>

USER QUESTION:
<original user question>
```

## Implicit Path

Implicit cross-note search only runs when the user did **not** arm explicit search **and** did not arm web search for this turn (`allowImplicitTools = !shouldSearchOtherNotes && !shouldSearchWeb`).

### Apple Foundation Models

Apple FM uses native `Tool` objects. When `CrossNoteSearchToolFeature.isEnabled` and `SmartSearchFeature.isEnabled`, `ChatViewModel.appleFMTools(includeImplicitCrossNoteSearch: true)` attaches a `NotesSearchTool` to the session.

Flow:

1. Session receives the user prompt plus the note context it already holds
2. The model may call `searchOtherNotes(query:)` mid-generation when it judges the user is asking about other notes
3. `NotesSearchTool.call(...)` runs `NotesSearchToolRuntime.searchNotesPayload(...)` with the model's query and the excluded note ids (current note for single-note chat, all source notes for multi-note chat)
4. Results are returned as `GeneratedContent` for the model to incorporate
5. Captured citations are merged into the assistant message via `NotesSearchToolRuntime.consumeCapturedCitations(for:)`

The `NotesSearchTool.description` string is deliberately strict - it tells the model to use the tool only when the user explicitly asks about other notes and never for summarizing or explaining the current note. This is intentional: weaker models tend to over-invoke this tool.

### Cloud Providers

Cloud providers do not receive Apple-style `Tool` objects. Instead, `makeImplicitCloudCrossNoteSearchContext(...)` runs after the primary response path would normally start:

1. Non-streaming tool-decision request via `AIService.makeCrossNoteSearchToolDecision(provider:model:systemMessage:messages:)`
2. That helper routes to either `makeAnthropicCrossNoteSearchToolDecision` or `makeOpenAICrossNoteSearchToolDecision`, which ask the model whether it wants to search other notes and, if yes, what query
3. If the helper returns a non-nil `plannedQuery`, the app calls `NotesSearchToolRuntime.searchNotesPayload(...)` itself
4. The app rebuilds the prompt via `ChatCrossNoteContextManager.assembleAugmentedPrompt(...)` and sends a fresh streaming request with the augmented user message

So for cloud, "implicit" still means:

- one non-streaming tool-decision helper call
- app-controlled RAG
- one final streaming answer request with the augmented prompt

It is **not** true provider-side function calling in a single round-trip.

### Citation Merging

The final assistant message gets sources merged from both paths:

- `mergedSourceIDs(explicit:implicit:)` unions `transcriptionId`s
- `mergeSourceCitations(explicit:implicit:)` keeps the highest-scoring citation per note
- `didUseCrossNoteSearchTool` is set to `true` if either explicit or implicit produced results

## RAG Retrieval Contract

`NotesSearchToolRuntime.searchNotesPayload(query:excluding:)`:

- validates non-empty query
- short-circuits with an `error` payload if `SmartSearchFeature` is disabled or the model container is missing
- calls `RAGIndexingService.shared.search(query:topK:)` with `topK = maxResults * 2 = 8`
- filters results by `excludedIDs`
- resolves each `transcriptionId` back to a `Transcription` via a `FetchDescriptor` predicate
- builds `CrossNoteSearchResult` with title (first line, up to 50 chars), abbreviated date, and a flattened 180-char excerpt preview
- caps at 4 final results

`RAGIndexingService.shared.search(...)`:

- runs semantic vector search over chunks via LumoKit/VecturaKit
- threshold: `0.25`
- over-fetches `topK * 2`
- keeps the highest-scoring chunk per transcription id
- returns up to `topK` `RAGSearchResult`s

There is no lexical reranking, no keyword boost, no hybrid merge inside cross-note search.

## Apple vs Cloud Execution Model

### Explicit, Apple FM

```text
Temporary planner LanguageModelSession (greedy)
        │
        ▼
Local RAG via NotesSearchToolRuntime
        │
        ▼
Persistent main chat LanguageModelSession receives the augmented prompt
```

The planner session is disposable and never touches the main chat transcript. The main session keeps its full conversation transcript and appends the augmented turn normally.

### Explicit, Cloud

```text
Non-streaming AIService.makeChatRequest (planner prompt)
        │
        ▼
Local RAG via NotesSearchToolRuntime
        │
        ▼
Streaming AIService.makeChatStreamingRequest (augmented prompt + full message history)
```

No provider-side session state - continuity comes from the explicit message array sent on each turn.

### Implicit, Apple FM

Single LanguageModelSession with `NotesSearchTool` attached. The tool may fire zero, one, or more times during one turn.

### Implicit, Cloud

Two sequential HTTP requests per turn: non-streaming tool-decision helper -> streaming final answer.

## Failure and Empty Cases

| Case | Runtime status | Prompt envelope |
|---|---|---|
| Planner failed (network, decode) | n/a | planner-unavailable block, no RAG |
| Planner said `shouldSearch: false` | n/a | no-query-inferred block, no RAG |
| RAG returned 0 hits | `empty` | `<OTHER_NOTES_SEARCH_RESULTS>` with "No relevant other notes were found..." |
| RAG hit notes but all were excluded | `empty` | same empty block |
| `SmartSearchFeature` disabled | `error` (runtime) | caller discards and aborts search; final prompt uses raw user text |
| Missing model container | `error` | same |

Even on empty or planner-missing cases, the final model still answers the original question. The envelope just makes clear no evidence was found.

## Logs

Search this in Console with category `chatViewModel` or `ragSearch`:

- `Cross-note planner provider=... shouldSearch=... query='...'`
- `Chat - Cross-note search found N note matches for plannedQuery='...'`
- `Chat - Cloud implicit cross-note tool provider=... plannedQuery='...'`
- `Cross-note search start query='...' excludedNotes=N smartEnabled=true`
- `Apple FM cross-note tool invoked query='...'` (implicit Apple FM path)

## Key Files

- [VivaDicta/Views/Chat/ChatViewModel.swift](../../VivaDicta/Views/Chat/ChatViewModel.swift)
- [VivaDicta/Views/MultiNoteChat/MultiNoteChatViewModel.swift](../../VivaDicta/Views/MultiNoteChat/MultiNoteChatViewModel.swift)
- [VivaDicta/Services/AIEnhance/CrossNoteSearchPlanner.swift](../../VivaDicta/Services/AIEnhance/CrossNoteSearchPlanner.swift)
- [VivaDicta/Services/AIEnhance/NotesSearchTool.swift](../../VivaDicta/Services/AIEnhance/NotesSearchTool.swift)
- [VivaDicta/Services/AIEnhance/ChatCrossNoteContextManager.swift](../../VivaDicta/Services/AIEnhance/ChatCrossNoteContextManager.swift)
- [VivaDicta/Services/AIEnhance/AIService+Chat.swift](../../VivaDicta/Services/AIEnhance/AIService+Chat.swift)
- [VivaDicta/Services/AIEnhance/CrossNoteSearchToolFeature.swift](../../VivaDicta/Services/AIEnhance/CrossNoteSearchToolFeature.swift)
- [VivaDicta/Services/RAG/RAGIndexingService.swift](../../VivaDicta/Services/RAG/RAGIndexingService.swift)
