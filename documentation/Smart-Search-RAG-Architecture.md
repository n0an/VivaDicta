# Smart Search RAG Architecture

## Overview

Smart Search is VivaDicta's retrieval-augmented chat mode for searching across the user's notes.

Unlike single-note chat and multi-note chat, Smart Search does not start with a fixed note set in context.

Instead, for every submitted user turn it now does:

1. Planner derives a focused retrieval query from the latest message plus recent chat context.
2. Local RAG searches the note index with that planned query.
3. Matching note chunks are injected into the final prompt.
4. The final model answers with note-grounded context.

The same local RAG index also powers the Smart mode in the main notes search surface.

## Current Setup

- chunking and indexing via `LumoKit`
- vector search via `VecturaKit`
- embeddings via `SwiftEmbedder`
- embedding model: `minishlab/potion-base-32M`
- chunking: semantic, `chunkSize = 500`, `overlap = 15%`
- runtime retrieval threshold: `0.25`
- retrieval path: planner-first, RAG-only
- no app-side lexical reranking
- prompt injection: chunk excerpts, not full notes

## High-Level Architecture

```text
┌──────────────────────────────────────────────────────────────────────────┐
│                           Smart Search Chat                             │
│                                                                          │
│  SmartSearchChatView                                                     │
│  - input                                                                │
│  - messages                                                             │
│  - citation pills                                                       │
└──────────────────────────────┬───────────────────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                    SmartSearchChatViewModel.sendMessage()               │
│                                                                          │
│  1. planner derives focused query                                        │
│  2. RAG searches with planned query                                      │
│  3. results mapped back to notes                                         │
│  4. augmented prompt assembled                                           │
│  5. final answer sent to Apple FM or cloud provider                      │
│  6. citations persisted on assistant message                             │
└──────────────────────────────┬───────────────────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                         SmartSearchQueryPlanner                          │
│                                                                          │
│  Inputs:                                                                 │
│  - latest user message                                                   │
│  - up to 4 previous non-summary messages                                 │
│                                                                          │
│  Output:                                                                 │
│  - shouldSearch                                                          │
│  - plannedQuery                                                          │
└──────────────────────────────┬───────────────────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                           RAGIndexingService                            │
│                                                                          │
│  - semantic chunk index                                                  │
│  - local vector search                                                   │
│  - chunk-id -> note-id mapping                                           │
│  - best chunk per note                                                   │
└──────────────────────────────┬───────────────────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                        SmartSearchContextManager                         │
│                                                                          │
│  - system prompt                                                         │
│  - SOURCE blocks                                                         │
│  - focused retrieval query section                                       │
│  - final USER QUESTION                                                   │
└──────────────────────────────────────────────────────────────────────────┘
```

## Planner-First Retrieval

Smart Search no longer sends the raw user sentence directly into RAG.

Instead:

- the planner sees the latest user message
- the planner also sees up to 4 recent non-summary chat messages
- it derives a more focused retrieval query
- RAG searches with that planned query

Example:

- user: `Do I have notes about similar thoughts?`
- planner may derive: `apple frameworks iOS macOS`
- RAG searches with `apple frameworks iOS macOS`

### Planner Input

Planner input is:

- latest user message
- up to 4 recent non-summary messages

There is no attached note text at planning time in Smart Search.

That is the main difference from cross-note chat planning.

### Planner Output

Planner returns:

```json
{
  "shouldSearch": true,
  "searchQuery": "apple frameworks iOS macOS",
  "reasoning": "brief internal explanation"
}
```

Normalization after planning:

- trim whitespace
- collapse repeated whitespace
- remove line breaks and tabs
- cap to 80 characters
- if the query becomes empty, planner result is treated as unusable

## Apple vs Cloud Execution Model

Smart Search uses the same planner-first idea on Apple and cloud, but the runtime structure differs.

### Apple FM

Apple uses two distinct session contexts:

```text
┌──────────────────────────────────────────────────────────────────────┐
│ Apple FM Smart Search turn                                          │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Temporary planner session                                           │
│ - derive plannedQuery                                               │
│ - separate from the main chat transcript                            │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Local RAG search                                                    │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Persistent main Apple Smart Search session                          │
│ - receives augmented prompt                                         │
│ - continues the real chat transcript                                │
└──────────────────────────────────────────────────────────────────────┘
```

So:

- planner uses a separate temporary Apple session
- final answering uses the persistent Smart Search Apple session
- search itself is local

### Cloud Providers

Cloud providers do not use a persistent provider-side session in our code.

Instead:

```text
┌──────────────────────────────────────────────────────────────────────┐
│ Cloud Smart Search turn                                             │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Planner request                                                     │
│ - non-streaming makeChatRequest(...)                                │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Local RAG search                                                    │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Final streaming chat request                                        │
│ - message history is sent explicitly                                │
│ - continuity comes from sent history, not provider session state    │
└──────────────────────────────────────────────────────────────────────┘
```

So:

- cloud does a planner request
- then local RAG
- then a final streaming answer request

## What RAG Actually Returns

`RAGIndexingService.search(...)`:

- performs semantic vector search over note chunks
- over-fetches `topK * 2`
- maps chunk ids back to note ids
- keeps the strongest chunk per note
- returns up to `topK` notes

Important:

- one best chunk per note
- no lexical reranking
- no exact-term boost layer
- no keyword merge inside Smart Search chat

## What Gets Injected Into the Final Model

The final model does not receive full notes.

It receives:

- all returned note results
- one chunk excerpt per returned note
- note title
- note date
- the original user question

It can also receive the focused retrieval query when that query differs from the raw user sentence.

Injected shape:

```text
Here are relevant excerpts from the user's notes:

Focused retrieval query used for note search:
apple frameworks iOS macOS

SOURCE 1
Title: ...
Date: ...
Excerpt:
...

SOURCE 2
Title: ...
Date: ...
Excerpt:
...

USER QUESTION:
Do I have notes about similar thoughts?
```

So the injection model is:

- all returned note results are included
- one chunk excerpt per note
- not full notes

## Empty Retrieval Behavior

When retrieval returns no note hits:

- if the planned query still has substantive terms, Smart Search returns a deterministic no-evidence response
- otherwise it can fall back to the raw question flow

This means the current empty-path behavior is:

- more deterministic for real substantive searches
- but still tolerant of planner outputs that are too weak to ground a no-evidence reply

## Indexing and Embeddings

Smart Search indexes:

- `transcription.text`

It intentionally does not index:

- `transcription.enhancedText`
- `TranscriptionVariation`

Current embedding and chunking setup:

- embedder model: `minishlab/potion-base-32M`
- chunking strategy: semantic
- chunk size: `500`
- overlap: `15%`
- runtime threshold: `0.25`

## Main Search Surface vs Smart Search Chat

The same `RAGIndexingService` is shared, but the product behavior differs:

- Smart Search chat:
  - planner-first
  - RAG-only
  - inject chunk excerpts into final answer prompt

- main search bar Smart mode:
  - still uses the shared RAG backend
  - also has app-level keyword filtering in the main notes search surface
  - semantic search is gated for very short inputs

So the shared backend is the same, but the chat orchestration around it differs by surface.

## Key Files

- [VivaDicta/Views/SmartSearch/SmartSearchChatViewModel.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/SmartSearch/SmartSearchChatViewModel.swift)
- [VivaDicta/Services/AIEnhance/SmartSearchQueryPlanner.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Services/AIEnhance/SmartSearchQueryPlanner.swift)
- [VivaDicta/Views/SmartSearch/SmartSearchContextManager.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/SmartSearch/SmartSearchContextManager.swift)
- [VivaDicta/Services/RAG/RAGIndexingService.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Services/RAG/RAGIndexingService.swift)
- [VivaDicta/Views/TranscriptionsContentView.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/TranscriptionsContentView.swift)
