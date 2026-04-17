# Smart Chat (Smart Search Chat)

## Overview

Smart Chat is VivaDicta's third chat mode, alongside single-note and multi-note chat. It does not start with a fixed note set in context. Instead, for every user turn it:

1. Plans a focused retrieval query from the latest message and recent chat.
2. Runs local RAG search against the note index.
3. Injects the matched note excerpts into the final answer prompt.
4. Answers via Apple FM or a cloud provider.

This document is the detailed operational view. For the architecture-level write-up covering chunking configuration, embedder choice, and injection rationale, see [Smart-Search-RAG-Architecture.md](../RAG/Smart-Search-RAG-Architecture.md).

## Entry Point

- Surface: `SmartSearchChatView`
- Opened from: main screen Smart Search icon (top-leading) -> starts or resumes a `SmartSearchConversation`
- Gate: `SmartSearchFeature.isEnabled` must be true. When disabled the entry point is hidden and no RAG search runs anywhere in the app.

## Models

- `SmartSearchConversation` (SwiftData) - stores title, `createdAt`, optional `appleFMTranscriptData`, messages relationship
- `ChatMessage` - shared message model (role, content, ai provider/model, estimated token count, source ids, citations)
- `SmartSearchSourceCitation` - `transcriptionId`, `excerpt`, `relevanceScore` - rendered as citation pills below assistant messages

There is no persisted note context at conversation level. Every turn retrieves its own context.

## Turn Flow

```text
User sends message
        │
        ▼
SmartSearchChatViewModel.sendMessage()
   - validate provider/model ready
   - append pending user ChatMessage (in-memory, deferred insert)
   - set isStreaming = true
        │
        ▼
makePlannedSearchQuery(for: text, provider:, model:)
   - SmartSearchQueryPlanner.makePlan(...)
   - inputs: latestUserMessage + up to 4 recent non-summary messages
   - no note text at planning time (unlike cross-note planner)
   - output: shouldSearch + plannedQuery, or falls back to raw text
        │
        ▼
RAGIndexingService.shared.search(query: plannedQuery, topK: N)
   - topK = 3 for Apple FM, 5 for cloud
   - threshold = 0.25
        │
  ┌─────┴─────┐
  │           │
  ▼           ▼
0 results   hits
  │           │
  ▼           ▼
deterministic   SmartSearchContextManager.assembleAugmentedPrompt(
no-evidence        query:, plannedQuery:, searchResults:, transcriptions:)
reply             (only if planner query was substantive)
  │           │
  │           ▼
  │       Apple FM main session OR cloud streaming request
  │           │
  └───────────┼──────────┐
              │          │
              ▼          ▼
       persistSuccessfulTurn(...):
       - insert user + assistant ChatMessage
       - save sourceIds and citations
       - didUseWebSearchTool flag
```

## Planner

`SmartSearchQueryPlanner.makePlan(aiService:provider:model:recentMessages:latestUserMessage:)`

### Inputs

- `latestUserMessage`
- `recentMessages` - up to 4 prior non-summary chat messages (`plannerMessagesForSmartSearch()` = drop last, filter non-summary, suffix 4)

Notably: **no note text is passed to the planner**. Smart Chat has no fixed note context, so the planner only sees the chat so far.

### Payload Shape

```text
LATEST USER MESSAGE:
...

RECENT CHAT:
User: ...
Assistant: ...
```

### Output (structured)

```json
{
  "shouldSearch": true,
  "searchQuery": "apple frameworks iOS macOS",
  "reasoning": "brief explanation"
}
```

Apple path: `@Generable SmartSearchQueryPlanSchema` with `.greedy` sampling.
Cloud path: non-streaming `AIService.makeChatRequest(...)`, then `extractJSONObject` + JSON decode.

### Normalization

- trim
- split on whitespace, rejoin with single spaces
- cap at 80 chars
- empty -> treated as unusable

### Fallback

If the planner is unavailable or returns `shouldSearch: false`, `makePlannedSearchQuery` returns the original raw user message as the retrieval query.

## RAG Retrieval

`RAGIndexingService.shared.search(query:topK:)`:

- semantic vector search over chunks via LumoKit/VecturaKit
- embedder: `SwiftEmbedder` with `minishlab/potion-base-32M`
- chunking: semantic strategy, `chunkSize = 500`, `overlapPercentage = 0.15`
- threshold: `0.25` (below which results are rejected)
- over-fetches `topK * 2` raw chunk hits
- keeps the highest-scoring chunk per transcription id
- returns up to `topK` `RAGSearchResult { transcriptionId, chunkText, relevanceScore }`

Indexing is done against `transcription.text` only - never `enhancedText` or variations, to avoid biasing retrieval toward shortened or stylistic rewrites.

## Deterministic No-Evidence Path

If RAG returns no hits **and** the planned query has substantive grounded terms (`groundedQueryTerms(from:)` strips stopwords and returns remaining tokens):

- the app skips the LLM call entirely
- returns a deterministic string:
  - English: `I could not find a reliable mention of that in your notes.`
  - Russian: `Я не нашел надежного упоминания этого в ваших заметках.`
- persists as a regular assistant message, no citations

This exists because grounding the model with nothing tends to produce fabricated or overconfident replies. For genuinely note-anchored queries, the deterministic path is safer than hoping the model will say "I don't know".

For weak/empty planner outputs (no substantive terms after stripping stopwords), the raw-query fallback path is still used and the model answers naturally without forced no-evidence framing.

## Prompt Assembly

`SmartSearchContextManager.assembleAugmentedPrompt(query:plannedQuery:searchResults:transcriptions:)`

When `plannedQuery` differs from the raw query (case/diacritic-insensitive), a focused-query section is included. Otherwise it's omitted.

```text
Here are relevant excerpts from the user's notes:

Focused retrieval query used for note search:
apple frameworks iOS macOS

SOURCE 1
Title: <first line, 60 chars>
Date: <abbreviated date, shortened time>
Excerpt:
<raw chunk text, trimmed>

SOURCE 2
Title: ...
Date: ...
Excerpt:
...

USER QUESTION:
<original user message>
```

Injection rules:

- one excerpt per returned note (the best-scoring chunk from RAG)
- never full note text
- up to `topK` notes (3 Apple FM / 5 cloud)
- chunk text is used verbatim, only trimmed

## System Prompt

Apple FM sessions use `SmartSearchContextManager.systemPrompt` as the instructions. Cloud requests send it as the system message on every turn.

Key rules in the prompt:

- answer using the provided note context
- reference notes by title or date when citing
- if notes don't cover the question, say so clearly
- don't mention prompt structure or source numbering
- don't fabricate

## Apple FM vs Cloud Execution

### Apple Foundation Models

```text
SmartSearchQueryPlanner (temporary LanguageModelSession, greedy)
        │
        ▼
RAGIndexingService.shared.search(...)
        │
        ▼
Persistent Smart Search LanguageModelSession
   - initialized with systemPrompt as instructions (no fixed note)
   - tools = [ExaWebSearchTool] when Exa key is configured
   - receives augmentedPrompt as the user turn
   - streams response; transcript is encoded and saved per turn
```

The planner session is disposable and never writes into the main transcript. The main session retains the full conversation across turns.

Reactive compaction: if `streamAppleFMResponse` throws `exceededContextWindowSize`, `summarizeAndRebuildSession(...)` builds a summary via a separate `LanguageModelSession(instructions: ChatContextManager.compactionPrompt)` (greedy, max 100 tokens), rebuilds a fresh session via `Transcript.buildCompactedFromInstructions` (no fixed note), compacts SwiftData messages keeping 2 most recent, and retries.

Apple FM chat uses `GenerationOptions(sampling: .random(probabilityThreshold: 0.9), temperature: 0.7)`.

### Cloud Providers

```text
SmartSearchQueryPlanner (non-streaming AIService.makeChatRequest)
        │
        ▼
RAGIndexingService.shared.search(...)
        │
        ▼
sendCloudMessage(augmentedPrompt, ...) - streaming chat request
   - systemMessage = SmartSearchContextManager.systemPrompt
   - messages = prior non-pending chat history + the augmented user turn
   - continuity comes from the message array, not provider-side session state
```

No cloud provider tool calls are made here - only Apple FM gets the native `ExaWebSearchTool`. Cloud-side web search in Smart Chat is therefore unavailable today.

## Web Search in Smart Chat

Only Apple FM. `appleFMTools` returns `[ExaWebSearchTool]` when `ExaAPIKeyManager.apiKey` is present. The model may invoke it mid-generation. Invocation is captured via `ExaWebSearchToolRuntime.beginCapture(for: captureID)` + `consumeDidInvoke(for:)`, and the resulting flag is persisted on the assistant message as `didUseWebSearchTool`.

There is no arming UX for web search in Smart Chat and no `WebSearchPlanner` path. The tool description in `ExaWebSearchTool` instructs the model to call it only for current facts or explicit lookups - not for answering note-grounded questions.

## Context Window

- Apple FM: reactive compaction only. `GenerationOptions` has no hard cap. iOS 26.4+ uses real `tokenCount(for:)` for fill ratio; older versions fall back to character estimation.
- Cloud: `SmartSearchContextManager.fillRatio(...)` estimates from recent messages. No preemptive compaction is implemented for cloud Smart Chat (see `performCompaction` for manual path).

## Citations

Every assistant message stores:

- `sourceTranscriptionIds` - deduplicated ids of notes used in this turn
- `sourceCitations` - array of `SmartSearchSourceCitation { transcriptionId, excerpt, relevanceScore }`
- `didUseWebSearchTool` - bool flag

`ChatBubbleView` renders citation pills below the bubble. Tapping a pill navigates to the source note.

## Failure Cases

| Case | Handling |
|---|---|
| Provider not configured | `errorMessage` set, turn aborted |
| Planner unavailable | raw user text used as retrieval query |
| RAG returns zero, query is substantive | deterministic no-evidence reply |
| RAG returns zero, query is weak | raw-query fallback, model answers naturally |
| Apple FM context exceeded | reactive summarize + rebuild + retry |
| Apple FM guardrail violation | typed error surfaced to user |
| Cancellation | partial response saved via `savePartialResponse(...)` |

## Key Files

- [VivaDicta/Views/SmartSearch/SmartSearchChatViewModel.swift](../../VivaDicta/Views/SmartSearch/SmartSearchChatViewModel.swift)
- [VivaDicta/Views/SmartSearch/SmartSearchChatView.swift](../../VivaDicta/Views/SmartSearch/SmartSearchChatView.swift)
- [VivaDicta/Views/SmartSearch/SmartSearchContextManager.swift](../../VivaDicta/Views/SmartSearch/SmartSearchContextManager.swift)
- [VivaDicta/Services/AIEnhance/SmartSearchQueryPlanner.swift](../../VivaDicta/Services/AIEnhance/SmartSearchQueryPlanner.swift)
- [VivaDicta/Services/AIEnhance/ExaWebSearchTool.swift](../../VivaDicta/Services/AIEnhance/ExaWebSearchTool.swift)
- [VivaDicta/Services/RAG/RAGIndexingService.swift](../../VivaDicta/Services/RAG/RAGIndexingService.swift)
- [VivaDicta/Models/SmartSearchConversation.swift](../../VivaDicta/Models/SmartSearchConversation.swift)
